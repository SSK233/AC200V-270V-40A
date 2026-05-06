// EInput.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls.Basic as Basic

Item {
    id: root
    width: 240
    height: 40

    // === 接口属性 & 信号 ===
    property alias text: textField.text
    property string placeholderText: ""
    property bool readOnly: false
    property bool passwordField: false
    property bool passwordVisible: false
    signal accepted()  // 输入回车触发

    // === 样式属性 ===
    property int fontSize: 16
    property real radius: 10
    property string showPasswordSymbol: "👁"
    property string hidePasswordSymbol: "🙈"

    // === 状态属性 ===
    property bool enabled: true
    property bool backgroundVisible: true  // 背景显示控制
    property bool validationError: false  // 验证错误状态

    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        propagateComposedEvents: true
        z: 999
        onPressed: (mouse)=> {
            var pos = mapToItem(root, mouse.x, mouse.y)
            if (!root.contains(pos)) {
                textField.focus = false
            }
            mouse.accepted = false
        }
        preventStealing: true
    }

    property Window windowRef: null

    Component.onCompleted: {
        windowRef = Window.window
        if (windowRef) {
            outsideClickArea.anchors.fill = undefined
            outsideClickArea.parent = windowRef.contentItem
            outsideClickArea.width = windowRef.width
            outsideClickArea.height = windowRef.height
            outsideClickArea.visible = textField.activeFocus
        }
    }

    Connections {
        target: textField
        function onActiveFocusChanged() {
            if (outsideClickArea.parent) {
                outsideClickArea.visible = textField.activeFocus
            }
        }
    }

    Timer {
        id: windowBindTimer
        interval: 100
        repeat: false
        running: !windowRef
        onTriggered: {
            if (Window.window && !windowRef) {
                windowRef = Window.window
                if (windowRef) {
                    outsideClickArea.anchors.fill = undefined
                    outsideClickArea.parent = windowRef.contentItem
                    outsideClickArea.width = windowRef.width
                    outsideClickArea.height = windowRef.height
                    outsideClickArea.visible = textField.activeFocus
                }
            }
        }
    }

    Connections {
        target: windowRef
        function onWidthChanged() {
            if (windowRef && outsideClickArea.parent) {
                outsideClickArea.width = windowRef.width
            }
        }
        function onHeightChanged() {
            if (windowRef && outsideClickArea.parent) {
                outsideClickArea.height = windowRef.height
            }
        }
    }

    // === 背景与阴影 ===
    MultiEffect {
        source: background
        anchors.fill: background
        shadowEnabled: true
        shadowColor: theme.shadowColor
        shadowBlur: theme.shadowBlur
        shadowHorizontalOffset: theme.shadowXOffset
        shadowVerticalOffset: theme.shadowYOffset
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        // 无背景时：选中用主题高亮色，未选中用次级色；有背景时沿用主题边框色
        border.color: root.validationError 
                       ? "#F44336" // 错误时显示红色边框
                       : (root.backgroundVisible 
                          ? theme.getBorderColor(textField.activeFocus)
                          : (textField.activeFocus ? theme.focusColor : theme.textColor))
        border.width: textField.activeFocus ? 2 : 1
        Behavior on border.width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        color: root.backgroundVisible ? theme.secondaryColor : "transparent"
        opacity: root.enabled ? 1.0 : 0.6
    }

    // === 内容布局 ===
    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // === 输入框主体 ===
        Basic.TextField {
            id: textField
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            z: 2

            font.pixelSize: root.fontSize
            color: theme.textColor
            readOnly: root.readOnly
            enabled: root.enabled
            verticalAlignment: Text.AlignVCenter
            echoMode: root.passwordField
                      ? (root.passwordVisible ? TextInput.Normal : TextInput.Password)
                      : TextInput.Normal
            background: null
            onAccepted: {
                root.accepted()
                textField.focus = false
            }
            onActiveFocusChanged: {
                if (!activeFocus) {
                    root.accepted()
                }
            }
        }

        // === 占位符文本 ===
        Text {
            id: placeholderTextLabel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            text: root.placeholderText
            color: Qt.rgba(theme.textColor.r, theme.textColor.g, theme.textColor.b, 0.5)
            font.pixelSize: root.fontSize
            verticalAlignment: Text.AlignVCenter
            visible: !textField.activeFocus && textField.text === ""
            z: 1
        }

        // === 密码显示切换按钮 ===
        Text {
            id: eyeToggle
            visible: root.passwordField
            text: root.passwordVisible ? root.hidePasswordSymbol : root.showPasswordSymbol
            color: "#666"
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                enabled: root.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.passwordVisible = !root.passwordVisible
            }
        }
    }
}
