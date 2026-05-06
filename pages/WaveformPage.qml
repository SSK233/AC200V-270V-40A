// 导入必要的QML模块
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import Qt.labs.platform as LabsPlatform
import EvolveUI

// 波形显示页面组件
Page {
    id: root

    // 动画窗口属性别名，用于外部访问
    property alias animatedWindow: animationWrapper

    // 数据记录器
    DataRecorder {
        id: dataRecorder
        interval: 3

        onExportFinished: function(success, filePath) {
            if (success) {
                exportSuccessDialog.message = "数据报表已成功导出到：\n" + filePath
                exportSuccessDialog.open()
            } else {
                exportSuccessDialog.message = "导出失败，请检查文件路径是否被占用"
                exportSuccessDialog.open()
            }
        }
    }

    // 文件保存对话框
    LabsPlatform.FileDialog {
        id: fileDialog
        title: "导出报表"
        fileMode: LabsPlatform.FileDialog.SaveFile
        defaultSuffix: "csv"
        nameFilters: ["CSV文件 (*.csv)", "所有文件 (*)"]
        onAccepted: {
            var filePath = fileDialog.file.toString()
            if (filePath.startsWith("file:///")) {
                filePath = filePath.substring(8)
            }
            if (!filePath.endsWith(".csv")) {
                filePath += ".csv"
            }
            dataRecorder.exportToExcel(filePath)
        }
    }

    // 导出成功对话框
    EAlertDialog {
        id: exportSuccessDialog
        title: "提示"
        message: ""
        confirmText: "确定"
        cancelText: ""
    }

    // 清除波形图确认对话框
    EAlertDialog {
        id: clearWaveformDialog
        title: "确认清除波形"
        message: "确定要清除波形图数据吗？"
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            waveformDataManager.clearData()
        }
    }

    // 清除报表数据确认对话框
    EAlertDialog {
        id: clearRecordDialog
        title: "确认清除报表"
        message: "确定要清除已记录的报表数据吗？"
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            dataRecorder.clearData()
        }
    }

    // 实时更新数据 - 从波形数据管理器获取最新值
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            var voltage = 0
            var current = 0
            var power = 0
            if (waveformDataManager.voltageHistory && waveformDataManager.voltageHistory.length > 0) {
                voltage = waveformDataManager.voltageHistory[waveformDataManager.voltageHistory.length - 1]
            }
            if (waveformDataManager.currentHistory && waveformDataManager.currentHistory.length > 0) {
                current = waveformDataManager.currentHistory[waveformDataManager.currentHistory.length - 1]
            }
            if (waveformDataManager.powerHistory && waveformDataManager.powerHistory.length > 0) {
                power = waveformDataManager.powerHistory[waveformDataManager.powerHistory.length - 1]
            }
            dataRecorder.addData(voltage, current, power)
        }
    }

    // 页面背景设置为透明
    background: Rectangle {
        color: "transparent"
    }

    // 滚动视图，用于容纳波形图表
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 8  // 边距设置
        clip: true  // 启用裁剪，防止内容溢出
        ScrollBar.vertical.policy: ScrollBar.AlwaysOn  // 始终显示垂直滚动条
        ScrollBar.vertical.width: 12  // 滚动条宽度

        // 可 flick 的内容区域
        Flickable {
            id: flickable
            width: scrollView.width - scrollView.ScrollBar.vertical.width
            height: contentHeight
            // 计算内容高度，确保所有图表都能显示
            contentHeight: column.children.length > 0 ? column.children[0].height + column.children[1].height + column.children[2].height + column.children[3].height + 32 : 600

            // 垂直布局容器
            Column {
                id: column
                width: parent.width
                spacing: 8  // 子项间距

                // 按钮行布局
                RowLayout {
                    width: parent.width
                    height: 60
                    spacing: 16

                    // 左侧空白占位
                    Item {
                        width: 10
                        height: 10
                    }

                    // 开始记录按钮
                    EButton {
                        id: startRecordButton
                        text: dataRecorder.recording ? "记录中..." : "开始记录"
                        iconCharacter: dataRecorder.recording ? "\uf111" : "\uf04b"
                        size: "s"
                        containerColor: dataRecorder.recording ? "#ef4444" : theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            if (!dataRecorder.recording) {
                                dataRecorder.startRecording()
                            }
                        }
                    }

                    // 停止记录按钮
                    EButton {
                        id: stopRecordButton
                        text: "停止记录"
                        iconCharacter: "\uf04d"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            dataRecorder.stopRecording()
                        }
                    }

                    // 导出报表按钮
                    EButton {
                        id: exportButton
                        text: "导出报表"
                        iconCharacter: "\uf1c3"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            fileDialog.open()
                        }
                    }

                    // 清除波形图按钮
                    EButton {
                        id: clearWaveformButton
                        text: "清除波形"
                        iconCharacter: "\uf1f8"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            clearWaveformDialog.open()
                        }
                    }

                    // 清除报表数据按钮
                    EButton {
                        id: clearRecordButton
                        text: "清除报表"
                        iconCharacter: "\uf1f8"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        iconColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            clearRecordDialog.open()
                        }
                    }

                    // 记录状态显示
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "transparent"

                        RowLayout {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: dataRecorder.recording ? "#22c55e" : "#9ca3af"
                            }

                            Text {
                                text: dataRecorder.recording ? "正在记录" : "已停止"
                                color: dataRecorder.recording ? "#22c55e" : "#9ca3af"
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: "| 已记录: " + dataRecorder.recordCount + " 条"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // 电压波形图表
                EAreaChart {
                    id: voltageChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "电压波形"
                    subtitle: "实时电压变化 (V)"
                    dataSeries: waveformDataManager.voltageChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                }

                // 电流波形图表
                EAreaChart {
                    id: currentChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "电流波形"
                    subtitle: "实时电流变化 (A)"
                    dataSeries: waveformDataManager.currentChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                }

                // 功率波形图表
                EAreaChart {
                    id: powerChart
                    x: 5
                    width: parent.width - 10
                    height: 280
                    title: "功率波形"
                    subtitle: "实时功率变化 (kW)"
                    dataSeries: waveformDataManager.powerChartData  // 数据系列
                    lineStyle: EAreaChart.LineStyle.Smooth  // 平滑线条样式
                    topPadding: 50  // 顶部内边距
                    chartPadding: 10  // 图表内边距
                    titleFontSize: 14  // 标题字体大小
                    subtitleFontSize: 10  // 副标题字体大小
                    startFromFirstValue: true  // 从第一个值开始绘制
                }
            }
        }
    }

    // 动画窗口包装器
    EAnimatedWindow {
        id: animationWrapper
    }

    // 数据更新连接
    Connections {
        target: waveformDataManager  // 目标数据源
        function onDataUpdated() {
            // 当数据更新时，刷新三个图表的数据
            voltageChart.dataSeries = waveformDataManager.voltageChartData
            currentChart.dataSeries = waveformDataManager.currentChartData
            powerChart.dataSeries = waveformDataManager.powerChartData
        }
    }
}
