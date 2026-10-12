pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root

    property var vms: []
    property bool loading: false
    property string errorMessage: ""
    property bool actionInProgress: false

    signal error(string message)

    readonly property var stateMeta: ({
        "running":    { icon: "check_circle",   color: Colors.colSuccess },
        "shut off":   { icon: "radio_button_unchecked", color: Colors.colSubtext },
        "paused":     { icon: "pause_circle",   color: Colors.colTertiary },
        "suspended":  { icon: "pause_circle",   color: Colors.colTertiary },
        "in shutdown":{ icon: "power_settings_new", color: Colors.colTertiary },
        "crashed":    { icon: "error",           color: Colors.colError },
        "dying":      { icon: "error",           color: Colors.colError },
    })

    function stateIcon(state) {
        var m = root.stateMeta[state]
        return m ? m.icon : "help"
    }

    function stateColor(state) {
        var m = root.stateMeta[state]
        return m ? m.color : Colors.colSubtext
    }

    function isRunning(state) { return state === "running" }
    function isStopped(state) { return state === "shut off" }

    function runningCount() {
        var c = 0
        for (var i = 0; i < root.vms.length; i++)
            if (root.vms[i].isActive) c++
        return c
    }

    function refresh() {
        if (listProc.running || root.actionInProgress) return
        root.loading = true
        listProc.running = true
    }

    Process {
        id: listProc
        command: ["virsh", "-c", "qemu:///system", "list", "--all"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                var result = []

                for (var i = 2; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line.trim()) continue

                    var m = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/)
                    if (!m) continue

                    var id = m[1]
                    result.push({
                        name: m[2],
                        state: m[3].trim(),
                        isActive: id !== "-",
                        id: id
                    })
                }

                root.vms = result
                root.loading = false
                root.errorMessage = ""
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error(text.trim())
            }
        }

        onExited: exitCode => {
            root.loading = false
            if (exitCode !== 0 && root.vms.length === 0) {
                var msg = "virsh exited with code " + exitCode
                root.errorMessage = msg
                root.error(msg)
            }
        }
    }

    Process {
        id: actionProc
        command: []

        onStarted: root.actionInProgress = true

        onExited: exitCode => {
            root.actionInProgress = false
            if (exitCode !== 0) {
                root.errorMessage = "Action failed (code " + exitCode + ")"
                root.error(root.errorMessage)
            }
            actionTimer.restart()
        }
    }

    Timer {
        id: pollTimer
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: actionTimer
        interval: 800
        onTriggered: root.refresh()
    }

    function _runAction(args) {
        if (root.actionInProgress) return
        actionProc.command = ["virsh", "-c", "qemu:///system"].concat(args)
        actionProc.running = true
    }

    function startVM(name)   { _runAction(["start", name]) }
    function shutdownVM(name){ _runAction(["shutdown", name]) }
    function destroyVM(name) { _runAction(["destroy", name]) }
    function rebootVM(name)  { _runAction(["reboot", name]) }

    Component.onCompleted: root.refresh()
}
