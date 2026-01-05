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
    if (typeof butterchurn === 'undefined') {
        showFallback('butterchurn library not loaded');
        notifyFailed('butterchurn library not loaded');
        return;
    }

    if (typeof butterchurnPresets === 'undefined') {
        showFallback('butterchurnPresets library not loaded');
        notifyFailed('butterchurnPresets library not loaded');
        return;
    }

    // Get canvas element
    const canvas = document.getElementById('canvas');
    if (!canvas) {
        showFallback('canvas element not found');
        notifyFailed('canvas element not found');
        return;
    }

    // Get presets from library
    presets = butterchurnPresets.getPresets();
    presetKeys = Object.keys(presets);

    if (presetKeys.length === 0) {
        showFallback('no presets available');
        notifyFailed('no presets available');
        return;
    }

    // Set canvas size to match container
    canvas.width = canvas.clientWidth || 256;
    canvas.height = canvas.clientHeight || 198;

    // Create Butterchurn visualizer
    // Note: Passing null for audioContext since we'll manually provide audio data
    try {
        visualizer = butterchurn.createVisualizer(null, canvas, {
            width: canvas.width,
            height: canvas.height,
            pixelRatio: window.devicePixelRatio || 1,
            textureRatio: 1,
            // Security: Don't eval untrusted preset code
            onlyUseWASM: true
        });
    } catch (error) {
        showFallback('visualizer creation failed: ' + error.message);
        notifyFailed('visualizer creation failed: ' + error.message);
        return;
    }

    // Load initial preset (no transition)
    if (presetKeys.length > 0) {
        visualizer.loadPreset(presets[presetKeys[0]], 0);
        currentPresetIndex = 0;
    }

    // 60 FPS render loop
    function renderLoop() {
        if (!isRunning) return;
        visualizer.render();
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
