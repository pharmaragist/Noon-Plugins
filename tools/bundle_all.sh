#!/usr/bin/env bash
#
# bundle_all.sh - regenerate the downloadable artifacts from the plugin sources.
#
# Source of truth is plugins/<group>/<slug>/. This script:
#   1. packs every plugins/<group>/<slug>/ into zip/<group>/<slug>.zip
#   2. regenerates plugins.json (the hub index) from the manifests
#
# Nothing is read from zip/ or plugins.json; both are outputs. Commit the
# plugins/<group>/<slug>/ sources and plugins.json, never the zips.
#
# Usage:
#   ./bundle_all.sh                 # pack zips + write plugins.json
#   ./bundle_all.sh --no-zip        # only write plugins.json
#   ./bundle_all.sh --no-index      # only pack zips
#   ./bundle_all.sh --clean         # wipe zip/ before packing
#   ./bundle_all.sh --help
#
# Environment:
#   PREVIEW_BASE    Base URL for preview (thumbnail) links (default: .../main)
#   DOWNLOAD_BASE   Base URL for download (zip) links (default: .../dist)
#   RAW_BASE        Set both at once (overridden by the two above)
#
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
SRC_DIR="$ROOT/plugins"
ZIP_DIR="$ROOT/zip"
INDEX="$ROOT/plugins.json"
THUMBS_DIR="$ROOT/assets/thumbs"

RAW_BASE="${RAW_BASE:-}"
DEFAULT_PREVIEW_BASE="https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/main"
DEFAULT_DOWNLOAD_BASE="https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/dist"
PREVIEW_BASE="${PREVIEW_BASE:-${RAW_BASE:-$DEFAULT_PREVIEW_BASE}}"
DOWNLOAD_BASE="${DOWNLOAD_BASE:-${RAW_BASE:-$DEFAULT_DOWNLOAD_BASE}}"
PREVIEW_BASE="${PREVIEW_BASE%/}"
DOWNLOAD_BASE="${DOWNLOAD_BASE%/}"

HUB_ID="noon-plugins"
HUB_NAME="Noon Plugins"

DO_ZIP=1
DO_INDEX=1
CLEAN=0

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
bundle_all.sh - regenerate the downloadable artifacts from the plugin sources.

Source of truth is plugins/<group>/<slug>/. This script:
  1. packs every plugins/<group>/<slug>/ into zip/<group>/<slug>.zip
  2. regenerates plugins.json (the hub index) from the manifests

Nothing is read from zip/ or plugins.json; both are outputs. Commit the
plugins/<group>/<slug>/ sources and plugins.json, never the zips.

Usage:
  ./bundle_all.sh                 # pack zips + write plugins.json
  ./bundle_all.sh --no-zip        # only write plugins.json
  ./bundle_all.sh --no-index      # only pack zips
  ./bundle_all.sh --clean         # wipe zip/ before packing
  ./bundle_all.sh --help

Environment:
  RAW_BASE   Base URL for preview/download links
             (default: https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/main)
EOF
}

ZIP_EXCLUDES=('-x' '*/__pycache__/*' '*.pyc' '*/__pycache__' '*.DS_Store' '*.swp' '*~')

pack() {
    local group=$1 slug=$2 src="$SRC_DIR/$group/$slug" out="$ZIP_DIR/$group/$slug.zip"
    mkdir -p "$ZIP_DIR/$group"
    rm -f "$out"
    (cd "$SRC_DIR/$group" && zip -q -r -X "$out" "$slug" "${ZIP_EXCLUDES[@]}")
    say "  packed  $group/$slug.zip  ($(du -h "$out" | cut -f1))"
}

index_entry() {
    # Emit one compact JSON object for plugins.json.
    local group=$1 slug=$2 mf="$SRC_DIR/$group/$slug/manifest.json"
    local name mentainer version description icon
    name=$(jq -r '.name // ""' "$mf")
    [[ -n "$name" ]] || { warn "$group/$slug has no manifest .name; using slug"; name=$slug; }
    mentainer=$(jq -r '.mentainer // .maintainer // ""' "$mf")
    version=$(jq -r '.version // ""' "$mf")
    description=$(jq -r '.description // ""' "$mf")
    icon=$(jq -r '.icon // ""' "$mf")

    if [[ ! -f "$THUMBS_DIR/$group/$slug.png" ]]; then
        warn "missing thumbnail: assets/thumbs/$group/$slug.png"
    fi

    jq -cn \
        --arg id "$slug" \
        --arg name "$name" \
        --arg group "$group" \
        --arg description "$description" \
        --arg version "$version" \
        --arg maintainer "$mentainer" \
        --arg preview "$PREVIEW_BASE/assets/thumbs/$group/$slug.png" \
        --arg download "$DOWNLOAD_BASE/zip/$group/$slug.zip" \
        --arg icon "$icon" \
        '{id: $id, name: $name, group: $group, description: $description,
          version: $version, maintainer: $maintainer, preview: $preview,
          download: $download, icon: $icon}'
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-zip) DO_ZIP=0 ;;
            --no-index) DO_INDEX=0 ;;
            --clean) CLEAN=1 ;;
            -h | --help) usage; exit 0 ;;
            *) die "unknown argument: $1 (try --help)" ;;
        esac
        shift
    done

    [[ -d "$SRC_DIR" ]] || die "no plugins/ directory at $SRC_DIR"
    command -v jq >/dev/null || die "jq is required"
    if [[ "$DO_ZIP" -eq 1 ]]; then command -v zip >/dev/null || die "zip is required"; fi

    local dirs=()
    while IFS= read -r d; do dirs+=("$d"); done < <(find "$SRC_DIR" -mindepth 2 -maxdepth 2 -type d | sort)
    [[ ${#dirs[@]} -gt 0 ]] || die "no plugins found under $SRC_DIR/<group>/<slug>/"

    if [[ "$CLEAN" -eq 1 ]]; then
        rm -rf "$ZIP_DIR"
        say "cleaned $ZIP_DIR"
    fi

    local group slug mf
    if [[ "$DO_ZIP" -eq 1 ]]; then
        say "Packing plugins:"
        for d in "${dirs[@]}"; do
            group=$(basename "$(dirname "$d")")
            slug=$(basename "$d")
            mf="$d/manifest.json"
            [[ -f "$mf" ]] || { warn "skipping $group/$slug: no manifest.json"; continue; }
            pack "$group" "$slug"
        done
    fi

    if [[ "$DO_INDEX" -eq 1 ]]; then
        local tmp
        tmp=$(mktemp)
        : >"$tmp"
        for d in "${dirs[@]}"; do
            group=$(basename "$(dirname "$d")")
            slug=$(basename "$d")
            mf="$d/manifest.json"
            [[ -f "$mf" ]] || continue
            index_entry "$group" "$slug" >>"$tmp"
        done
        jq -s --arg id "$HUB_ID" --arg name "$HUB_NAME" \
            '{id: $id, name: $name, plugins: .}' "$tmp" >"$INDEX.new"
        mv "$INDEX.new" "$INDEX"
        rm -f "$tmp"
        say "Wrote plugins.json ($(jq '.plugins | length' "$INDEX") plugins)"
    fi
}

main "$@"
