#!/bin/bash
# Export the Web build and deploy it to GitHub Pages.
#
# TWO CHANNELS, one branch. gh-pages serves its whole tree, so a subdirectory is
# a second site for free: no extra repo, no extra host, no DNS.
#
#   stable   https://droptop.github.io/cockroach-colonization/
#   preview  https://droptop.github.io/cockroach-colonization/preview/
#
# PREVIEW IS THE DEFAULT, on purpose. Every deploy used to overwrite the only
# URL there was, so the build being played and the build being worked on were
# always the same one, and a bad afternoon replaced a good morning with no way
# back.
#
# Usage:
#   ./deploy_web.sh [path-to-godot]              -> preview  (default)
#   ./deploy_web.sh [path-to-godot] --stable     -> stable, straight from source
#   ./deploy_web.sh [path-to-godot] --promote    -> copy the CURRENT preview to
#                                                   stable, no re-export, so what
#                                                   goes live is what was played
#
# Pushes only the files that changed (the ~40MB wasm rarely does), because
# force-pushing a fresh 40MB history hits "remote end hung up" errors.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="godot"
MODE="preview"
for arg in "$@"; do
	case "$arg" in
		--preview) MODE="preview" ;;
		--stable)  MODE="stable" ;;
		--promote) MODE="promote" ;;
		*)         GODOT="$arg" ;;
	esac
done

REPO_URL="https://github.com/droptop/cockroach-colonization.git"
CLONE_DIR="$(mktemp -d)/pages-clone"
BASE_URL="https://droptop.github.io/cockroach-colonization"

if [ "$MODE" != "promote" ]; then
	echo "==> Exporting web build..."
	"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" build/web/index.html
fi

echo "==> Cloning gh-pages..."
git clone -q --depth 1 --branch gh-pages "$REPO_URL" "$CLONE_DIR"

case "$MODE" in
	preview)
		mkdir -p "$CLONE_DIR/preview"
		cp -R "$PROJECT_DIR/build/web/." "$CLONE_DIR/preview/"
		TARGET="$BASE_URL/preview/"
		;;
	stable)
		cp -R "$PROJECT_DIR/build/web/." "$CLONE_DIR/"
		TARGET="$BASE_URL/"
		;;
	promote)
		if [ ! -f "$CLONE_DIR/preview/index.pck" ]; then
			echo "==> Nothing in preview to promote. Deploy a preview first."
			exit 1
		fi
		# Everything the export produces, and nothing else: copying the whole
		# directory would drag preview/ into the root and nest it forever.
		for f in "$CLONE_DIR"/preview/*; do
			[ -f "$f" ] && cp "$f" "$CLONE_DIR/"
		done
		TARGET="$BASE_URL/  (promoted from preview)"
		;;
esac

cd "$CLONE_DIR"
touch .nojekyll
git add -A
if git diff --cached --quiet; then
	echo "==> Nothing changed; $MODE is already current."
	exit 0
fi
git commit -q -m "Deploy web build ($MODE) $(date +%Y-%m-%d_%H:%M)"
git push -q origin gh-pages
echo "==> Deployed [$MODE]: $TARGET"
echo "    Verify: curl -s $BASE_URL/${MODE:+$([ "$MODE" = preview ] && echo 'preview/')}index.pck | md5"
