import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    property var homePage
    padding: 20
    background: Rectangle {
        color: "transparent"
    }

    ColumnLayout {
        spacing: 20
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20

        Label {
            text: "设置页面"
            font.pixelSize: 24
            color: theme.textColor
            font.bold: true
        }

        EButton {
            text: theme.isDark ? "浅色" : "深色"
            iconCharacter: theme.isDark ? "\uf185" : "\uf186"
            iconRotateOnClick: true
            onClicked: theme.toggleTheme()
        }

        EButton {
            id: debugModeButton
            text: homePage ? (homePage.debugMode ? "退出调试" : "调试模式") : "调试模式"
            size: "s"
            containerColor: homePage && homePage.debugMode ? (theme.isDark ? "#FF5722" : "#E64A19") : theme.secondaryColor
            textColor: theme.textColor
            shadowEnabled: true
            onClicked: {
                if (homePage) {
                    var newDebugMode = !homePage.debugMode
                    homePage.debugMode = newDebugMode
                    console.log("调试模式:", newDebugMode ? "开启" : "关闭")
                    
                    if (!newDebugMode && homePage.fanSwitch2 && homePage.fanSwitch2.checked) {
                        if (!homePage.fanSwitchOn || (homePage.modbusManager && homePage.modbusManager.fanState !== 1)) {
                            homePage.fanSwitch2.checked = false
                            console.log("退出调试模式，风机1未运行，自动关闭风机2")
                        }
                    }
                }
            }
        }
    }

}
