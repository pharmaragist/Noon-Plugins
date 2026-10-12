import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.common.widgets
import "../"

Item {
    id: root
    property string searchFilter: ""
    property string selectedSubject: ""
    readonly property var currentQuestions: root.getFiltered()

    property bool immersiveMode: false
    property int immersiveIndex: 0

    onSelectedSubjectChanged: {
        LMSService.data.questionsSelectedSubject = root.selectedSubject;
        root.ensureAnswers(root.selectedSubject);
    }

    function getSubjects() {
        return Object.keys(LMSService?.questions) ?? [];
    }

    function hasAnswers(subject) {
        var qs = LMSService?.questions[subject];
        if (!qs || qs.length === 0)
            return false;
        return qs[0].options !== undefined;
    }

    function ensureAnswers(subject) {
        if (!subject || hasAnswers(subject))
            return;
        LMSService.fetchAnswers(subject);
    }

    function getFiltered() {
        var subj = LMSService?.questions[selectedSubject];
        if (!subj)
            return [];
        var q = searchFilter.toLowerCase().trim();
        if (!q)
            return subj;
        var res = [];
        for (var i = 0; i < subj.length; i++) {
            var text = (subj[i].question_text || subj[i].question_name || "").toLowerCase();
            var topic = (subj[i].topic || "").toLowerCase();
            if (text.indexOf(q) !== -1 || topic.indexOf(q) !== -1)
                res.push(subj[i]);
        }
        return res;
    }

    function enterImmersive(idx) {
        immersiveIndex = idx;
        immersiveMode = true;
    }

    function exitImmersive() {
        immersiveMode = false;
    }

    CLayout {
        anchors.fill: parent
        anchors.margins: Padding.small
        spacing: 0

        PageHeader {
            title: "Question Bank"

            subTitle: {
                var total = LMSService.totalItems(LMSService.questions);
                var shown = currentQuestions.length;
                var ans = root.hasAnswers(root.selectedSubject) ? "answers loaded" : "no answers";
                return total + " questions total" + (shown < total ? "  ·  showing " + shown : "") + "  ·  " + ans;
            }
        }

        RLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Padding.large
            Layout.rightMargin: Padding.large
            Layout.bottomMargin: Padding.small
            spacing: Padding.small

            StyledRect {
                enableBorders: true
                color: Colors.colLayer1
                radius: Rounding.normal
                height: 38
                Layout.fillWidth: true

                RLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.small
                    spacing: Padding.small
                    Symbol {
                        text: "search"
                        color: Colors.colSubtext
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignVCenter
                    }
                    TextInput {
                        id: searchInput
                        color: Colors.colOnSurface
                        font.pixelSize: Fonts.sizes.small
                        clip: true
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        selectByMouse: true
                        onTextChanged: root.searchFilter = text
                        Component.onCompleted: root.searchFilter = ""
                    }
                    Symbol {
                        text: "close"
                        visible: root.searchFilter.length > 0
                        color: Colors.colSubtext
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.searchFilter = "";
                                searchInput.text = "";
                            }
                        }
                    }
                }
            }
            StyledComboBox {
                id: subjectComboBox
                Layout.preferredWidth: 120
                model: root.getSubjects()
                currentIndex: model.indexOf(LMSService.data.questionsSelectedSubject)
                onCurrentIndexChanged: root.selectedSubject = subjectComboBox.model[subjectComboBox.currentIndex]
            }
        }

        StyledListView {
            clip: true
            radius: Rounding.verylarge
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Padding.small
            Layout.leftMargin: Padding.large
            Layout.rightMargin: Padding.large
            model: ScriptModel {
                values: root.currentQuestions
            }
            delegate: QuestionCard {
                required property var modelData
                required property int index
                anchors.right: parent?.right
                anchors.left: parent?.left
                qData: modelData
            }
        }
    }

    StyledRect {
        id: immOverlay
        anchors.fill: parent
        visible: root.immersiveMode
        color: Colors.m3.m3surface
        radius: Rounding.verylarge
        clip: true
        focus: true

        readonly property var qData: root.currentQuestions[root.immersiveIndex]
        property bool immAnswered: false
        property int immSelectedIndex: -1
        property bool immWasCorrect: false

        Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_Escape:
                root.exitImmersive();
                event.accepted = true;
                break;
            case Qt.Key_Left:
                if (root.immersiveIndex > 0) {
                    root.immersiveIndex--;
                    optionsList.forceActiveFocus();
                }
                event.accepted = true;
                break;
            case Qt.Key_Right:
                if (root.immersiveIndex < root.currentQuestions.length - 1) {
                    root.immersiveIndex++;
                    optionsList.forceActiveFocus();
                }
                event.accepted = true;
                break;
            }
        }

        CLayout {
            anchors.fill: parent
            anchors.margins: Padding.verylarge
            spacing: Padding.normal

            RLayout {
                Layout.maximumHeight: 45
                Layout.fillWidth: true
                spacing: Padding.small

                GroupButtonWithIcon {
                    Layout.fillWidth: false
                    Layout.fillHeight: false
                    materialIcon: "arrow_back"
                    implicitSize: 38
                    onClicked: root.exitImmersive()
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledRect {
                    enableBorders: true
                    color: Colors.m3.m3surface
                    radius: Rounding.small
                    implicitHeight: 28
                    implicitWidth: 52
                    Layout.alignment: Qt.AlignVCenter

                    TextInput {
                        id: qNumInput
                        anchors.fill: parent
                        anchors.leftMargin: Padding.small
                        anchors.rightMargin: Padding.small
                        color: Colors.colOnSurface
                        font.pixelSize: Fonts.sizes.small
                        font.weight: 600
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator {
                            bottom: 1
                            top: root.currentQuestions.length
                        }
                        text: root.immersiveIndex + 1
                        selectByMouse: true
                        onAccepted: {
                            var num = parseInt(text);
                            if (!isNaN(num) && num >= 1 && num <= root.currentQuestions.length)
                                root.immersiveIndex = num - 1;
                        }
                    }
                }

                StyledText {
                    text: "/" + root.currentQuestions.length
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 600
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            RLayout {
                Layout.maximumHeight: 45
                Layout.fillWidth: true
                Layout.topMargin: Padding.normal
                spacing: Padding.huge

                StyledRect {
                    color: {
                        var t = (immOverlay.qData.question_type || "").toLowerCase();
                        if (t.indexOf("mcq") >= 0 || t.indexOf("choice") >= 0)
                            return Colors.colPrimary;
                        if (t.indexOf("true") >= 0 || t.indexOf("false") >= 0)
                            return Colors.colSecondary;
                        return Colors.colSecondary;
                    }
                    radius: Rounding.small
                    implicitHeight: 26
                    implicitWidth: immTypeText.contentWidth + Padding.normal * 2
                    StyledText {
                        id: immTypeText
                        anchors.centerIn: parent
                        text: immOverlay.qData.question_type || "?"
                        color: Colors.colOnPrimary
                        font.pixelSize: Fonts.sizes.verysmall
                        font.weight: 600
                    }
                }

                StyledRect {
                    visible: immOverlay.qData.topic && immOverlay.qData.topic.length > 0
                    enableBorders: true
                    color: Colors.m3.m3surface
                    radius: Rounding.small
                    implicitHeight: 26
                    implicitWidth: immTopicText.contentWidth + Padding.normal * 2
                    StyledText {
                        id: immTopicText
                        anchors.centerIn: parent
                        text: immOverlay.qData.topic || ""
                        color: Colors.colSubtext
                        font.pixelSize: Fonts.sizes.verysmall
                        font.weight: 500
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: (immOverlay.qData.default_mark || 1) + "m"
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 600
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            CLayout {
                id: immCol
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Padding.normal

                StyledText {
                    text: {
                        var txt = immOverlay.qData.question_text || immOverlay.qData.question_name || "";
                        txt = txt.replace(/<[^>]*>/g, "");
                        return txt;
                    }
                    color: Colors.colOnSurface
                    font.pixelSize: Fonts.sizes.large
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    lineHeight: 1.5
                    font.weight: 600
                }

                StyledText {
                    visible: immOverlay.qData && immOverlay.qData.options ? immOverlay.qData.options.length > 0 : false
                    text: (immOverlay.qData && immOverlay.qData.options ? immOverlay.qData.options.length : 0) + " option" + (immOverlay.qData && immOverlay.qData.options && immOverlay.qData.options.length !== 1 ? "s" : "")
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 500
                    Layout.topMargin: Padding.small
                    Layout.bottomMargin: Padding.small
                }

                StyledRect {
                    visible: !immOverlay.qData?.options || immOverlay.qData.options.length === 0
                    color: Colors.colLayer2
                    radius: Rounding.normal
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    CLayout {
                        anchors.centerIn: parent
                        spacing: Padding.normal
                        Symbol {
                            text: "edit_note"
                            color: Colors.colSubtext
                            font.pixelSize: 32
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: {
                                var t = (immOverlay.qData?.question_type || "").toLowerCase();
                                if (t.indexOf("short") >= 0)
                                    return "Short answer question — you answer this";
                                return "Essay question — you answer this";
                            }
                            color: Colors.colSubtext
                            font.pixelSize: Fonts.sizes.normal
                            font.weight: 500
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                StyledListView {
                    id: optionsList
                    visible: immOverlay.qData?.options?.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Padding.tiny
                    clip: true
                    focus: true
                    highlightMoveDuration: 0
                    model: ScriptModel {
                        values: immOverlay.qData?.options || []
                    }
                    delegate: OptionButton {
                        required property var modelData
                        required property int index
                        topRadius: index === 0 ? Rounding.normal : Rounding.tiny
                        bottomRadius: index === (immOverlay.qData?.options?.length ?? 0) - 1 ? Rounding.normal : Rounding.tiny
                        width: parent?.width ?? 0
                        optIndex: index
                        optText: modelData.text || ""
                        optCorrect: modelData.correct || false
                        qAnswered: immOverlay.immAnswered
                        qSelectedIndex: immOverlay.immSelectedIndex
                        qWasCorrect: immOverlay.immWasCorrect
                        optHighlighted: optionsList.currentIndex === index
                        onOptionClicked: function (idx, correct) {
                            if (immOverlay.immAnswered)
                                return;
                            immOverlay.immAnswered = true;
                            immOverlay.immSelectedIndex = idx;
                            immOverlay.immWasCorrect = correct;
                        }
                    }

                    Keys.onUpPressed: {
                        if (currentIndex > 0)
                            currentIndex--;
                        else
                            currentIndex = count - 1;
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1)
                            currentIndex++;
                        else
                            currentIndex = 0;
                    }
                    Keys.onReturnPressed: {
                        var del = currentItem;
                        if (del && del.optIndex >= 0 && !immOverlay.immAnswered) {
                            immOverlay.immAnswered = true;
                            immOverlay.immSelectedIndex = del.optIndex;
                            immOverlay.immWasCorrect = del.optCorrect;
                        }
                    }
                }

                StyledText {
                    visible: immOverlay.immAnswered
                    text: immOverlay.immWasCorrect ? "✓ Correct!" : "✗ Incorrect"
                    color: immOverlay.immWasCorrect ? Colors.colSecondary : Colors.colError
                    font.pixelSize: Fonts.sizes.normal
                    font.weight: 700
                    Layout.topMargin: Padding.small
                }
            }

            ButtonGroup {
                Layout.fillWidth: true
                Layout.maximumHeight: 45

                GroupButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    materialIcon: "chevron_left"
                    enabled: root.immersiveIndex > 0
                    onClicked: {
                        root.immersiveIndex--;
                        optionsList.forceActiveFocus();
                    }
                }

                GroupButtonWithIcon {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    materialIcon: "chevron_right"
                    enabled: root.immersiveIndex < root.currentQuestions.length - 1
                    onClicked: {
                        root.immersiveIndex++;
                        optionsList.forceActiveFocus();
                    }
                }
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: optionsList.forceActiveFocus()
    }

    Connections {
        target: immOverlay
        function onVisibleChanged() {
            if (immOverlay.visible) {
                qNumInput.text = root.immersiveIndex + 1;
                var a = root.getImmersiveAnswer(root.immersiveIndex);
                if (a.answered && a.selectedIndex >= 0 && a.selectedIndex < optionsList.count)
                    optionsList.currentIndex = a.selectedIndex;
                focusTimer.restart();
            }
        }
    }

    Connections {
        target: root
        function onImmersiveIndexChanged() {
            qNumInput.text = root.immersiveIndex + 1;
            immOverlay.immAnswered = false;
            optionsList.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        var subs = getSubjects();
        if (subs.length > 0) {
            var savedSubject = LMSService.data.questionsSelectedSubject;
            if (savedSubject && subs.indexOf(savedSubject) >= 0)
                root.selectedSubject = savedSubject;
            else
                root.selectedSubject = subs[0];
            root.ensureAnswers(root.selectedSubject);
        }
    }

    component QuestionCard: StyledRect {
        id: cardRoot
        property var qData
        property bool answered: false
        property int selectedIndex: -1
        property bool wasCorrect: false
        readonly property bool isMcq: (qData.question_type || "").toLowerCase().indexOf("mcq") >= 0
        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: col.implicitHeight + Padding.veryhuge * 2

        CLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: 4

            RLayout {
                Layout.fillWidth: true
                spacing: Padding.huge

                StyledRect {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    color: {
                        var t = (qData.question_type || "").toLowerCase();
                        if (t.indexOf("mcq") >= 0 || t.indexOf("choice") >= 0)
                            return Colors.colPrimary;
                        if (t.indexOf("true") >= 0 || t.indexOf("false") >= 0)
                            return Colors.colSecondary;
                        return Colors.colSecondary;
                    }
                    radius: Rounding.small
                    implicitHeight: 24
                    implicitWidth: typeText.contentWidth + Padding.normal * 2
                    StyledText {
                        id: typeText
                        anchors.centerIn: parent
                        text: qData.question_type || "?"
                        color: isMcq ? Colors.colOnPrimary : Colors.colOnSecondary
                        font.pixelSize: Fonts.sizes.verysmall
                        font.weight: 600
                    }
                }

                StyledRect {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    visible: qData.topic && qData.topic.length > 0
                    enableBorders: true
                    color: Colors.colLayer1
                    radius: Rounding.small
                    implicitHeight: 24
                    implicitWidth: topicText.contentWidth + Padding.normal * 2
                    StyledText {
                        id: topicText
                        anchors.centerIn: parent
                        text: qData.topic || ""
                        color: Colors.colSubtext
                        font.pixelSize: Fonts.sizes.verysmall
                        font.weight: 500
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Symbol {
                    text: "open_in_full"
                    color: Colors.colSubtext
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.enterImmersive(index)
                    }
                }

                StyledText {
                    text: (qData.default_mark || 1) + "m"
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 600
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            StyledText {
                text: {
                    var txt = qData.question_text || qData.question_name || "";
                    txt = txt.replace(/<[^>]*>/g, "");
                    return txt;
                }
                color: Colors.colOnSurface
                font.pixelSize: Fonts.sizes.small
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
                lineHeight: 1.4
                font.weight: 500
            }

            StyledText {
                visible: qData && qData.options ? qData.options.length > 0 : false
                text: (qData && qData.options ? qData.options.length : 0) + " option" + (qData && qData.options && qData.options.length !== 1 ? "s" : "")
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                font.weight: 500
                Layout.bottomMargin: Padding.small
            }

            Repeater {
                model: cardRoot?.qData?.options || []
                delegate: OptionButton {
                    topRadius: optIndex === 0 ? Rounding.normal : Rounding.tiny
                    bottomRadius: optIndex === cardRoot?.qData?.options.length - 1 ? Rounding.normal : Rounding.tiny

                    Layout.fillWidth: true
                    optIndex: index
                    optText: modelData.text || ""
                    optCorrect: modelData.correct || false
                    qAnswered: cardRoot.answered
                    qSelectedIndex: cardRoot.selectedIndex
                    qWasCorrect: cardRoot.wasCorrect
                    onOptionClicked: function (idx, correct) {
                        if (cardRoot.answered)
                            return;
                        cardRoot.selectedIndex = idx;
                        cardRoot.wasCorrect = correct;
                        cardRoot.answered = true;
                    }
                }
            }

            StyledText {
                visible: cardRoot.answered
                text: cardRoot.wasCorrect ? "✓ Correct!" : "✗ Incorrect"
                color: cardRoot.wasCorrect ? Colors.colSecondary : Colors.colError
                font.pixelSize: Fonts.sizes.small
                font.weight: 700
                Layout.topMargin: Padding.small
            }
        }
    }

    component OptionButton: StyledRect {
        property int optIndex
        property string optText
        property bool optCorrect
        property bool qAnswered
        property int qSelectedIndex
        property bool qWasCorrect
        property bool optHighlighted: false
        signal optionClicked(int idx, bool correct)
        implicitHeight: Math.max(contentText?.contentHeight + Padding.veryhuge, 40)
        color: {
            if (qAnswered && optIndex === qSelectedIndex) {
                if (!qWasCorrect)
                    return Colors.colError;
                return Colors.colPrimary;
            } else
                return Colors.colLayer3;
        }

        RLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.normal
            anchors.rightMargin: Padding.normal
            spacing: Padding.small
            StyledRect {
                implicitWidth: 4
                implicitHeight: 28
                radius: 2
                color: {
                    if (qAnswered && optIndex === qSelectedIndex) {
                        if (!qWasCorrect)
                            return Colors.m3.m3onError;
                        return Colors.colOnPrimary;
                    }
                    if (optHighlighted)
                        return Colors.colPrimary;
                    return "transparent";
                }
                Layout.alignment: Qt.AlignVCenter
            }

            Symbol {
                text: {
                    if (!qAnswered)
                        return "radio_button_unchecked";
                    if (optCorrect)
                        return "check_circle";
                    if (optIndex === qSelectedIndex && !qWasCorrect)
                        return "cancel";
                    return "radio_button_unchecked";
                }
                color: {
                    if (!qAnswered)
                        return Colors.colSubtext;
                    if (optCorrect)
                        return Colors.colOnPrimary;
                    if (optIndex === qSelectedIndex && !qWasCorrect)
                        return Colors.m3.m3onError;
                    return Colors.colSubtext;
                }
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                id: contentText
                text: optText
                color: {
                    if (!qAnswered)
                        return Colors.colOnSurface;
                    if (optCorrect)
                        return Colors.colOnPrimary;
                    if (optIndex === qSelectedIndex && !qWasCorrect)
                        return Colors.m3.m3onError;
                    return Colors.colOnSurface;
                }
                font.pixelSize: Fonts.sizes.normal
                font.weight: 500
                elide: Text.ElideRight
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter
            }
        }

        opacity: qAnswered && optIndex !== qSelectedIndex && !optCorrect ? 0.5 : 1.0

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !qAnswered
            onClicked: optionClicked(optIndex, optCorrect)
        }
    }
}
