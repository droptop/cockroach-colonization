#!/bin/bash
# Export the Web build and deploy it to GitHub Pages.
# Usage: ./deploy_web.sh [path-to-godot-binary]
#
# Pushes only the files that changed (the ~40MB wasm rarely does), because
# force-pushing a fresh 40MB history hits "remote end hung up" errors.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${1:-godot}"
REPO_URL="https://github.com/droptop/cockroach-colonization.git"
CLONE_DIR="$(mktemp -d)/pages-clone"

echo "==> Exporting web build..."
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" build/web/index.html

echo "==> Cloning gh-pages..."
git clone -q --depth 1 --branch gh-pages "$REPO_URL" "$CLONE_DIR"
cp -R "$PROJECT_DIR/build/web/." "$CLONE_DIR/"
cd "$CLONE_DIR"
touch .nojekyll
git add -A
if git diff --cached --quiet; then
	echo "==> Nothing changed; live build is already current."
	exit 0
fi
git commit -q -m "Deploy web build $(date +%Y-%m-%d_%H:%M)"
git push -q origin gh-pages
echo "==> Deployed: https://droptop.github.io/cockroach-colonization/"
