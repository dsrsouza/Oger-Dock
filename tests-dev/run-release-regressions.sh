#!/usr/bin/env bash
# Curated Node.js regression tests for Oger Dock 1.0.0. Does not install or modify KDE.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v node >/dev/null 2>&1 || { echo 'Node.js is required for regression tests' >&2; exit 1; }
passed=0
for f in "$ROOT"/tests-dev/test-*.mjs; do
    echo "==> $(basename "$f")"
    node "$f"
    passed=$((passed + 1))
done
printf 'PASS: %d/%d curated regression tests
' "$passed" "$passed"
