pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Noon.Utils
import Quickshell.Io
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root
    readonly property var data: lmsFile.data
    readonly property var materials: data.materials
    readonly property var schedule: data.schedule
    readonly property var grades: data.grades
    readonly property var questions: data.questions
    readonly property var baseCommand: ["uv", "run", root.scraperPath]
    property bool refreshing: false
    property string refreshStatus: ""
    property real dataAge: 0
    property real refreshRotation: 0

    PluginFileView {
        id: lmsFile
        fileName: "lms_data"
        LMSSchema {}
    }

    function subjectColor(name) {
        if (!name)
            return Colors.m3.m3primary;
        var palette = [Colors.m3.m3primary, Colors.m3.m3tertiary, Colors.m3.m3error, Colors.m3.m3success, Colors.m3.m3secondary,];
        var hash = 0;
        for (var i = 0; i < name.length; i++)
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        return palette[Math.abs(hash) % palette.length];
    }

    function subjectContainerColor(name) {
        if (!name)
            return Colors.m3.m3primaryContainer;
        var palette = [Colors.m3.m3primaryContainer, Colors.m3.m3tertiaryContainer, Colors.m3.m3errorContainer, Colors.m3.m3successContainer, Colors.m3.m3secondaryContainer,];
        var hash = 0;
        for (var i = 0; i < name.length; i++)
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        return palette[Math.abs(hash) % palette.length];
    }

    function refreshAll() {
        if (root.refreshing)
            return;
        root.refreshing = true;
        root.refreshStatus = "Refreshing...";
        root.dataAge = 0;
        root.refreshRotation = 0;
        spinAnim.restart();
        refresher.running = true;
    }

    function totalSubjects(obj) {
        var c = 0;
        for (var k in obj) {
            if (obj.hasOwnProperty(k))
                c++;
        }
        return c;
    }
    function downloadFile(url) {
        NoonUtils.execDetached([...baseCommand, "download", "--url", url, "--dist", FileUtils.trimFileProtocol(Paths.standard.downloads)]);
    }

    function totalItems(obj) {
        var c = 0;
        for (var k in obj) {
            if (obj.hasOwnProperty(k) && Array.isArray(obj[k]))
                c += obj[k].length;
        }
        return c;
    }

    readonly property string scraperPath: Paths.plugins.main + "/sidebar/NVU/scraper.py"

    Process {
        id: refresher
        command: [...baseCommand, "lms-data", "--refresh"]
        onStarted: {
            console.log("Refreshing LMS data...", lmsFile.cleanPath);
        }
        environment: ({
                "LMS_DATA_FILE": lmsFile.cleanPath
            })
        onExited: exitCode => {
            root.refreshing = false;
            root.refreshStatus = exitCode === 0 ? "Updated" : "Failed";
            spinAnim.stop();
            statusTimer.restart();
        }
    }

    property string answersSubject: ""
    Process {
        id: answerFetcher
        command: [...baseCommand, "answers", "--sub", root.answersSubject]
        environment: ({
                "LMS_DATA_FILE": lmsFile.cleanPath
            })
        onExited: exitCode => {
            root.refreshing = false;
            root.refreshStatus = exitCode === 0 ? "Answers loaded" : "Answers failed";
            spinAnim.stop();
            statusTimer.restart();
            lmsFile.reload();
        }
    }

    function fetchAnswers(subject) {
        if (root.refreshing)
            return;
        root.answersSubject = subject;
        root.refreshing = true;
        root.refreshStatus = "Fetching answers...";
        spinAnim.restart();
        answerFetcher.running = true;
    }

    NumberAnimation {
        id: spinAnim
        target: root
        property: "refreshRotation"
        from: 0
        to: 360
        duration: 1000
        running: false
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    Timer {
        id: statusTimer
        interval: 4000
        onTriggered: root.refreshStatus = ""
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.dataAge += 1
    }
}
