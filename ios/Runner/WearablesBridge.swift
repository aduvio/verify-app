import Flutter
import UIKit
import MWDATCore
import MWDATCamera

/// DAT 0.9 connection diagnostics, separate from inspection evidence and audio.
final class WearablesBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let shared = WearablesBridge()
  private var configured = false
  private var available = false
  private var errorMessage: String?
  private var sink: FlutterEventSink?
  private var observers: [Task<Void, Never>] = []
  private var sessionObservers: [Task<Void, Never>] = []
  private var tokens: [any AnyListenerToken] = []
  private var session: DeviceSession?
  private var camera: Camera?
  private var frames = 0
  private var photo: Data?
  private var photoPending = false
  private var photoTimeout: Task<Void, Never>?
  private var generation = 0
  private var operationPending = false

  // Startup configuration only: never starts registration or capture.
  func configureOnce() {
    guard !configured else { return }
    configured = true
    do { try Wearables.configure(); available = true }
    catch { errorMessage = "Meta SDK configuration failed: \(error.localizedDescription)" }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(name: "project_verify/wearables", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(shared, channel: methods)
    FlutterEventChannel(name: "project_verify/wearables/events", binaryMessenger: registrar.messenger())
      .setStreamHandler(shared)
  }

  static func isCallback(_ url: URL) -> Bool {
    url.scheme == "projectverify" &&
      URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
        .contains(where: { $0.name == "metaWearablesAction" }) == true
  }

  func handleCallback(_ url: URL) {
    guard Self.isCallback(url), available else { return }
    Task { @MainActor in
      do {
        if !(try await Wearables.shared.handleUrl(url)) {
          errorMessage = "Meta AI did not recognize the callback. Try registration again."
        }
      } catch { errorMessage = "Meta AI callback failed: \(error.localizedDescription)" }
      emit()
    }
  }

  private func snapshot() -> [String: Any] {
    var value: [String: Any] = [
      "available": available,
      "registered": available && Wearables.shared.registrationState == .registered,
      "registration": available ? Wearables.shared.registrationState.description : "Unavailable",
      "devices": available ? Wearables.shared.devices.map { id in
        guard let device = Wearables.shared.deviceForIdentifier(id) else { return "Unknown device" }
        return "\(device.nameOrId()): \(device.linkState), compatibility: \(device.compatibility())"
      }.joined(separator: "\n") : "Unavailable",
      "session": session.map { String(describing: $0.state) } ?? "stopped",
      "camera": camera.map { String(describing: $0.state) } ?? "Not requested",
      "stream": camera.map { String(describing: $0.stream.state) } ?? "stopped",
      "frames": frames, "photoPending": photoPending,
    ]
    if let errorMessage { value["error"] = errorMessage }
    if let photo { value["photo"] = FlutterStandardTypedData(bytes: photo) }
    return value
  }
  private func emit() { sink?(snapshot()) }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if available {
      observers.append(Task { @MainActor in
        for await _ in Wearables.shared.registrationStateStream() {
          if Task.isCancelled { break }; emit()
        }
      })
      observers.append(Task { @MainActor in
        for await _ in Wearables.shared.devicesStream() {
          if Task.isCancelled { break }; emit()
        }
      })
    }
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    observers.forEach { $0.cancel() }; observers.removeAll()
    stopSession()
    return nil
  }

  func stopSession() {
    generation += 1
    photoTimeout?.cancel(); photoTimeout = nil; photoPending = false
    camera?.stream.stop(); camera?.stop(); session?.stop()
    camera = nil; session = nil; photo = nil; frames = 0
    sessionObservers.forEach { $0.cancel() }; sessionObservers.removeAll()
    let oldTokens = tokens; tokens.removeAll()
    Task { for token in oldTokens { await token.cancel() } }
    emit()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Stop bypasses the pending lock, invalidating outstanding permission work.
    if call.method == "stopSession" { stopSession(); result(snapshot()); return }
    if call.method == "status" { result(snapshot()); return }
    guard available else {
      result(FlutterError(code: "unavailable", message: errorMessage ?? "Meta SDK unavailable", details: nil)); return
    }
    guard !operationPending else {
      result(FlutterError(code: "busy", message: "Wait for the current Meta operation to finish.", details: nil)); return
    }
    operationPending = true; errorMessage = nil
    let expected = generation
    Task { @MainActor in
      defer { operationPending = false }
      do {
        guard expected == generation else { throw TestError.message("Operation cancelled because the session ended.") }
        switch call.method {
        case "register": try await Wearables.shared.startRegistration()
        case "startSession":
          guard session == nil else { throw TestError.message("Stop the existing session first.") }
          guard Wearables.shared.registrationState == .registered else { throw TestError.message("Register with Meta AI first.") }
          guard UIApplication.shared.applicationState == .active else { throw TestError.message("Return to the foreground first.") }
          let created = try Wearables.shared.createSession(deviceSelector: AutoDeviceSelector(wearables: Wearables.shared))
          session = created
          sessionObservers.append(Task { @MainActor in
            for await state in created.stateStream() {
              guard !Task.isCancelled, expected == generation else { break }
              if state == .stopped { stopSession(); break }
              emit()
            }
          })
          sessionObservers.append(Task { @MainActor in
            for await error in created.errorStream() {
              guard !Task.isCancelled, expected == generation else { break }
              errorMessage = "Glasses session: \(error.localizedDescription)"
              stopSession(); break
            }
          })
          do { try created.start() } catch { stopSession(); throw error }
        case "requestCamera":
          guard let session, session.state == .started, camera == nil else { throw TestError.message("Start a glasses session and wait for its started state first.") }
          var permission = try await Wearables.shared.checkPermissionStatus(.camera)
          if permission != .granted { permission = try await Wearables.shared.requestPermission(.camera) }
          guard expected == generation, UIApplication.shared.applicationState == .active else { throw TestError.message("Session ended while permission was pending. Start a new session explicitly.") }
          guard permission == .granted else { throw TestError.message("Glasses camera permission denied. Allow access in Meta AI, then request again.") }
          guard let capability = try session.addCamera(config: StreamConfiguration(videoCodec: .raw, resolution: .low, frameRate: 24)) else { throw TestError.message("Camera capability unavailable on this device/session.") }
          camera = capability
          observeCamera(capability, generation: expected)
        case "startStream":
          guard let camera, session?.state == .started, UIApplication.shared.applicationState == .active else { throw TestError.message("Request the glasses camera in an active session first.") }
          guard camera.stream.state == .stopped else { throw TestError.message("Wait for the stream to stop before starting again.") }
          camera.stream.start()
        case "stopStream": camera?.stream.stop()
        case "capturePhoto":
          guard let camera, camera.stream.state == .streaming, !photoPending else { throw TestError.message("Start the video stream and wait before taking a test photo.") }
          guard camera.stream.capturePhoto(format: .jpeg) else { throw TestError.message("Glasses rejected the photo request. Check their state and retry.") }
          photoPending = true
          photoTimeout = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
            guard expected == generation, photoPending else { return }
            photoPending = false
            errorMessage = "No photo arrived within 15 seconds. Check glasses connection and try again."
            emit()
          }
        default: result(FlutterMethodNotImplemented); return
        }
        emit(); result(snapshot())
      } catch {
        errorMessage = error.localizedDescription
        emit(); result(FlutterError(code: "wearables", message: errorMessage, details: nil))
      }
    }
  }

  private func observeCamera(_ camera: Camera, generation expected: Int) {
    tokens.append(camera.statePublisher.listen { [weak self] _ in
      DispatchQueue.main.async { guard let self, self.generation == expected else { return }; self.emit() }
    })
    tokens.append(camera.stream.statePublisher.listen { [weak self] _ in
      DispatchQueue.main.async { guard let self, self.generation == expected else { return }; self.emit() }
    })
    tokens.append(camera.stream.errorPublisher.listen { [weak self] error in
      DispatchQueue.main.async {
        guard let self, self.generation == expected else { return }
        self.errorMessage = "Glasses camera: \(error.localizedDescription)"
        self.photoPending = false; self.emit()
      }
    })
    tokens.append(camera.stream.videoFramePublisher.listen { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, self.generation == expected else { return }
        self.frames += 1
        if self.frames == 1 || self.frames % 24 == 0 { self.emit() }
      }
    })
    tokens.append(camera.stream.photoDataPublisher.listen { [weak self] photo in
      DispatchQueue.main.async {
        guard let self, self.generation == expected else { return }
        self.photoTimeout?.cancel(); self.photoPending = false
        self.photo = photo.data; self.emit()
      }
    })
  }
}

private enum TestError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self { case .message(let message): return message }
  }
}
