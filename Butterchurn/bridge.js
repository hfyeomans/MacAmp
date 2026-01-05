/**
 * MacAmp Butterchurn Bridge
 *
 * Communication layer between Swift (WKWebView) and Butterchurn visualization.
 * Injected at document end after butterchurn.min.js and butterchurnPresets.min.js.
 *
 * Phase 1: Static frame rendering (no audio data)
 * Phase 3: 30 FPS audio data from Swift, 60 FPS JS render loop
 */
(function() {
    'use strict';

    // DEBUG: Log bridge execution start
    console.log('[MacAmp Bridge] bridge.js executing...');
    console.log('[MacAmp Bridge] typeof butterchurn:', typeof butterchurn);
    console.log('[MacAmp Bridge] typeof butterchurnPresets:', typeof butterchurnPresets);
    console.log('[MacAmp Bridge] typeof window.butterchurn:', typeof window.butterchurn);
    console.log('[MacAmp Bridge] typeof window.butterchurnPresets:', typeof window.butterchurnPresets);
    console.log('[MacAmp Bridge] typeof window.minimal:', typeof window.minimal);

    // State
    let visualizer = null;
    let presets = null;
    let presetKeys = [];
    let currentPresetIndex = 0;
    let isRunning = false;

    // Audio data buffers (Phase 3: populated by Swift at 30 FPS)
    let audioData = {
        spectrum: new Uint8Array(1024),
        waveform: new Float32Array(1024)
    };

    // Check for required libraries (injected at documentStart)
    // Try both direct reference and window global
    var butterchurnLib = (typeof butterchurn !== 'undefined') ? butterchurn : window.butterchurn;
    var butterchurnPresetsLib = (typeof butterchurnPresets !== 'undefined') ? butterchurnPresets : window.butterchurnPresets;

    console.log('[MacAmp Bridge] butterchurnLib:', butterchurnLib);
    console.log('[MacAmp Bridge] butterchurnPresetsLib:', butterchurnPresetsLib);

    if (!butterchurnLib) {
        console.error('[MacAmp Bridge] butterchurn library not loaded!');
        showFallback('butterchurn library not loaded');
        notifyFailed('butterchurn library not loaded');
        return;
    }

    if (!butterchurnPresetsLib) {
        console.error('[MacAmp Bridge] butterchurnPresets library not loaded!');
        showFallback('butterchurnPresets library not loaded');
        notifyFailed('butterchurnPresets library not loaded');
        return;
    }

    // Use the resolved libraries
    var butterchurn = butterchurnLib;
    var butterchurnPresets = butterchurnPresetsLib;

    // Get canvas element
    const canvas = document.getElementById('canvas');
    if (!canvas) {
        showFallback('canvas element not found');
        notifyFailed('canvas element not found');
        return;
    }

    // DEBUG: Log canvas dimensions
    console.log('[MacAmp Bridge] Canvas clientWidth:', canvas.clientWidth, 'clientHeight:', canvas.clientHeight);
    console.log('[MacAmp Bridge] Canvas width:', canvas.width, 'height:', canvas.height);

    // NOTE: Do NOT create WebGL context here!
    // canvas.getContext('webgl') would create a context with default attributes.
    // Butterchurn needs to create its own context with specific attributes.
    // Once a context is created, you can't create another on the same canvas.
    // Let butterchurn handle context creation in createVisualizer().

    // Get presets from library
    // UMD bundle exports {default: {presetName: preset}} structure
    // ES module via getPresets() returns {presetName: preset} directly
    if (typeof butterchurnPresets.getPresets === 'function') {
        // ES module pattern (webamp-modern style)
        presets = butterchurnPresets.getPresets();
    } else if (butterchurnPresets.default && typeof butterchurnPresets.default === 'object') {
        // UMD bundle pattern - presets are at .default
        presets = butterchurnPresets.default;
    } else if (typeof butterchurnPresets === 'object') {
        // Direct object (already unwrapped)
        presets = butterchurnPresets;
    } else {
        showFallback('butterchurnPresets has unexpected format');
        notifyFailed('butterchurnPresets has unexpected format: ' + typeof butterchurnPresets);
        return;
    }
    console.log('[MacAmp Bridge] Loaded presets object, keys sample:', Object.keys(presets).slice(0, 3));
    presetKeys = Object.keys(presets);

    if (presetKeys.length === 0) {
        showFallback('no presets available');
        notifyFailed('no presets available');
        return;
    }

    // Ensure canvas has actual pixel dimensions (not just CSS)
    // Use clientWidth/Height if available, fallback to Milkdrop default size
    canvas.width = canvas.clientWidth || 256;
    canvas.height = canvas.clientHeight || 198;
    console.log('[MacAmp Bridge] Canvas pixel dimensions:', canvas.width, 'x', canvas.height);

    // Create AudioContext with audio graph that enables flow to butterchurn's analyser
    //
    // Web Audio is "pull-based" - audio only flows if there's a path to destination.
    // We create: oscillator -> signalGain -> [muteGain -> destination] (enables flow)
    //                                    \-> butterchurn.analyser (for visualization)
    //
    var audioContext = null
    var audioSourceNode = null
    try {
        audioContext = new (window.AudioContext || window.webkitAudioContext)()

        // Create oscillator with audible frequency (gives analyser frequency content)
        var oscillator = audioContext.createOscillator()
        oscillator.frequency.value = 440  // A4 note - gives us frequency content to visualize

        // Signal gain - MUST be non-zero so analyser sees the signal
        var signalGain = audioContext.createGain()
        signalGain.gain.value = 1  // Full signal for analyser
        oscillator.connect(signalGain)

        // Mute gain - connected to destination to enable audio flow, but silenced
        var muteGain = audioContext.createGain()
        muteGain.gain.value = 0  // Muted - no sound output
        signalGain.connect(muteGain)
        muteGain.connect(audioContext.destination)  // CRITICAL: enables audio flow

        // This is what butterchurn.connectAudio() will use
        audioSourceNode = signalGain

        oscillator.start()
        console.log('[MacAmp Bridge] AudioContext created with audio flow enabled, state:', audioContext.state)

        // Resume AudioContext if suspended (autoplay policy)
        if (audioContext.state === 'suspended') {
            audioContext.resume().then(function() {
                console.log('[MacAmp Bridge] AudioContext resumed, state:', audioContext.state)
            }).catch(function(err) {
                console.warn('[MacAmp Bridge] AudioContext resume failed:', err.message)
            })
        }
    } catch (audioError) {
        console.warn('[MacAmp Bridge] AudioContext creation failed:', audioError.message)
        // Continue without audio - will show static visualization
    }

    try {
        console.log('[MacAmp Bridge] Creating visualizer with dimensions:', canvas.width, 'x', canvas.height);
        visualizer = butterchurn.createVisualizer(audioContext, canvas, {
            width: canvas.width,
            height: canvas.height,
            pixelRatio: window.devicePixelRatio || 1,
            textureRatio: 1,
            // DEBUG: Try without WASM-only to test if WASM is blocked by sandbox
            onlyUseWASM: false
        });
        console.log('[MacAmp Bridge] Visualizer created successfully')

        // DEBUG: Check WebGL context after butterchurn creates it
        var glContext = canvas.getContext('webgl2') || canvas.getContext('webgl');
        if (glContext) {
            console.log('[MacAmp Bridge] WebGL context:', glContext.getParameter(glContext.VERSION));
            console.log('[MacAmp Bridge] WebGL viewport:', glContext.getParameter(glContext.VIEWPORT));
        } else {
            console.error('[MacAmp Bridge] No WebGL context available after visualizer creation!');
        }
    } catch (error) {
        showFallback('visualizer creation failed: ' + error.message)
        notifyFailed('visualizer creation failed: ' + error.message)
        return;
    }

    if (audioSourceNode) {
        visualizer.connectAudio(audioSourceNode)
        console.log('[MacAmp Bridge] Connected audio source to visualizer (audio flow enabled)')
    } else {
        console.warn('[MacAmp Bridge] No audio source available - visualization may not animate')
    }

    // Load initial preset (no transition)
    if (presetKeys.length > 0) {
        try {
            console.log('[MacAmp Bridge] Loading initial preset:', presetKeys[0]);
            visualizer.loadPreset(presets[presetKeys[0]], 0);
            currentPresetIndex = 0;
            console.log('[MacAmp Bridge] Preset loaded successfully');
        } catch (error) {
            console.error('[MacAmp Bridge] Failed to load preset:', error.message, error.stack);
            showFallback('preset load failed: ' + error.message);
            notifyFailed('preset load failed: ' + error.message);
            return;
        }
    }

    // DEBUG: Track render errors and frame count
    var renderErrorCount = 0;
    var maxRenderErrors = 3;
    var frameCount = 0;

    // 60 FPS render loop with error handling
    function renderLoop() {
        if (!isRunning) return;
        try {
            visualizer.render();
            frameCount++;
            // Log every 60 frames (~1 second at 60fps)
            if (frameCount === 1 || frameCount % 60 === 0) {
                console.log('[MacAmp Bridge] Rendered ' + frameCount + ' frames');
            }
        } catch (error) {
            renderErrorCount++;
            console.error('[MacAmp Bridge] Render error #' + renderErrorCount + ':', error.message, error.stack);
            if (renderErrorCount >= maxRenderErrors) {
                console.error('[MacAmp Bridge] Too many render errors, stopping');
                isRunning = false;
                showFallback('render failed: ' + error.message);
                notifyFailed('render failed: ' + error.message);
                return;
            }
        }
        requestAnimationFrame(renderLoop);
    }

    // Show fallback UI
    function showFallback(message) {
        const fallback = document.getElementById('fallback');
        if (fallback) {
            fallback.textContent = 'Butterchurn: ' + message;
            fallback.style.display = 'block';
        }
        const canvasEl = document.getElementById('canvas');
        if (canvasEl) {
            canvasEl.style.display = 'none';
        }
    }

    // Notify Swift of failure
    function notifyFailed(error) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.butterchurn) {
            window.webkit.messageHandlers.butterchurn.postMessage({
                type: 'loadFailed',
                error: error
            });
        }
    }

    // Notify Swift of success
    function notifyReady() {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.butterchurn) {
            window.webkit.messageHandlers.butterchurn.postMessage({
                type: 'ready',
                presetCount: presetKeys.length,
                presetNames: presetKeys
            });
        }
    }

    // Handle window resize
    function handleResize() {
        if (!visualizer) return;

        const width = canvas.clientWidth || 256;
        const height = canvas.clientHeight || 198;

        canvas.width = width;
        canvas.height = height;
        visualizer.setRendererSize(width, height);
    }

    window.addEventListener('resize', handleResize);

    // Public API for Swift bridge
    window.macampButterchurn = {
        /**
         * Update audio data from Swift (Phase 3: called at 30 FPS)
         * @param {number[]} spectrum - Frequency data (0-255), 1024 bins
         * @param {number[]} waveform - Waveform data (-1 to 1), 1024 samples
         */
        setAudioData: function(spectrum, waveform) {
            if (spectrum && spectrum.length) {
                audioData.spectrum.set(spectrum.slice(0, 1024));
            }
            if (waveform && waveform.length) {
                audioData.waveform.set(waveform.slice(0, 1024));
            }
            // Note: Butterchurn will read from these buffers on next render
        },

        /**
         * Load preset by index
         * @param {number} index - Preset index
         * @param {number} transition - Transition duration in seconds (default: 2.7)
         */
        loadPreset: function(index, transition) {
            if (!visualizer || !presetKeys[index]) return;

            visualizer.loadPreset(presets[presetKeys[index]], transition || 2.7);
            currentPresetIndex = index;
        },

        /**
         * Show track title animation
         * @param {string} title - Track title to display
         */
        showTrackTitle: function(title) {
            if (!visualizer) return;
            visualizer.launchSongTitleAnim(title);
        },

        /**
         * Resize canvas and renderer
         * @param {number} width - New width
         * @param {number} height - New height
         */
        setSize: function(width, height) {
            if (!visualizer) return;

            canvas.width = width;
            canvas.height = height;
            visualizer.setRendererSize(width, height);
        },

        /**
         * Start render loop
         */
        start: function() {
            if (isRunning) return;
            isRunning = true;
            requestAnimationFrame(renderLoop);
        },

        /**
         * Stop render loop
         */
        stop: function() {
            isRunning = false;
        },

        /**
         * Get current state
         * @returns {object} Current state
         */
        getState: function() {
            return {
                isRunning: isRunning,
                presetCount: presetKeys.length,
                currentPresetIndex: currentPresetIndex,
                currentPresetName: presetKeys[currentPresetIndex] || null
            };
        }
    };

    // Notify Swift we're ready
    notifyReady();

    // Start render loop
    window.macampButterchurn.start();

})();
