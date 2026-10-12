import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

WidgetContainer {
    id: root

    color: "#FFF3B0"
    rotation: -1.2
    clip: true

    property bool editing: false
    property int autoSaveInterval: 3000

    Timer {
        id: autoSaveTimer
        interval: root.autoSaveInterval
        running: NotesService.isDirty && root.editing
        repeat: false
        onTriggered: NotesService.save()
    }

    Component.onCompleted: {
        contentArea.text = NotesService.content;
    }

    Connections {
        target: NotesService
        function onContentChanged() {
            if (!root.editing && contentArea.text !== NotesService.content) {
                contentArea.text = NotesService.content;
            }
        }
    }

    StyledRect {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -3
        anchors.rightMargin: -3
        width: 32
        height: 32
        rotation: 15
        color: "#FFFFFF"
        opacity: 0.2
        radius: 2
        enableBorders: false
    }

    StyledRect {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: -2
        anchors.leftMargin: 14
        width: 26
        height: 26
        rotation: -8
        color: "#FFFFFF"
        opacity: 0.15
        radius: 2
        enableBorders: false
    }

    StyledRect {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4
        color: "#000000"
        opacity: 0.06
        radius: 0
        enableBorders: false
    }

    StyledText {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Padding.small
        text: NotesService.fileName
        color: "#3D2E00"
        opacity: 0.45
        font.pixelSize: Fonts.sizes.verysmall
        elide: Text.ElideRight
    }

    TextArea {
        id: contentArea
        anchors.fill: parent
        anchors.topMargin: Padding.huge + Padding.verylarge
        anchors.margins: Padding.large
        color: "#3D2E00"
        font.family: Fonts.family.main
        font.pixelSize: Fonts.sizes.normal
        selectionColor: Colors.m3.m3tertiary
        selectedTextColor: Colors.m3.m3onTertiary
        background: null

        selectByMouse: root.editing
        wrapMode: TextArea.Wrap
        readOnly: !root.editing
        focus: true
        textFormat: root.editing ? TextEdit.PlainText : TextEdit.MarkdownText
        placeholderText: root.editing ? "Start typing..." : "Press Ctrl+E to edit"
        placeholderTextColor: "#3D2E00"
        opacity: root.editing ? 1.0 : 0.9

        onTextChanged: {
            if (root.editing && text !== NotesService.content) {
                NotesService.content = text;
                NotesService.isDirty = true;
                autoSaveTimer.restart();
            }
        }

        onLinkActivated: link => Qt.openUrlExternally(link)

        Keys.onPressed: event => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_E) {
                    root.editing = !root.editing;
                    event.accepted = true;
                } else if (event.key === Qt.Key_S) {
                    NotesService.save();
                    event.accepted = true;
                }
            }
        }
    }

    MouseArea {
        anchors.fill: contentArea
        acceptedButtons: Qt.RightButton
        onPressed: mouse => mouse.accepted = true
        onReleased: mouse => mouse.accepted = true
        onClicked: mouse => mouse.accepted = true
    }

    StyledText {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Padding.small
        text: root.editing ? "Editing..." : ""
        color: "#3D2E00"
        opacity: 0.35
        font.pixelSize: Fonts.sizes.verysmall
    }

    StyledText {
        anchors.centerIn: parent
        visible: !NotesService.isLoaded || contentArea.text === ""
        text: "Open a note in sidebar"
        color: "#3D2E00"
        opacity: 0.3
        font.pixelSize: Fonts.sizes.large
    }
}
