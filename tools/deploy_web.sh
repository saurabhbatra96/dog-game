#!/usr/bin/env bash
# Exports the web build and publishes it to the gh-pages branch of the
# "origin" remote, which is what GitHub Pages serves.
#
#   tools/deploy_web.sh
#
# The gh-pages branch is replaced on every run: it only ever holds the latest
# build, never the source.
set -euo pipefail
cd "$(dirname "$0")/.."

remote=$(git remote get-url origin)

rm -rf build/web
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html

# Tell GitHub Pages to serve the files as they are.
touch build/web/.nojekyll

cd build/web
git init -q -b gh-pages
git add -A
git commit -q -m "Deploy web build"
git push -f "$remote" gh-pages
rm -rf .git

echo "Published. GitHub Pages usually updates within a minute or two."
