/* Browser-only capture adapter. No network, uploads, mock fallback or startup permissions. */
(() => {
  'use strict';
  const event = (target, name, timeout = 15000, signal) => new Promise((resolve, reject) => {
    const done = e => { cleanup(); resolve(e); };
    const fail = () => { cleanup(); reject(new Error('Media could not be decoded or the device stopped.')); };
    const timer = setTimeout(() => { cleanup(); reject(new Error('Media operation timed out. Cancel and retry.')); }, timeout);
    const abort = () => { cleanup(); resolve(); };
    const cleanup = () => { clearTimeout(timer); target.removeEventListener(name, done); target.removeEventListener('error', fail); signal?.removeEventListener('abort', abort); };
    target.addEventListener(name, done, {once:true}); target.addEventListener('error', fail, {once:true});
    signal?.addEventListener('abort', abort, {once:true});
  });
  const message = e => ({NotAllowedError:'Permission denied. Allow the camera/microphone in Chrome, or explicitly retry camera only.',
    NotFoundError:'No matching camera/microphone found. Connect a device or explicitly use simulation.',
    NotReadableError:'Camera/microphone is unavailable or in use by another application.',
    OverconstrainedError:'The selected device is unavailable or does not support the requested settings. Refresh the microphone list and select an available input.'}[e.name] || e.message || 'Capture is unsupported or unavailable.');

  async function validate(blob, photo) {
    if (!blob.size) throw new Error('Empty capture. No evidence was accepted.');
    const url = URL.createObjectURL(blob);
    const element = document.createElement(photo ? 'img' : 'video');
    const controller = new AbortController();
    try {
      if (photo) {
        element.src = url; await element.decode();
        if (!element.naturalWidth || !element.naturalHeight) throw new Error('Photo could not be decoded.');
        return 0;
      }
      element.muted = true; element.playsInline = true; element.preload = 'auto';
      const loaded = event(element, 'loadedmetadata', 15000, controller.signal); element.src = url; await loaded;
      if (!element.videoWidth || !element.videoHeight) throw new Error('Recording has no playable video track.');
      // WebM often reports Infinity. Decode the finalized clip through to ended,
      // using its media timeline (not the wall clock or timeslice callback count).
      const ended = event(element, 'ended', 120000, controller.signal);
      element.playbackRate = 8;
      await Promise.all([element.play(), ended]);
      const seconds = Number.isFinite(element.duration) ? element.duration : element.currentTime;
      if (!Number.isFinite(seconds) || seconds <= 0) throw new Error('Recording duration is unavailable; retry the clip.');
      return Math.floor(seconds * 1000);
    } finally { controller.abort(); if (!photo) { element.pause(); element.removeAttribute('src'); element.load(); } URL.revokeObjectURL(url); }
  }

  function createCamera() {
    const preview = document.createElement('video');
    const previewPanel = document.createElement('div');
    const devices = document.createElement('p');
    previewPanel.style.cssText = 'width:100%;height:100%;display:flex;flex-direction:column';
    devices.style.cssText = 'margin:4px;font:13px sans-serif;overflow-wrap:anywhere';
    devices.textContent = 'Computer test/fallback devices selected by Chrome. Names appear after permission; confirm them before recording. Ray-Ban Meta is not connected.';
    preview.muted = true; preview.autoplay = true; preview.playsInline = true;
    preview.style.cssText = 'width:100%;min-height:0;flex:1;object-fit:contain;background:#111';
    previewPanel.append(preview, devices);
    previewPanel.style.overflowY = 'auto';
    preview.style.minHeight = '90px';
    const audioPanel = document.createElement('div');
    audioPanel.hidden = true;
    const selector = document.createElement('select');
    selector.setAttribute('aria-label', 'Available microphones');
    selector.style.cssText = 'width:100%;max-width:100%';
    const apply = document.createElement('button');
    apply.textContent = 'USE SELECTED MICROPHONE';
    const refresh = document.createElement('button');
    refresh.textContent = 'REFRESH MICROPHONES';
    const meterButton = document.createElement('button');
    meterButton.textContent = 'START / RESUME MICROPHONE METER';
    const meter = document.createElement('meter');
    meter.min = 0; meter.max = 1; meter.value = 0;
    meter.setAttribute('aria-label', 'Measured microphone level');
    meter.style.width = '100%';
    const diagnostic = document.createElement('div');
    const audioError = document.createElement('div');
    diagnostic.textContent = 'Analyzer inactive — click Start / Resume Microphone Meter. No speaker monitoring.';
    audioPanel.append(selector, refresh, apply, meterButton, meter, diagnostic, audioError);
    previewPanel.append(audioPanel);
    let stream, recorder, chunks = [], busy = false, generation = 0, cancelled = false;
    let stopped, failure, narration = false;
    let context, source, analyser, meterTimer, measuredTrack;
    const stopMeter = () => {
      clearInterval(meterTimer); meterTimer = null;
      source?.disconnect(); source = null; analyser = null; measuredTrack = null;
      if (context) context.close().catch(() => {});
      context = null; meter.value = 0;
      diagnostic.textContent = 'Analyzer inactive — devices stopped or input changed. Click Start / Resume Microphone Meter after enabling the input.';
    };
    const showDevices = () => {
      const track = stream?.getAudioTracks()[0];
      devices.textContent = 'Camera: ' + (stream?.getVideoTracks()[0]?.label || 'off') +
        ' | Microphone: ' + (narration ? (track?.label || 'unavailable') : 'OFF');
    };
    const listInputs = async () => {
      const inputs = await navigator.mediaDevices.enumerateDevices();
      selector.replaceChildren();
      for (const input of inputs.filter(d => d.kind === 'audioinput')) {
        const option = document.createElement('option');
        option.value = input.deviceId; option.textContent = input.label || 'Unnamed microphone (permission may be required)';
        selector.append(option);
      }
      const actual = stream?.getAudioTracks()[0]?.getSettings().deviceId;
      if ([...selector.options].some(o => o.value === actual)) selector.value = actual;
      if (!selector.options.length) throw new Error('No microphone is listed. Check Chrome microphone permission, then Refresh Microphones.');
    };
    refresh.onclick = async () => {
      if (busy || recorder?.state === 'recording' || cancelled) return;
      try { await listInputs(); audioError.textContent = ''; } catch (e) { audioError.textContent = message(e); }
    };
    apply.onclick = async () => {
      if (busy || !stream || cancelled || recorder?.state === 'recording') return;
      busy = true; apply.disabled = true; const token = generation;
      try {
        if (!selector.value) throw new Error('Select an available microphone first.');
        const acquired = await navigator.mediaDevices.getUserMedia({video:false, audio:{deviceId:{exact:selector.value}}});
        if (token !== generation || cancelled) { acquired.getTracks().forEach(t => t.stop()); return; }
        const track = acquired.getAudioTracks()[0];
        if (!track || !track.enabled || track.readyState !== 'live') {
          acquired.getTracks().forEach(t => t.stop()); throw new Error('Selected microphone returned no live enabled audio track.');
        }
        stopMeter();
        stream.getAudioTracks().forEach(t => { stream.removeTrack(t); t.stop(); });
        stream.addTrack(track);
        showDevices(); audioError.textContent = '';
      } catch (e) { audioError.textContent = message(e) + ' Input was not changed; check the actual microphone shown above.'; }
      finally { busy = false; apply.disabled = false; }
    };
    meterButton.onclick = async () => {
      if (busy || !stream || cancelled || !narration) return;
      try {
        if (!context) {
          const AudioContextClass = window.AudioContext || window.webkitAudioContext;
          if (!AudioContextClass) throw new Error('Audio analyzer unavailable in this browser.');
          context = new AudioContextClass();
          measuredTrack = stream.getAudioTracks()[0];
          if (!measuredTrack) throw new Error('No microphone track to measure. Select a microphone first.');
          source = context.createMediaStreamSource(new MediaStream([measuredTrack]));
          analyser = context.createAnalyser(); analyser.fftSize = 2048;
          source.connect(analyser); // Deliberately never connected to speakers/destination.
        }
        const activeContext = context;
        await activeContext.resume(); // User's explicit click, not startup or capture helper.
        if (context !== activeContext || cancelled) return;
        clearInterval(meterTimer);
        const samples = new Float32Array(analyser.fftSize);
        meterTimer = setInterval(() => {
          if (!context || !measuredTrack) return;
          const running = context.state === 'running';
          analyser.getFloatTimeDomainData(samples);
          const rms = running ? Math.sqrt(samples.reduce((sum, x) => sum + x*x, 0) / samples.length) : 0;
          meter.value = Math.min(1, rms * 8);
          diagnostic.textContent = 'Actual input: ' + measuredTrack.label +
            ' | track ' + measuredTrack.readyState + ' | enabled: ' + measuredTrack.enabled + ' | muted: ' + measuredTrack.muted +
            ' | Analyzer: ' + context.state + ' | RMS: ' + rms.toFixed(5) +
            (running ? (rms > 0.001 ? ' — Sound activity detected (not proof of speech).' : ' — No sound activity detected. Check selected input and input mute/level.') : ' — Analyzer inactive; click Start / Resume.') +
            (recorder?.state === 'recording' ? ' | Recorder uses this track: ' + recorder.stream.getAudioTracks().includes(measuredTrack) : ' | Preview only; this track will be supplied to the recorder.');
        }, 100);
        audioError.textContent = '';
      } catch (e) { stopMeter(); audioError.textContent = message(e); }
    };
    const checkAudio = () => {
      if (narration && !stream?.getAudioTracks().some(t => t.enabled && !t.muted && t.readyState === 'live')) {
        throw new Error('Narration requested, but no usable microphone track is available. Check Chrome microphone permission and selected input, unmute the microphone, then cancel and retry. No video-only fallback was substituted.');
      }
    };
    const release = () => { stopMeter(); if (stream) stream.getTracks().forEach(t => t.stop()); stream = null; preview.srcObject = null; };
    const cancel = () => {
      cancelled = true; generation++;
      if (recorder && recorder.state !== 'inactive') recorder.stop();
      release();
    };
    const hidden = () => { if (document.hidden) cancel(); };
    document.addEventListener('visibilitychange', hidden);
    window.addEventListener('pagehide', cancel);
    return {
      preview: previewPanel,
      async open(audio) {
        if (busy || stream) throw new Error('Camera operation already active.');
        busy = true; cancelled = false; const token = ++generation;
        try {
          if (!navigator.mediaDevices?.getUserMedia) throw new Error('Camera API unavailable. Use Chrome at the fixed loopback address or HTTPS.');
          const acquired = await navigator.mediaDevices.getUserMedia({video:true, audio});
          if (token !== generation || cancelled) { acquired.getTracks().forEach(t => t.stop()); throw new Error('Capture cancelled.'); }
          stream = acquired;
          narration = audio;
          checkAudio();
          audioPanel.hidden = !audio;
          if (audio) {
            try { await listInputs(); } catch (e) { audioError.textContent = message(e); }
          }
          if (token !== generation || cancelled) throw new Error('Capture cancelled.');
          devices.textContent = 'Camera: ' + (stream.getVideoTracks()[0]?.label || 'name unavailable — confirm in Chrome') +
            ' | Microphone: ' + (audio ? (stream.getAudioTracks()[0]?.label || 'name unavailable — confirm in Chrome') : 'OFF') +
            '. Preview only until you start capture. Prepare a non-sensitive scene and avoid private conversation.';
          stream.getVideoTracks().forEach(t => t.addEventListener('ended', cancel, {once:true}));
          preview.srcObject = stream; await preview.play();
        } catch (e) { release(); throw new Error(message(e)); }
        finally { busy = false; }
      },
      async photo() {
        if (busy || !stream || cancelled) throw new Error('Enable the camera first.');
        busy = true; const token = generation;
        try {
          if (!preview.videoWidth) throw new Error('Camera image is not ready. Retry.');
          const canvas = document.createElement('canvas');
          canvas.width = preview.videoWidth; canvas.height = preview.videoHeight;
          canvas.getContext('2d').drawImage(preview, 0, 0);
          const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.9));
          if (!blob) throw new Error('Photo encoding failed.');
          const durationMs = await validate(blob, true);
          if (token !== generation || cancelled) throw new Error('Capture interrupted.');
          return {bytes:new Uint8Array(await blob.arrayBuffer()), mimeType:blob.type, durationMs};
        } finally { busy = false; release(); }
      },
      async start() {
        if (busy || !stream || cancelled || recorder?.state === 'recording') throw new Error('Camera is not ready or is already recording.');
        checkAudio();
        if (!window.MediaRecorder) throw new Error('Video recording is unsupported in this browser.');
        const mimeType = (narration ? ['video/webm;codecs=vp8,opus','video/mp4'] : ['video/webm;codecs=vp8,opus','video/webm;codecs=vp8','video/mp4']).find(t => MediaRecorder.isTypeSupported(t));
        if (!mimeType) throw new Error('No supported video recording format.');
        chunks = []; failure = null;
        recorder = new MediaRecorder(stream, {mimeType});
        selector.disabled = true; apply.disabled = true; refresh.disabled = true;
        stopped = new Promise(resolve => { recorder.onstop = resolve; });
        recorder.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
        recorder.onerror = () => { failure = 'Recording failed or device disconnected.'; cancel(); };
        recorder.start(1000);
      },
      async stop() {
        if (busy || !recorder || recorder.state !== 'recording' || cancelled) throw new Error('Recording was interrupted or is not active.');
        busy = true; const token = generation;
        try {
          checkAudio();
          recorder.stop();
          await Promise.race([stopped, new Promise((_, reject) => setTimeout(() => reject(new Error('Recording did not finalize.')), 15000))]);
          const blob = new Blob(chunks, {type:recorder.mimeType});
          release();
          if (failure || token !== generation || cancelled) throw new Error(failure || 'Recording interrupted.');
          const durationMs = await validate(blob, false);
          if (token !== generation || cancelled) throw new Error('Recording interrupted during validation.');
          return {bytes:new Uint8Array(await blob.arrayBuffer()), mimeType:blob.type, durationMs};
        } finally { busy = false; release(); }
      },
      dispose() { cancel(); document.removeEventListener('visibilitychange', hidden); window.removeEventListener('pagehide', cancel); }
    };
  }
  function player(bytes, mimeType) {
    const photo = mimeType.startsWith('image/');
    const root = document.createElement('div');
    const element = document.createElement(photo ? 'img' : 'video');
    const status = document.createElement('p');
    status.textContent = 'Loading local media…';
    const url = URL.createObjectURL(new Blob([bytes], {type:mimeType}));
    element.style.cssText = 'width:100%;min-height:0;flex:1;object-fit:contain;background:#111';
    root.style.cssText = 'width:100%;height:100%;display:flex;flex-direction:column';
    if (!photo) { element.controls = false; element.preload = 'auto'; element.playsInline = true; element.muted = false; element.volume = 1; }
    const ready = () => { status.textContent = 'Saved local media • not proof of service condition'; if (!photo) element.controls = true; };
    element.addEventListener(photo ? 'load' : 'canplay', ready, {once:true});
    element.onerror = () => { status.textContent = 'Missing, corrupt, or unsupported playback. No playable evidence is available here.'; if (!photo) element.controls = false; };
    element.src = url; root.append(element, status);
    if (!photo) {
      const sound = document.createElement('button');
      const update = () => { sound.textContent = element.muted || element.volume === 0 ? 'SOUND OFF — enable playback sound' : 'SOUND ON — mute playback'; };
      sound.onclick = () => { if (element.muted || element.volume === 0) { element.muted = false; element.volume = 1; } else element.muted = true; update(); };
      element.addEventListener('volumechange', update); update();
      const hint = document.createElement('small');
      hint.textContent = 'Press Play and listen to confirm narration. Sound on does not prove audio was recorded. Check device/output volume if silent.';
      root.append(sound, hint);
    }
    return {element:root, dispose() { if (!photo) { element.pause(); element.removeAttribute('src'); element.load(); } URL.revokeObjectURL(url); root.remove(); }};
  }
  window.verifyMedia = {createCamera, player, validate};
})();
