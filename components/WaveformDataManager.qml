import QtQuick

Item {
    id: root

    signal dataUpdated()

    property int maxDataPoints: 60
    property int updateInterval: 1000

    property var voltageHistory: []
    property var currentHistory: []
    property var powerHistory: []
    property var timeLabels: []

    property var voltageChartData: [{ name: "电压", color: "#2196F3", data: [] }]
    property var currentChartData: [{ name: "电流", color: "#4CAF50", data: [] }]
    property var powerChartData: [{ name: "功率", color: "#FF9800", data: [] }]

    function generateChartData(history, unit) {
        var result = []
        for (var i = 0; i < history.length; i++) {
            result.push({
                month: root.timeLabels[i] || "",
                value: history[i],
                label: root.timeLabels[i] ? root.timeLabels[i] + " " + history[i].toFixed(1) + unit : ""
            })
        }
        return result
    }

    function updateChartData() {
        root.voltageChartData = [{
            name: "电压",
            color: "#2196F3",
            data: root.generateChartData(root.voltageHistory, "V")
        }]
        root.currentChartData = [{
            name: "电流",
            color: "#4CAF50",
            data: root.generateChartData(root.currentHistory, "A")
        }]
        root.powerChartData = [{
            name: "功率",
            color: "#FF9800",
            data: root.generateChartData(root.powerHistory, "kW")
        }]
    }

    function addDataPoint(voltage, current, power) {
        var now = new Date()
        var timeLabel = String(now.getHours()).padStart(2, '0') + ":" +
                        String(now.getMinutes()).padStart(2, '0') + ":" +
                        String(now.getSeconds()).padStart(2, '0')

        root.voltageHistory.push(voltage)
        root.currentHistory.push(current)
        root.powerHistory.push(power)
        root.timeLabels.push(timeLabel)

        if (root.voltageHistory.length > root.maxDataPoints) {
            root.voltageHistory.shift()
            root.currentHistory.shift()
            root.powerHistory.shift()
            root.timeLabels.shift()
        }

        root.updateChartData()
        root.dataUpdated()
    }

    function clearData() {
        root.voltageHistory = []
        root.currentHistory = []
        root.powerHistory = []
        root.timeLabels = []
        root.updateChartData()
        root.dataUpdated()
    }
}
