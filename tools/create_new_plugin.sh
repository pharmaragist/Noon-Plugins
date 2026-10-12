#!/usr/bin/env bash
#
# create_new_pluin.sh - scaffold a new Noon plugin for pre-development.
#
# Interactively asks for the plugin group, name, maintainer, description and
# version, then creates:
#
#   <plugins>/<group>/<name>/manifest.json   (stub, "singletons": [])
#   <plugins>/<group>/<name>/<name>.qml      (entry stub)
#
# The plugins dir defaults to ~/.noon_plugins and can be overridden with the
# PLUGINS_DIR environment variable.
#
# Usage:
#   ./create_new_pluin.sh
#   PLUGINS_DIR=/tmp/plugins ./create_new_pluin.sh
#   ./create_new_pluin.sh --help
#
set -euo pipefail

PLUGINS_DIR="${PLUGINS_DIR:-$HOME/.noon_plugins}"
PLUGIN_GROUPS=(sidebar dock beam widgets)
DEFAULT_MAINTAINER="big-pickle"
DEFAULT_VERSION="1.0"

usage() {
    cat <<'EOF'
create_new_pluin.sh - scaffold a new Noon plugin for pre-development.

Usage:
  ./create_new_pluin.sh              interactive (uses ~/.noon_plugins)
  PLUGINS_DIR=<dir> ./create_new_pluin.sh
  ./create_new_pluin.sh --help

Environment:
  PLUGINS_DIR   Target plugins root (default: ~/.noon_plugins)

Creates <PLUGINS_DIR>/<group>/<name>/ with a stub manifest.json and <name>.qml.
EOF
}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Escape a value for embedding inside a JSON string.
escape_json() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/\\t}
    s=${s//$'\r'/}
    printf '%s' "$s"
}

# Read a required value (re-prompts until non-empty).
prompt_required() {
    local __var=$1 __label=$2 __val
    while :; do
        read -rp "$__label: " __val || die "input closed"
        [[ -n "$__val" ]] && break
        warn "a value is required"
    done
    printf -v "$__var" '%s' "$__val"
}

# Read a value with a default used when the answer is empty.
prompt_default() {
    local __var=$1 __label=$2 __default=$3 __val
    read -rp "$__label [${__default}]: " __val || die "input closed"
    [[ -z "$__val" ]] && __val=$__default
    printf -v "$__var" '%s' "$__val"
}

select_group() {
    say "Plugin group:"
    local i
    for i in "${!PLUGIN_GROUPS[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${PLUGIN_GROUPS[$i]}"
    done
    local __choice g
    while :; do
        read -rp "Choose group [1-${#PLUGIN_GROUPS[@]}]: " __choice || die "input closed"
        if [[ "$__choice" =~ ^[0-9]+$ ]] &&
            ((__choice >= 1 && __choice <= ${#PLUGIN_GROUPS[@]})); then
            GROUP="${PLUGIN_GROUPS[$((__choice - 1))]}"
            return
        fi
        for g in "${PLUGIN_GROUPS[@]}"; do
            [[ "$__choice" == "$g" ]] && GROUP="$g" && return
        done
        warn "invalid selection"
    done
}

write_manifest() {
    local file=$1 group_body
    local e_name e_maint e_version e_desc
    e_name=$(escape_json "$NAME")
    e_maint=$(escape_json "$MAINTAINER")
    e_version=$(escape_json "$VERSION")
    e_desc=$(escape_json "$DESCRIPTION")

    case "$GROUP" in
        sidebar | widgets)
            group_body=$(cat <<EOF
  "entry": "@plugins/${e_name}.qml",
  "shape": "Cookie12Sided",
  "singletons": []
EOF
            )
            ;;
        dock)
            group_body=$(cat <<EOF
  "entry": "@plugins/${e_name}.qml",
  "direction": "right",
  "singletons": []
EOF
            )
            ;;
        beam)
            group_body=$(cat <<EOF
  "prefix": "@",
  "icon": "bolt",
  "shape": "Oval",
  "placeholder": "Learn More",
  "showHint": true,
  "hinter": "() => { shell('echo \"\$q\"'); return activeHint; }",
  "executor": "() => exec('wl-copy \"\$q\"')",
  "singletons": []
EOF
            )
            ;;
    esac

    cat >"$file" <<EOF
{
  "name": "${e_name}",
  "pluginGroup": "${GROUP}",
  "enabled": true,
  "mentainer": "${e_maint}",
  "version": "${e_version}",
  "description": "${e_desc}",
${group_body}
}
EOF
}

