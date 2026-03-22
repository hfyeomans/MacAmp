#!/usr/bin/env bash
set -euo pipefail

lang="swift"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)
      if [[ $# -lt 2 ]]; then
        echo "error: --lang requires a value" >&2
        exit 1
      fi
      lang="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 ]]; then
  echo "usage: $0 [--lang <language>] <root> <symbol> [symbol ...]" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg is required" >&2
  exit 1
fi

if ! command -v ast-grep >/dev/null 2>&1; then
  echo "error: ast-grep is required" >&2
  exit 1
fi

root="$1"
shift

echo "# Duplicate Path Inventory"
echo
echo "root: $root"
echo "lang: $lang"
echo

for symbol in "$@"; do
  echo "## symbol: $symbol"
  echo

  pattern="\\b${symbol}\\s*\\("
  raw_matches="$(rg -n --glob '*.swift' --glob '!**/.build/**' --glob '!**/node_modules/**' "$pattern" "$root" || true)"
  matches="$(printf '%s\n' "$raw_matches" | rg -v ":[0-9]+:.*\\bfunc\\b.*\\b${symbol}\\s*\\(" || true)"

  if [[ -z "$matches" ]]; then
    echo "No raw call-site matches found."
    echo
    continue
  fi

  count="$(printf '%s\n' "$matches" | wc -l | tr -d ' ')"
  echo "Raw call-site count: $count"
  echo
  printf '%s\n' "$matches"
  echo
done

echo "## Context scans"
echo

if [[ "$lang" == "swift" ]]; then
  echo "### MainActor task entry points"
  ast-grep --lang swift -p 'Task { @MainActor in $$$BODY }' "$root" || true
  echo

  echo "### onAppear handlers"
  ast-grep --lang swift -p '.onAppear { $$$BODY }' "$root" || true
  echo

  echo "### onChange handlers"
  ast-grep --lang swift -p '.onChange(of: $$$VALUE) { $$$BODY }' "$root" || true
  echo

  echo "### NotificationCenter observer registration"
  ast-grep --lang swift -p 'NotificationCenter.default.addObserver($$$ARGS)' "$root" || true
else
  echo "No built-in language-specific context scans for '$lang'."
  echo "Load the relevant modular reference and run language-appropriate ast-grep patterns."
fi
