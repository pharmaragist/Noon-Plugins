import qs.common.utils

JsonAdapter {
    property var folders: ({})
    property var devices: ({})
    property var systemInfo: ({})
    property var connections: ({})
    property var events: []
    property int currentPage: 0
    property bool connected: false
    property string connectionStatus: "Disconnected"
    property string actionFeedback: ""
}
