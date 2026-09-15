import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts where WearablesBridge.isCallback(context.url) {
      WearablesBridge.shared.handleCallback(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let remaining = URLContexts.filter { !WearablesBridge.isCallback($0.url) }
    for context in URLContexts where WearablesBridge.isCallback(context.url) {
      WearablesBridge.shared.handleCallback(context.url)
    }
    if !remaining.isEmpty { super.scene(scene, openURLContexts: Set(remaining)) }
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    WearablesBridge.shared.stopSession()
    super.sceneDidEnterBackground(scene)
  }
}
