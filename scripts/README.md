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

## PR Comment Resolution

**`resolve-pr-comments.sh`** - List, reply to, and resolve PR review comments from automated reviewers (CodeRabbit, Gemini-bot, etc.)

### Usage:

```bash
# List unresolved review threads
./scripts/resolve-pr-comments.sh 53 list

# List ALL threads (including resolved)
./scripts/resolve-pr-comments.sh 53 list-all

# Reply to thread #2 with a message and resolve it
./scripts/resolve-pr-comments.sh 53 reply 2 "False positive. This is a project convention."

# Resolve thread #2 without replying
./scripts/resolve-pr-comments.sh 53 resolve 2

# Resolve ALL unresolved threads at once
./scripts/resolve-pr-comments.sh 53 resolve-all
```

### What it does:

1. Fetches review threads via GitHub GraphQL API
2. Displays thread index, author, file:line, and comment preview
3. Posts replies via REST API (for `reply` command)
4. Resolves threads via GraphQL mutation

**Requires:** `gh` CLI authenticated with repo access

**Perfect for:** Responding to CodeRabbit/Gemini-bot automated review comments

---

## See Also

- **[DEVELOPMENT_TESTING.md](../DEVELOPMENT_TESTING.md)** - Complete testing workflow guide
- **[README.md](../README.md)** - Project overview
