// Butterchurn Bridge - Swift ↔ JavaScript communication
console.log('🟡 Butterchurn bridge.js loaded');

(function() {
    console.log('🟡 Butterchurn IIFE started');

    let visualizer = null;
    let presets = [];
    let currentPresetIndex = 0;
    let audioContext = null;

    // Initialize Butterchurn
    function init() {
        console.log('🟡 Butterchurn init() called');
        try {
            const canvas = document.getElementById('canvas');
            if (!canvas) {
                console.error('❌ Canvas element not found');
                return;
            }
            console.log('✅ Canvas found:', canvas);

            // Get canvas dimensions
            const width = canvas.clientWidth;
            const height = canvas.clientHeight;

            // Create Butterchurn visualizer
            visualizer = window.butterchurn.createVisualizer(audioContext || new AudioContext(), canvas, {
                width: width,
                height: height,
                pixelRatio: window.devicePixelRatio || 1,
                textureRatio: 1
            });

            // Load curated presets from minimal bundle
            const allPresets = window.butterchurnPresets.getPresets();
            const presetNames = Object.keys(allPresets);

            // Select 5-8 high-quality presets
            const curatedNames = [
                'Geiss - Spiral Artifact',
                'Martin - Mandelbox Explorer',
                'Flexi - Predator-Prey',
                'Rovastar - Altars of Madness',
                'Unchained - Lucid Concentration'
            ].filter(name => presetNames.includes(name));

            presets = curatedNames.map(name => allPresets[name]);

            // Load first preset
            if (presets.length > 0) {
                visualizer.loadPreset(presets[0], 2.7);  // 2.7s transition
                currentPresetIndex = 0;
            }

            // Start render loop
            requestAnimationFrame(render);

            // Notify Swift that we're ready
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ready) {
                window.webkit.messageHandlers.ready.postMessage('initialized');
            }

            console.log('Butterchurn initialized with', presets.length, 'presets');
        } catch (error) {
            console.error('Butterchurn initialization failed:', error);
        }
    }

    // Render loop
    function render() {
        if (visualizer) {
            visualizer.render();
        }
        requestAnimationFrame(render);
    }

    // Update audio data from Swift (called at ~60fps)
    window.updateAudioData = function(fftData, waveformData) {
        if (!visualizer) return;

        // Convert arrays to typed arrays if needed
        const fft = new Uint8Array(fftData || []);
        const waveform = new Float32Array(waveformData || []);

        // Butterchurn expects frequency and waveform data
        // Note: We'll need to adapt MacAmp's audio tap data format
        // For now, pass through and let Butterchurn handle it
    };

    // Load specific preset by index
    window.loadPreset = function(index) {
        if (!visualizer || !presets[index]) return;
        visualizer.loadPreset(presets[index], 2.7);
        currentPresetIndex = index;
    };

    // Cycle to next preset
    window.nextPreset = function() {
        const nextIndex = (currentPresetIndex + 1) % presets.length;
        window.loadPreset(nextIndex);
    };

    // Cycle to previous preset
    window.previousPreset = function() {
        const prevIndex = (currentPresetIndex - 1 + presets.length) % presets.length;
        window.loadPreset(prevIndex);
    };

    // Handle window resize
    window.addEventListener('resize', function() {
        if (visualizer) {
            const canvas = document.getElementById('canvas');
            visualizer.setRendererSize(canvas.clientWidth, canvas.clientHeight);
        }
    });

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