write_qml() {
    local file=$1
    case "$GROUP" in
        sidebar)
            cat >"$file" <<EOF
import QtQuick

import qs.common
import qs.common.widgets
import qs.services

// SidebarItemContainer is a StyledRect that already provides the sidebar API:
//   properties: searchQuery, debouncedQuery, expanded, detached, panelWindow, selectedTabIndex
//   signals:    dismiss, searchFocusRequested, contentFocusRequested, expandRequested, accepted
// Do not redeclare those; just fill it with content.
SidebarItemContainer {
    id: root

    StyledText {
        anchors.centerIn: parent
        text: "${NAME}"
    }
}
EOF
            ;;
        widgets)
            cat >"$file" <<EOF
import QtQuick

import qs.common
import qs.common.widgets
import qs.services

// WidgetContainer picks a size-specific component (small/normal/large/xlarge)
// from the user's chosen widget size and exposes "widgetData" for persistence.
WidgetContainer {
    id: root

    small: StyledText {
        anchors.centerIn: parent
        text: "${NAME}"
    }

    normal: StyledText {
        anchors.centerIn: parent
        text: "${NAME}"
    }
}
EOF
            ;;
        dock)
            cat >"$file" <<EOF
import QtQuick
import QtQuick.Layouts

import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    Layout.preferredWidth: 500
    Layout.fillHeight: true
    Layout.margins: Padding.small

    color: Colors.colPrimary
    radius: Rounding.large

    StyledText {
        anchors.centerIn: parent
        text: "${NAME}"
    }
}
EOF
            ;;
        beam)
            # Beam plugins are manifest-only; this stub is kept for reference.
            cat >"$file" <<EOF
// Beam plugins are driven by manifest.json (hinter/executor) and do not load
// an entry QML file. Kept as a stub for reference.
import QtQuick

Item {
    id: root
}
EOF
            ;;
    esac
}

main() {
    case "${1:-}" in
        -h | --help)
            usage
            exit 0
            ;;
        "") ;;
        *) die "unknown argument: $1 (try --help)" ;;
    esac

    say "Noon plugin scaffold"
    say "Plugins dir: $PLUGINS_DIR"
    say

    select_group
    say
    prompt_required NAME "Plugin name (also the folder and .qml file name)"
    [[ "$NAME" == *"/"* ]] && die "plugin name must not contain '/'"
    [[ "$NAME" == *" "* ]] && warn "names with spaces may not resolve as a QML entry"
    prompt_default MAINTAINER "Maintainer (mentainer)" "$DEFAULT_MAINTAINER"
    prompt_default DESCRIPTION "Description" ""
    prompt_default VERSION "Version" "$DEFAULT_VERSION"

    local dest="$PLUGINS_DIR/$GROUP/$NAME"
    say
    say "About to create:"
    say "  $dest/manifest.json"
    say "  $dest/$NAME.qml"

    if [[ -e "$dest" ]]; then
        local reply
        read -rp "Destination already exists. Overwrite? [y/N]: " reply || die "input closed"
        if [[ ! "$reply" =~ ^[Yy] ]]; then
            say "Aborted."
            exit 0
        fi
        rm -rf "$dest"
    fi

    mkdir -p "$dest"
    write_manifest "$dest/manifest.json"
    write_qml "$dest/$NAME.qml"

    say
    say "Created $GROUP/$NAME"
    say "  $dest/manifest.json"
    say "  $dest/$NAME.qml"
    say
    say "Next:"
    say "  - Edit $NAME.qml to build the plugin."
    say "  - Noon hot-reloads plugins on file change in dev mode."
    say "  - A qmldir is generated automatically when the plugin is enabled."
    if [[ "$GROUP" == "beam" ]]; then
        say "  - Beam plugins run from manifest.json (hinter/executor); the .qml stub is unused."
    fi
}

main "$@"
