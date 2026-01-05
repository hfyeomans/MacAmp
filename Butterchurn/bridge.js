/**
 * MacAmp Butterchurn Bridge
 *
 * Communication layer between Swift (WKWebView) and Butterchurn visualization.
 * Injected at document end after butterchurn.min.js and butterchurnPresets.min.js.
 *
 * Phase 1: Placeholder audio (440Hz oscillator)
 * Phase 2-3: Real audio data from Swift at 30 FPS
 */
(function() {
    'use strict';

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

    if (!butterchurnLib) {
        showFallback('butterchurn library not loaded');
        notifyFailed('butterchurn library not loaded');
        return;
    }

    if (!butterchurnPresetsLib) {
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

    // NOTE: Do NOT create WebGL context before butterchurn!
    // canvas.getContext('webgl') creates a context with default attributes.
    // Butterchurn needs to create its own context with specific attributes.
    // Once a context is created, you can't create another on the same canvas.

    // Get presets from library
    // UMD bundle exports {default: {presetName: preset}} structure
    // ES module via getPresets() returns {presetName: preset} directly
    if (typeof butterchurnPresets.getPresets === 'function') {
        presets = butterchurnPresets.getPresets();
    } else if (butterchurnPresets.default && typeof butterchurnPresets.default === 'object') {
        presets = butterchurnPresets.default;
    } else if (typeof butterchurnPresets === 'object') {
        presets = butterchurnPresets;
    } else {
        showFallback('butterchurnPresets has unexpected format');
        notifyFailed('butterchurnPresets has unexpected format');
        return;
    }
    presetKeys = Object.keys(presets);

    if (presetKeys.length === 0) {
        showFallback('no presets available');
        notifyFailed('no presets available');
        return;
    }

    // Ensure canvas has actual pixel dimensions (not just CSS)
    canvas.width = canvas.clientWidth || 256;
    canvas.height = canvas.clientHeight || 198;

    // Create AudioContext with audio graph that enables flow to butterchurn's analyser
    //
    // Web Audio is "pull-based" - audio only flows if there's a path to destination.
    // We create: oscillator -> signalGain -> [muteGain -> destination] (enables flow)
    //                                    \-> butterchurn.analyser (for visualization)
    //
    // Phase 2-3: Replace oscillator with real audio data from Swift
    var audioContext = null;
    var audioSourceNode = null;
    try {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();

        // Create oscillator with audible frequency (gives analyser frequency content)
        var oscillator = audioContext.createOscillator();
        oscillator.frequency.value = 440;  // A4 note - placeholder for Phase 1

        // Signal gain - MUST be non-zero so analyser sees the signal
        var signalGain = audioContext.createGain();
        signalGain.gain.value = 1;
        oscillator.connect(signalGain);

        // Mute gain - connected to destination to enable audio flow, but silenced
        var muteGain = audioContext.createGain();
        muteGain.gain.value = 0;  // Muted - no sound output
        signalGain.connect(muteGain);
        muteGain.connect(audioContext.destination);  // Enables audio flow

        audioSourceNode = signalGain;
        oscillator.start();

        // Resume AudioContext if suspended (autoplay policy)
        if (audioContext.state === 'suspended') {
            audioContext.resume();
        }
    } catch (audioError) {
        // Continue without audio - visualization will be static
    }

    // Create visualizer
    try {
        visualizer = butterchurn.createVisualizer(audioContext, canvas, {
            width: canvas.width,
            height: canvas.height,
            pixelRatio: window.devicePixelRatio || 1,
            textureRatio: 1
        });
    } catch (error) {
        showFallback('visualizer creation failed: ' + error.message);
        notifyFailed('visualizer creation failed: ' + error.message);
        return;
    }

    // Connect audio source to butterchurn's internal analyser
    if (audioSourceNode) {
        visualizer.connectAudio(audioSourceNode);
    }

    // Load initial preset (no transition)
    if (presetKeys.length > 0) {
        try {
            visualizer.loadPreset(presets[presetKeys[0]], 0);
            currentPresetIndex = 0;
        } catch (error) {
            showFallback('preset load failed: ' + error.message);
            notifyFailed('preset load failed: ' + error.message);
            return;
        }
    }

    // Render error tracking
    var renderErrorCount = 0;
    var maxRenderErrors = 3;

    // 60 FPS render loop
    function renderLoop() {
        if (!isRunning) return;
        try {
            visualizer.render();
        } catch (error) {
            renderErrorCount++;
            if (renderErrorCount >= maxRenderErrors) {
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

    // Notify Swift we're ready and start rendering
    notifyReady();
    window.macampButterchurn.start();

})();
