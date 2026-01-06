/**
 * MacAmp Butterchurn Bridge
 *
 * Communication layer between Swift (WKWebView) and Butterchurn visualization.
 * Injected at document end after butterchurn.min.js and butterchurnPresets.min.js.
 *
 * Phase 3: Real audio data from Swift at 30 FPS via ScriptProcessorNode
 *
 * Preset Loading:
 * - Base pack (butterchurnPresets): ~98 presets
 * - Extra pack (butterchurnPresetsExtra): ~147 presets (optional)
 * - Total: ~245 presets when both loaded
 *
 * Preset Sources (butterchurn-presets@2.4.7 via jsDelivr CDN):
 * - Base: https://cdn.jsdelivr.net/npm/butterchurn-presets@2.4.7/lib/butterchurnPresets.min.js
 * - Extra: https://cdn.jsdelivr.net/npm/butterchurn-presets@2.4.7/lib/butterchurnPresetsExtra.min.js
 *
 * Local files (Butterchurn/ folder):
 * - butterchurnPresets.min.js (638KB, Base pack)
 * - butterchurnPresetsExtra.min.js (825KB, Extra pack)
 */
(function() {
    'use strict';

    // State
    var visualizer = null;
    var presets = null;
    var presetKeys = [];
    var currentPresetIndex = 0;
    var isRunning = false;

    // Audio data buffer - populated by Swift at 30 FPS, output by ScriptProcessorNode
    // Using 1024 samples to match butterchurn's expected buffer size
    var latestWaveform = new Float32Array(1024);
    var waveformWriteIndex = 0;  // Tracks where we are in the waveform for continuous output

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

    // Load presets from Base pack (required)
    // Only use getPresets() or .default paths to avoid non-preset keys from raw object
    var basePresets = {};
    if (typeof butterchurnPresets.getPresets === 'function') {
        basePresets = butterchurnPresets.getPresets();
    } else if (butterchurnPresets.default && typeof butterchurnPresets.default === 'object') {
        basePresets = butterchurnPresets.default;
    } else {
        showFallback('butterchurnPresets has unexpected format (expected getPresets or default)');
        notifyFailed('butterchurnPresets has unexpected format');
        return;
    }

    // Load presets from Extra pack (optional, ~147 additional presets)
    // Wrapped in try/catch for graceful degradation - base presets still work if extra fails
    var extraPresets = {};
    var extraPackLoaded = false;
    try {
        var butterchurnPresetsExtraLib = (typeof butterchurnPresetsExtra !== 'undefined') ? butterchurnPresetsExtra : window.butterchurnPresetsExtra;
        if (butterchurnPresetsExtraLib) {
            // Only use getPresets() or .default paths to avoid non-preset keys
            if (typeof butterchurnPresetsExtraLib.getPresets === 'function') {
                extraPresets = butterchurnPresetsExtraLib.getPresets();
                extraPackLoaded = true;
            } else if (butterchurnPresetsExtraLib.default && typeof butterchurnPresetsExtraLib.default === 'object') {
                extraPresets = butterchurnPresetsExtraLib.default;
                extraPackLoaded = true;
            }
            // Validate extraPresets is a plain object
            if (typeof extraPresets !== 'object' || extraPresets === null) {
                extraPresets = {};
                extraPackLoaded = false;
            }
        }
    } catch (extraError) {
        // Extra pack failed to load - continue with base presets only
        console.warn('[MacAmp] Extra presets failed to load:', extraError.message);
        extraPresets = {};
        extraPackLoaded = false;
    }

    // Merge Base + Extra presets (Extra overwrites on conflict, but names shouldn't overlap)
    presets = Object.assign({}, basePresets, extraPresets);

    // Sort preset keys alphabetically for deterministic order across sessions
    // Use fixed 'en' locale to ensure consistent ordering regardless of user locale
    presetKeys = Object.keys(presets).sort(function(a, b) {
        return a.localeCompare(b, 'en', { sensitivity: 'base' });
    });

    if (presetKeys.length === 0) {
        showFallback('no presets available');
        notifyFailed('no presets available');
        return;
    }

    // Ensure canvas has actual pixel dimensions (not just CSS)
    canvas.width = canvas.clientWidth || 256;
    canvas.height = canvas.clientHeight || 198;

    // Create AudioContext with ScriptProcessorNode to output Swift audio data
    //
    // Web Audio is "pull-based" - audio only flows if there's a path to destination.
    // We use ScriptProcessorNode to generate audio from latestWaveform (pushed by Swift).
    // The processor outputs our waveform data, butterchurn's analyser analyzes it.
    //
    // Architecture:
    //   ScriptProcessorNode (outputs latestWaveform) → muteGain(0) → destination
    //                                                ↘ butterchurn.analyser
    var audioContext = null;
    var audioSourceNode = null;
    var scriptProcessor = null;
    try {
        audioContext = new (window.AudioContext || window.webkitAudioContext)();

        // ScriptProcessorNode: 0 inputs, 1 output, buffer size 1024
        // Deprecated but still works in all browsers; AudioWorklet is more complex
        scriptProcessor = audioContext.createScriptProcessor(1024, 0, 1);

        // Fill output buffer with latestWaveform data from Swift
        scriptProcessor.onaudioprocess = function(e) {
            var output = e.outputBuffer.getChannelData(0);
            var waveformLen = latestWaveform.length;

            // Copy waveform data to output, looping if needed
            for (var i = 0; i < output.length; i++) {
                output[i] = latestWaveform[waveformWriteIndex];
                waveformWriteIndex = (waveformWriteIndex + 1) % waveformLen;
            }
        };

        // Mute gain - enables audio flow but silences output (we don't want to hear it)
        var muteGain = audioContext.createGain();
        muteGain.gain.value = 0;

        // Connect: processor → muteGain → destination (enables pull-based flow)
        scriptProcessor.connect(muteGain);
        muteGain.connect(audioContext.destination);

        // audioSourceNode is what we connect to butterchurn
        audioSourceNode = scriptProcessor;

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
                presetNames: presetKeys,
                extraPackLoaded: extraPackLoaded,
                basePresetCount: Object.keys(basePresets).length,
                extraPresetCount: Object.keys(extraPresets).length
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
         * Update audio data from Swift (called at 30 FPS)
         * The waveform data is output by ScriptProcessorNode for butterchurn to analyze.
         * @param {number[]} spectrum - Frequency data (0-255), 1024 bins (currently unused, derived by analyser)
         * @param {number[]} waveform - Waveform data (-1 to 1), 1024 samples
         */
        setAudioData: function(spectrum, waveform) {
            // Update the waveform buffer that ScriptProcessorNode outputs
            // The spectrum is derived by butterchurn's internal analyser from the waveform
            if (waveform && waveform.length) {
                var len = Math.min(waveform.length, latestWaveform.length);
                for (var i = 0; i < len; i++) {
                    latestWaveform[i] = waveform[i];
                }
                // Reset write index so next onaudioprocess starts from beginning
                waveformWriteIndex = 0;
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
        },

        /**
         * Dispose resources to prevent memory leaks
         * Call from Swift when web view is dismissed
         */
        dispose: function() {
            // Stop render loop
            isRunning = false;

            // Remove resize listener
            window.removeEventListener('resize', handleResize);

            // Disconnect and close audio nodes
            if (scriptProcessor) {
                scriptProcessor.disconnect();
                scriptProcessor.onaudioprocess = null;
            }
            if (audioContext && audioContext.state !== 'closed') {
                audioContext.close().catch(function() {});
            }

            // Clear references
            visualizer = null;
            presets = null;
            presetKeys = [];
            audioContext = null;
            audioSourceNode = null;
            scriptProcessor = null;
        }
    };

    // Notify Swift we're ready and start rendering
    notifyReady();
    window.macampButterchurn.start();

})();
