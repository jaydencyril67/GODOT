#!/usr/bin/env bash
set -euo pipefail

# Install the exact GDGS revision used by DigitalWorld.
# If the project already vendors a complete addon, leave that copy untouched.
readonly GDGS_REPOSITORY="https://github.com/ReconWorldLab/godot-gaussian-splatting.git"
readonly GDGS_COMMIT="d9de8db86a63e8bf9067c869dcdbd0614922fd1e"
readonly DESTINATION="addons/gdgs"

if [[ -f "${DESTINATION}/plugin.cfg" && -f "${DESTINATION}/runtime/nodes/gaussian_splat_node.gd" ]]; then
  echo "GDGS addon already exists in the repository checkout."
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

git -C "$tmp_dir" init -q
git -C "$tmp_dir" remote add origin "$GDGS_REPOSITORY"
git -C "$tmp_dir" fetch --quiet --depth=1 origin "$GDGS_COMMIT"
git -C "$tmp_dir" checkout --quiet --detach FETCH_HEAD

source_dir="$tmp_dir/addons/gdgs"
test -s "$source_dir/plugin.cfg"
test -s "$source_dir/runtime/nodes/gaussian_splat_node.gd"

mkdir -p "$DESTINATION"
cp -a "$source_dir/." "$DESTINATION/"

test -s "$DESTINATION/plugin.cfg"
test -s "$DESTINATION/runtime/nodes/gaussian_splat_node.gd"
echo "Installed GDGS addon at pinned commit $GDGS_COMMIT."
