import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import EvolveUI

Item {
    id: root
    property var modbusManager
    property int interval: 3
    property bool isRecording: dataRecorder.recording

    DataRecorder {
        id: dataRecorder
        interval: root.interval
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            EButton {
                id: recordButton
                text: dataRecorder.recording ? "停止记录" : "开始记录"
                icon.source: dataRecorder.recording ? "qrc:/EvolveUI/icons/stop.png" : "qrc:/EvolveUI/icons/record.png"
                onClicked: {
                    if (dataRecorder.recording) {
                        dataRecorder.stopRecording()
                    } else {
                        dataRecorder.startRecording()
                    }
                }
            }

            EButton {
                text: "导出报表"
                icon.source: "qrc:/EvolveUI/icons/excel.png"
                onClicked: {
                    dataRecorder.exportToExcel("")
                }
            }

            EButton {
                text: "清除数据"
                icon.source: "qrc:/EvolveUI/icons/clear.png"
                onClicked: {
                    dataRecorder.clearData()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: 8
            color: ETheme.colors.surface
            border.color: ETheme.colors.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "记录状态:"
                        color: ETheme.colors.onSurface
                        font.pointSize: 12
                    }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: dataRecorder.recording ? "#22c55e" : "#9ca3af"
                    }

                    Text {
                        text: dataRecorder.recording ? "正在记录" : "已停止"
                        color: dataRecorder.recording ? "#22c55e" : "#9ca3af"
                        font.pointSize: 12
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "已记录: " + dataRecorder.recordCount() + " 条"
                        color: ETheme.colors.onSurface
                        font.pointSize: 12
                    }
                }

                Text {
                    id: lastRecordText
                    text: "最新记录: 无"
                    color: ETheme.colors.onSurfaceVariant
                    font.pointSize: 11
                }
            }
        }
    }

    Connections {
        target: dataRecorder
        function onDataAdded(timestamp, voltage, current, power) {
            lastRecordText.text = "最新记录: " + timestamp + " | 电压: " + voltage.toFixed(2) + " V | 电流: " + current.toFixed(2) + " A | 功率: " + power.toFixed(3) + " kW"
        }
        function onExportFinished(success, filePath) {
            if (success) {
                console.log("报表已导出到: " + filePath)
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.modbusManager) {
                dataRecorder.addData(
                    root.modbusManager.voltage,
                    root.modbusManager.current,
                    root.modbusManager.power
                )
            }
        }
    }
}
