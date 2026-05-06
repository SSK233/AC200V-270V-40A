import QtQuick
import QtQuick.Effects

Item {
    id: root
    property string text: ""
    property int duration: 2000 // 显示时间2秒
    property bool shadowEnabled: true
    property real radius: 16
    property int padding: 12
    property real maxWidth: 420
    property color bgColor: "#E9EEF6" // 默认背景色
    property color fgColor: "#000000" // 默认前景色
    property real yOffset: 0
    width: Math.min(contentItem.implicitWidth, maxWidth) + padding * 2
    height: contentItem.implicitHeight + padding * 2
    visible: false
    opacity: 0
    z: 2000

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.radius
        color: root.bgColor
    }
    MultiEffect {
        source: background
        anchors.fill: background
        visible: root.shadowEnabled
        shadowEnabled: true
        shadowColor: "#40000000"
        shadowBlur: 1.0
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 2
    }
    Text {
        id: contentItem
        anchors.centerIn: parent
        text: root.text
        color: root.fgColor
        wrapMode: Text.WrapAnywhere
        width: Math.min(root.maxWidth, implicitWidth)
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 14
    }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    function show(msg) { 
        root.text = msg; 
        root.visible = true; 
        root.opacity = 1; 
        root.yOffset = -12; 
        enter.restart(); 
        hideTimer.interval = root.duration; 
        hideTimer.start() 
    }
    function hide() { 
        root.opacity = 0; 
        out.restart() 
    }
    PropertyAnimation { id: enter; target: root; property: "yOffset"; from: -12; to: 0; duration: 220; easing.type: Easing.OutCubic }
    PropertyAnimation { id: out; target: root; property: "yOffset"; from: 0; to: -12; duration: 200; easing.type: Easing.InCubic; onStopped: root.visible = false }
    Timer { id: hideTimer; interval: root.duration; running: false; repeat: false; onTriggered: { root.opacity = 0; out.restart() } }
}