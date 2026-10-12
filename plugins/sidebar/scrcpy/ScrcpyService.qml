pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import Scrcpy

Singleton {
    id: root

    readonly property var presets: [
        {
            label: "Low",
            maxSize: 720,
            bitRate: 4000000,
            maxFps: 30
        },
        {
            label: "Med",
            maxSize: 1080,
            bitRate: 12000000,
            maxFps: 60
        },
        {
            label: "High",
            maxSize: 1920,
            bitRate: 20000000,
            maxFps: 60
        },
        {
            label: "Native",
            maxSize: 0,
            bitRate: 30000000,
            maxFps: 0
        }
    ]

    readonly property var settings: settingsView.data
    readonly property int qualityIndex: settings ? settings.qualityIndex : 2
    readonly property bool hardwareDecode: settings ? settings.hardwareDecode : true
    readonly property bool autoConnect: settings ? settings.autoConnect : true
    readonly property bool trackpadOptimizations: settings ? settings.trackpadOptimizations : true
    readonly property string savedSerial: settings ? settings.serial : ""

    readonly property bool connected: view.connected
    readonly property string serial: view.serial
    readonly property size frameSize: view.frameSize
    readonly property string errorString: view.errorString

    property var devices: []
    property bool autoTried: false

    PluginFileView {
        id: settingsView
        fileName: "scrcpy"
        JsonAdapter {
            property string serial: ""
            property int qualityIndex: 2
            property bool hardwareDecode: true
            property bool autoConnect: true
            property bool trackpadOptimizations: true
        }
    }

    ScrcpyView {
        id: view
        hardwareDecode: root.hardwareDecode
        trackpadOptimizations: root.trackpadOptimizations
        onErrorOccurred: message => NoonUtils.toast({
                header: "Scrcpy",
                content: message,
                icon: "screen_share",
                status: "error"
            })
        onFileTransferFinished: (success, isApk) => NoonUtils.toast({
                header: "Scrcpy",
                content: (isApk ? "APK install" : "File transfer") + (success ? " complete" : " failed"),
                icon: success ? "check" : "error",
                status: success ? "success" : "error"
            })
    }

    Component.onCompleted: {
        root.applyQuality();
        root.refreshDevices();
    }

    function applyQuality() {
        const preset = root.presets[root.qualityIndex] ?? root.presets[2];
        view.maxSize = preset.maxSize;
        view.bitRate = preset.bitRate;
        view.maxFps = preset.maxFps;
    }

    function setQualityIndex(index) {
        if (settingsView.data)
            settingsView.data.qualityIndex = index;
        root.applyQuality();
        root.reconnect();
    }

    function setHardwareDecode(enabled) {
        if (settingsView.data)
            settingsView.data.hardwareDecode = enabled;
        root.reconnect();
    }

    function setAutoConnect(enabled) {
        if (settingsView.data)
            settingsView.data.autoConnect = enabled;
    }

    function setTrackpadOptimizations(enabled) {
        if (settingsView.data)
            settingsView.data.trackpadOptimizations = enabled;
    }

    function connectTo(serial) {
        const target = (serial ?? root.savedSerial ?? "").trim();
        if (target.length === 0)
            return;
        if (settingsView.data)
            settingsView.data.serial = target;
        root.applyQuality();
        view.serial = target;
        view.start(target);
    }

    function disconnect() {
        view.stop();
    }

    function toggle() {
        if (view.connected)
            root.disconnect();
        else
            root.connectTo();
    }

    function reconnect() {
        if (!view.connected)
            return;
        view.stop();
        view.start(view.serial);
    }

    function refreshDevices() {
        root.devices = view.adbDevices();
        if (root.autoTried || !root.autoConnect || view.connected || root.devices.length !== 1)
            return;
        root.autoTried = true;
        root.connectTo(root.devices[0]);
    }

    function findAdb() {
        return view.findAdb();
    }

    function attachSink(sink) {
        view.videoSink = sink;
    }

    function detachSink() {
        view.videoSink = null;
    }

    function contentRect(width, height) {
        return view.contentRect(width, height);
    }

    function press(nx, ny) {
        view.pointer(ScrcpyView.PointerPress, nx, ny, 0);
    }

    function release(nx, ny) {
        view.pointer(ScrcpyView.PointerRelease, nx, ny, 0);
    }

    function move(nx, ny) {
        view.pointer(ScrcpyView.PointerMove, nx, ny, 0);
    }

    function rightPress(nx, ny) {
        view.pointer(ScrcpyView.PointerRightPress, nx, ny, 0);
    }

    function rightRelease(nx, ny) {
        view.pointer(ScrcpyView.PointerRightRelease, nx, ny, 0);
    }

    function wheel(nx, ny, dx, dy) {
        view.wheel(nx, ny, dx, dy);
    }

    function scroll(nx, ny, dx, dy) {
        view.scroll(nx, ny, dx, dy);
    }

    function keyPress(qtKey, modifiers, autoRepeat) {
        view.key(ScrcpyView.KeyPress, qtKey, modifiers, autoRepeat ?? false);
    }

    function keyRelease(qtKey, modifiers, autoRepeat) {
        view.key(ScrcpyView.KeyRelease, qtKey, modifiers, autoRepeat ?? false);
    }

    function back() {
        view.back();
    }

    function home() {
        view.home();
    }

    function recents() {
        view.recents();
    }

    function fileNameOf(fileUrl) {
        const s = String(fileUrl);
        const i = s.lastIndexOf("/");
        return i >= 0 ? s.substring(i + 1) : s;
    }

    function installApk(fileUrl) {
        NoonUtils.toast({
            header: "Scrcpy",
            content: "Installing " + root.fileNameOf(fileUrl) + "…",
            icon: "android",
            status: "normal"
        });
        view.installApk(String(fileUrl));
    }

    function pushFile(fileUrl, deviceDir) {
        NoonUtils.toast({
            header: "Scrcpy",
            content: "Sending " + root.fileNameOf(fileUrl) + "…",
            icon: "upload_file",
            status: "normal"
        });
        view.pushFile(String(fileUrl), deviceDir ?? "/sdcard/");
    }
}
