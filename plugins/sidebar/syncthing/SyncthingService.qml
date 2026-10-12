pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Noon.Utils
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root

    readonly property var data: stFile.data
    readonly property var folders: data.folders
    readonly property var devices: data.devices
    readonly property var systemInfo: data.systemInfo
    readonly property var connections: data.connections
    readonly property var events: data.events
    readonly property bool connected: data.connected
    readonly property string connectionStatus: data.connectionStatus
    readonly property string actionFeedback: data.actionFeedback || ""

    property bool refreshing: false
    property bool actionInProgress: false
    property real dataAge: 0

    PluginFileView {
        id: stFile
        fileName: "syncthing_data"
        SyncthingSchema {}
    }

    readonly property string scriptPath: Paths.plugins.main + "/sidebar/syncthing/syncthing_client.py"

    Process {
        id: poller
        command: ["uv", "run", root.scriptPath]
        onStarted: root.refreshing = true
        environment: ({ "STGN_DATA_FILE": stFile.cleanPath })
        onExited: exitCode => {
            root.refreshing = false;
            stFile.reload();
            if (root.actionFeedback)
                feedbackTimer.restart();
        }
    }

    Process {
        id: actionPoller
        command: []
        onStarted: { root.actionInProgress = true; root.refreshing = true; }
        environment: ({ "STGN_DATA_FILE": stFile.cleanPath })
        onExited: exitCode => {
            root.actionInProgress = false;
            root.refreshing = false;
            pollTimer.restart();
            stFile.reload();
            if (root.actionFeedback)
                feedbackTimer.restart();
        }
    }

    Timer {
        id: feedbackTimer
        interval: 3000
        onTriggered: {
            if (stFile && stFile.data)
                stFile.data.actionFeedback = "";
        }
    }

    function refresh() {
        if (root.refreshing && !root.actionInProgress)
            return;
        poller.running = true;
    }

    function runAction(cmdParts) {
        if (root.actionInProgress)
            return;
        actionPoller.command = ["uv", "run", root.scriptPath].concat(cmdParts);
        actionPoller.running = true;
    }

    function folderPause(folderId) { runAction(["pause", folderId]); }
    function folderResume(folderId) { runAction(["resume", folderId]); }
    function folderRescan(folderId) { runAction(["rescan", folderId]); }

    function devicePause(deviceId) { runAction(["device-pause", deviceId]); }
    function deviceResume(deviceId) { runAction(["device-resume", deviceId]); }

    function restartSt() { runAction(["restart"]); }
    function refreshNow() { runAction(["refresh"]); }

    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.dataAge += 1
    }

    function folderCount() {
        var c = 0;
        for (var k in root.folders) { if (root.folders.hasOwnProperty(k)) c++; }
        return c;
    }

    function deviceCount() {
        var c = 0;
        for (var k in root.devices) { if (root.devices.hasOwnProperty(k)) c++; }
        return c;
    }

    function connectedDeviceCount() {
        var c = 0;
        for (var k in root.devices) { if (root.devices.hasOwnProperty(k) && root.devices[k].connected) c++; }
        return c;
    }

    function pausedDeviceCount() {
        var c = 0;
        for (var k in root.devices) { if (root.devices.hasOwnProperty(k) && root.devices[k].paused) c++; }
        return c;
    }

    function totalNeedFiles() {
        var t = 0;
        for (var k in root.folders) { if (root.folders.hasOwnProperty(k)) t += root.folders[k].needFiles || 0; }
        return t;
    }

    function totalNeedBytes() {
        var t = 0;
        for (var k in root.folders) { if (root.folders.hasOwnProperty(k)) t += root.folders[k].needBytes || 0; }
        return t;
    }

    function formatBytes(bytes) {
        if (!bytes || bytes === 0) return "0 B";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var i = 0; var b = bytes;
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++; }
        return b.toFixed(i > 0 ? 1 : 0) + " " + units[i];
    }

    function formatUptime(seconds) {
        if (!seconds) return "—";
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 24) return Math.floor(h / 24) + "d " + (h % 24) + "h";
        return h + "h " + m + "m";
    }

    function folderStatus(folderId) {
        var f = root.folders[folderId];
        if (!f) return "unknown";
        if (f.paused) return "paused";
        if (f.needFiles > 0) return "syncing";
        if (f.completion >= 100) return "synced";
        return "syncing";
    }

    function folderStatusColor(status) {
        switch (status) {
        case "synced": return Colors.colSuccess;
        case "syncing": return Colors.colTertiary;
        case "paused": return Colors.colSubtext;
        default: return Colors.colError;
        }
    }

    function folderActionIcon(folderId) {
        var f = root.folders[folderId];
        return f && f.paused ? "play_arrow" : "pause";
    }

    function eventIcon(type) {
        switch (type) {
        case "ItemStarted": return "sync";
        case "StateChanged": return "info";
        case "RemoteIndexUpdated": return "download";
        case "LocalIndexUpdated": return "upload";
        default: return "info";
        }
    }

    function deviceActionIcon(deviceId) {
        var d = root.devices[deviceId];
        return d && d.paused ? "play_arrow" : "pause";
    }
}
