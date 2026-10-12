import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "../"

Item {
    id: root
    property bool expanded: false

    CLayout {
        anchors.fill: parent
        anchors.margins: Padding.small
        spacing: 0

        PageHeader {
            title: "Study Materials"

            subTitle: {
                var subs = LMSService.totalSubjects(LMSService.materials);
                var files = LMSService.totalItems(LMSService.materials);
                return subs + " subjects  ·  " + files + " files";
            }
        }

        StyledListView {
            clip: true
            radius: Rounding.verylarge
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Padding.normal
            Layout.topMargin: Padding.small
            model: ScriptModel {
                values: Object.keys(LMSService?.materials) ?? []
            }
            delegate: SubjectCard {
                required property string modelData
                anchors.right: parent?.right
                anchors.left: parent?.left
                subjectName: modelData
                fileCount: LMSService.materials[modelData] ? LMSService.materials[modelData].length : 0
                files: LMSService.materials[modelData] || []
            }
        }
    }

    component SubjectCard: StyledRect {
        id: root
        property string subjectName
        property bool expanded: false
        property int fileCount
        property var files: []

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: header.implicitHeight + cardContent.implicitHeight + Padding.massive * 2
        clip: true

        RLayout {
            id: header
            height: 50
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Padding.huge
            spacing: Padding.huge

            CLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                StyledText {
                    text: root.subjectName
                    color: Colors.colOnSurface
                    font.pixelSize: Fonts.sizes.large
                    font.weight: 600
                    truncate: true
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    text: root.fileCount + " file" + (root.fileCount !== 1 ? "s" : "")
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 500
                }
            }

            Symbol {
                text: root.expanded ? "expand_less" : "expand_more"
                color: Colors.colSubtext
                font.pixelSize: 22
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            }
        }

        CLayout {
            id: cardContent
            visible: root.expanded
            anchors.bottom: parent.bottom
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Padding.huge
            spacing: Padding.large
            z: 9999
            Revealer {
                reveal: root.expanded
                vertical: true
                implicitWidth: parent.width
                Layout.fillWidth: true

                CLayout {
                    width: parent.width
                    spacing: Padding.tiny
                    Layout.topMargin: Padding.small

                    Repeater {
                        model: root.files
                        delegate: StyledRect {
                            required property var modelData
                            required property int index
                            topRadius: index === 0 ? Rounding.large : Rounding.tiny
                            bottomRadius: index === root.files.length - 1 ? Rounding.large : Rounding.tiny

                            Layout.fillWidth: true
                            implicitHeight: 48
                            color: Colors.colLayer2
                            MouseArea {
                                z: 9999
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LMSService.downloadFile(modelData.download_url)
                            }

                            RLayout {
                                anchors.fill: parent
                                anchors.margins: Padding.large
                                spacing: Padding.normal

                                Symbol {
                                    text: {
                                        var n = (modelData.file_name || "").toLowerCase();
                                        if (n.indexOf(".pdf") >= 0)
                                            return "picture_as_pdf";
                                        if (n.indexOf(".mp4") >= 0 || n.indexOf(".mkv") >= 0)
                                            return "videocam";
                                        if (n.indexOf(".mp3") >= 0 || n.indexOf(".wav") >= 0)
                                            return "audio_file";
                                        if (n.indexOf(".zip") >= 0 || n.indexOf(".rar") >= 0)
                                            return "folder_zip";
                                        if (n.indexOf(".doc") >= 0 || n.indexOf(".ppt") >= 0 || n.indexOf(".xls") >= 0)
                                            return "description";
                                        if (n.indexOf(".png") >= 0 || n.indexOf(".jpg") >= 0)
                                            return "image";
                                        return "insert_drive_file";
                                    }
                                    color: Colors.colPrimary
                                    font.pixelSize: 20
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                StyledText {
                                    text: modelData?.file_name || "Unnamed"
                                    color: Colors.colOnSurface
                                    font.pixelSize: Fonts.sizes.normal
                                    font.weight: 500
                                    truncate: true
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Symbol {
                                    text: "download"
                                    color: Colors.colSubtext
                                    font.pixelSize: 18
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            z: 0
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }
}
