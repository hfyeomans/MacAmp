# MacAmp Development Scripts

## Quick Install - Automated Build & Test

**`quick-install.sh`** - Fast build and install to /Applications

### Usage:

```bash
# From terminal (requires sudo password):
cd /Users/hank/dev/src/MacAmp

# Debug build (30-40 seconds)
./scripts/quick-install.sh

# Release build (60-90 seconds)
./scripts/quick-install.sh Release
```

### What it does:

1. Kills running MacAmp
2. Builds app (Debug or Release)
3. Verifies code signature
4. Installs to /Applications/MacAmp.app
5. Launches the app

**Perfect for:** Rapid testing during development

---

## Distribution Verification

**`verify-dist-signature.sh`** - Verify code signing for distribution

### Usage:

```bash
# Verify dist/MacAmp.app signature
./scripts/verify-dist-signature.sh

# Or specify custom path
./scripts/verify-dist-signature.sh /path/to/MacAmp.app
```

**Use before:** Creating GitHub releases or distributing to users

---

## See Also

- **[DEVELOPMENT_TESTING.md](../DEVELOPMENT_TESTING.md)** - Complete testing workflow guide
- **[README.md](../README.md)** - Project overview
