import QtQuick
import QtQuick.Layouts
import QtMultimedia
import qs.common
import qs.common.widgets
import "./"

SidebarItemContainer {
    id: root

    readonly property var svc: ScrcpyService

    property bool settingsOpen: false
    property bool dropActive: false

    property Item focusItem: root

    focus: true

    Keys.onPressed: event => {
        const mods = event.modifiers;
        if (event.key === Qt.Key_Escape)
            return;
        if ((mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return;
        root.svc.keyPress(event.key, mods, event.isAutoRepeat);
        event.accepted = true;
    }

    Keys.onReleased: event => {
        const mods = event.modifiers;
        if (event.key === Qt.Key_Escape)
            return;
        if ((mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0)
            return;
        root.svc.keyRelease(event.key, mods, event.isAutoRepeat);
        event.accepted = true;
    }

    onSettingsOpenChanged: settings.show = root.settingsOpen

    function statusText() {
        if (svc.connected) {
            const size = svc.frameSize;
            return size.width > 0 ? svc.serial + "  ·  " + size.width + " × " + size.height : svc.serial;
        }
        if (svc.errorString.length > 0)
            return svc.errorString;
        if (svc.devices.length > 0)
            return svc.devices.length + " device(s) available";
        return "No device found";
    }

    function toContent(x, y) {
        const r = svc.contentRect(preview.width, preview.height);
        if (r.width <= 0 || r.height <= 0)
            return null;
        const nx = (x - r.x) / r.width;
        const ny = (y - r.y) / r.height;
        if (nx < 0 || nx > 1 || ny < 0 || ny > 1)
            return null;
        return {
            nx: nx,
            ny: ny
        };
    }

    BottomDialog {
        id: settings

        z: root.settingsOpen ? 5 : -1
        revealOnWheel: false
        bottomAreaReveal: true
        enableStagedReveal: false
        hoverHeight: 0
        baseHeight: 520
        onShowChanged: root.settingsOpen = show

        contentItem: CLayout {
            anchors.fill: parent
            anchors.margins: Padding.massive
            spacing: Padding.large

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 4
                radius: Rounding.full
                color: Colors.colOutlineVariant
            }

            RLayout {
                Layout.fillWidth: true
                Layout.topMargin: Padding.tiny
                spacing: Padding.small

                CLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        truncate: true
                        text: "Screen mirror"
                        font: Fonts.request("title", "subTitle")
                        color: Colors.colOnLayer2
                    }

                    StyledText {
                        Layout.fillWidth: true
                        truncate: true
                        text: root.statusText()
                        font.pixelSize: Fonts.sizes.small
                        color: root.svc.connected ? Colors.colPrimary : Colors.colSubtext
                    }
                }

                RippleButtonWithIcon {
                    implicitSize: 40
                    materialIcon: "close"
                    onClicked: root.settingsOpen = false
                }
            }

            StyledFlickable {
                id: scroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: body.implicitHeight
                clip: true

                CLayout {
                    id: body

                    width: scroll.width
                    spacing: Padding.verylarge

                    ContentSubsection {
                        title: "Device"

                        RLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Padding.small
                            spacing: Padding.small

                            StyledTextField {
                                id: serialField
                                Layout.fillWidth: true
                                placeholderText: "device serial or ip:port"
                                text: root.svc.savedSerial
                                onAccepted: root.svc.connectTo(text)
                            }

                            RippleButtonWithIcon {
                                implicitSize: 40
                                materialIcon: "sync"
                                onClicked: root.svc.refreshDevices()
                            }
                        }

                        StyledFlow {
                            Layout.fillWidth: true
                            Layout.topMargin: root.svc.devices.length > 0 ? Padding.small : 0
                            spacing: Padding.small

                            Repeater {
                                model: root.svc.devices

                                delegate: StyledRect {
                                    id: chip

                                    required property var modelData

                                    readonly property bool selected: serialField.text === modelData

                                    implicitWidth: chipLabel.implicitWidth + Padding.huge
                                    implicitHeight: 30
                                    radius: Rounding.full
                                    color: chip.selected ? Colors.colPrimaryContainer : Colors.colLayer3

                                    StyledText {
                                        id: chipLabel
                                        anchors.centerIn: parent
                                        text: chip.modelData
                                        font.pixelSize: Fonts.sizes.verysmall
                                        color: chip.selected ? Colors.colOnPrimaryContainer : Colors.colOnLayer1
                                    }

                                    TapHandler {
                                        onTapped: serialField.text = chip.modelData
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: Padding.small
                            visible: root.svc.devices.length === 0
                            truncate: true
                            text: "No devices detected. Connect over USB or wireless adb, then scan."
                            font.pixelSize: Fonts.sizes.verysmall
                            color: Colors.colSubtext
                        }
                    }

                    ContentSubsection {
                        title: "Quality"

                        SegmentedButtonGroup {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Padding.small
                            content: root.svc.presets.map(p => p.label)
                            selectedIndex: root.svc.qualityIndex
                            onSelectedIndexChanged: root.svc.setQualityIndex(selectedIndex)
                        }
                    }

                    ContentSubsection {
                        title: "Options"

                        SettingRow {
                            Layout.fillWidth: true
                            Layout.topMargin: Padding.small
                            icon: "swipe"
                            name: "Trackpad optimizations"
                            description: "Scroll by flicking instead of discrete wheel steps"
                            value: root.svc.trackpadOptimizations
                            onToggled: root.svc.setTrackpadOptimizations(checked)
                        }

                        SettingRow {
                            Layout.fillWidth: true
                            icon: "memory"
                            name: "Hardware decode"
                            description: "Accelerate with VA-API when available"
                            value: root.svc.hardwareDecode
                            onToggled: root.svc.setHardwareDecode(checked)
                        }

                        SettingRow {
                            Layout.fillWidth: true
                            icon: "cable"
                            name: "Auto-connect"
                            description: "Connect automatically when one device is found"
                            value: root.svc.autoConnect
                            onToggled: root.svc.setAutoConnect(checked)
                        }
                    }
                }
            }

            Separator {}

            RLayout {
                Layout.fillWidth: true
                spacing: Padding.small

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colSubtext
                    verticalAlignment: Text.AlignVCenter
                    text: {
                        const adb = root.svc.findAdb();
                        return adb.length > 0 ? "adb: " + adb : "adb not found in PATH";
                    }
                }

                DialogButton {
                    buttonText: root.svc.connected ? "Disconnect" : "Connect"
                    toggled: root.svc.connected
                    releaseAction: () => {
                        if (root.svc.connected)
                            root.svc.disconnect();
                        else
                            root.svc.connectTo(serialField.text);
                    }
                }
            }
        }
    }

    component SettingRow: StyledRect {
        id: row

        property string icon: ""
        property string name: ""
        property string description: ""
        property bool value: false

        signal toggled(bool checked)

        implicitHeight: 58
        radius: Rounding.large
        color: Colors.colLayer3

        RLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.large
            anchors.rightMargin: Padding.large
            spacing: Padding.large

            StyledRect {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: Rounding.full
                color: row.value ? Colors.colPrimary : Colors.colSurfaceContainerHighest

                Symbol {
                    anchors.centerIn: parent
                    icon: row.icon
                    iconSize: 20
                    fill: 1
                    color: row.value ? Colors.colOnPrimary : Colors.colOnLayer3
                }
            }

            CLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    text: row.name
                    color: Colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    text: row.description
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colSubtext
                }
            }

            StyledSwitch {
                checked: row.value
                onToggled: row.toggled(checked)
            }
        }
    }

    CLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.small

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            clip: true
            color: Colors.colLayer1
            radius: Rounding.verylarge

            VideoOutput {
                id: preview
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
                Component.onCompleted: root.svc.attachSink(videoSink)
                Component.onDestruction: root.svc.detachSink()
            }

            Item {
                anchors.fill: parent
                enabled: root.svc.connected
                visible: root.svc.connected

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: mouse => {
                        root.forceActiveFocus();
                        const p = root.toContent(mouse.x, mouse.y);
                        if (!p)
                            return;
                        if (mouse.button === Qt.RightButton)
                            root.svc.rightPress(p.nx, p.ny);
                        else
                            root.svc.press(p.nx, p.ny);
                    }
                    onPositionChanged: mouse => {
                        const p = root.toContent(mouse.x, mouse.y);
                        if (p)
                            root.svc.move(p.nx, p.ny);
                    }
                    onReleased: mouse => {
                        const p = root.toContent(mouse.x, mouse.y);
                        if (!p)
                            return;
                        if (mouse.button === Qt.RightButton)
                            root.svc.rightRelease(p.nx, p.ny);
                        else
                            root.svc.release(p.nx, p.ny);
                    }
                    onWheel: event => {
                        const p = root.toContent(event.x, event.y);
                        if (!p)
                            return;
                        const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x / 40 : event.angleDelta.x / 120;
                        const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y / 40 : event.angleDelta.y / 120;
                        root.svc.scroll(p.nx, p.ny, dx, dy);
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                visible: !root.svc.connected
                onClicked: root.settingsOpen = true
            }

            CLayout {
                anchors.centerIn: parent
                spacing: Padding.small
                visible: !root.svc.connected

                Symbol {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "screen_lock_portrait"
                    iconSize: 40
                    color: Colors.colOnLayer1Inactive
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No device connected"
                    color: Colors.colOnLayer1Inactive
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Click to configure"
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colOnLayer1Inactive
                }
            }

            StyledRect {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Padding.small
                visible: root.svc.errorString.length > 0
                color: Colors.colErrorContainer
                radius: Rounding.large
                implicitHeight: errorText.implicitHeight + Padding.normal * 2

                StyledText {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    text: root.svc.errorString
                    color: Colors.colOnErrorContainer
                    font.pixelSize: Fonts.sizes.verysmall
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                z: 6
                onEntered: drag => {
                    if (drag.hasUrls) {
                        drag.accept(Qt.CopyAction);
                        root.dropActive = true;
                    }
                }
                onExited: root.dropActive = false
                onDropped: drop => {
                    root.dropActive = false;
                    if (!drop.hasUrls)
                        return;
                    for (let i = 0; i < drop.urls.length; i++) {
                        const u = drop.urls[i].toString();
                        if (u.toLowerCase().endsWith(".apk"))
                            root.svc.installApk(u);
                        else
                            root.svc.pushFile(u);
                    }
                }
            }

            StyledRect {
                anchors.fill: parent
                z: 7
                visible: root.dropActive
                color: Colors.colScrim
                radius: Rounding.verylarge

                CLayout {
                    anchors.centerIn: parent
                    spacing: Padding.small

                    Symbol {
                        Layout.alignment: Qt.AlignHCenter
                        icon: "install_mobile"
                        iconSize: 44
                        color: Colors.colOnLayer2
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Drop APK to install"
                        color: Colors.colOnLayer2
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Other files are pushed to /sdcard/"
                        font.pixelSize: Fonts.sizes.verysmall
                        color: Colors.colSubtext
                    }
                }
            }
        }

        RLayout {
            Layout.fillWidth: true
            spacing: Padding.small

            Repeater {
                model: [
                    {
                        icon: "link",
                        act: "toggle"
                    },
                    {
                        icon: "arrow_back",
                        act: "back"
                    },
                    {
                        icon: "home",
                        act: "home"
                    },
                    {
                        icon: "apps",
                        act: "recents"
                    },
                    {
                        icon: "tune",
                        act: "settings"
                    }
                ]

                delegate: RippleButtonWithIcon {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    implicitSize: 44
                    buttonRadius: Rounding.large
                    toggled: (modelData.act === "toggle" && root.svc.connected) || (modelData.act === "settings" && root.settingsOpen)
                    materialIcon: modelData.act === "toggle" && root.svc.connected ? "link_off" : modelData.icon
                    onClicked: {
                        if (modelData.act === "toggle")
                            root.svc.toggle();
                        else if (modelData.act === "back")
                            root.svc.back();
                        else if (modelData.act === "home")
                            root.svc.home();
                        else if (modelData.act === "recents")
                            root.svc.recents();
                        else
                            root.settingsOpen = true;
                    }
                }
            }
        }
    }
}
