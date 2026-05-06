import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import EvolveUI

// ============================================================================//
// 主页组件 (HomePage.qml)
// 功能：设备控制面板，包含串口通信、风机控制、电流设置等核心功能
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

// 主要功能模块：
// - 串口通信管理（端口选择、开关控制）
// - 风机控制
// - 电气参数显示（电压、电流、功率）
// - 电流值设置
Page {
    id: window

    // ========================================================================//
    // 属性定义
    // ========================================================================//

    // 动画窗口别名，用于页面切换动画
    // 类型：alias
    // 用途：提供动画窗口的外部访问接口
    property alias animatedWindow: animationWrapper

    // 当前选中的串口索引，-1表示未选中
    // 类型：int
    // 用途：跟踪用户选择的串口端口
    property int selectedSerialPortIndex: -1
    
    // 串口开关状态
    // 类型：bool
    // 用途：暴露串口开关的状态，供其他页面访问
    property bool serialPortOpen: false
    
    // 风机开关状态
    // 类型：bool
    // 用途：暴露风机开关的状态，供其他页面访问
    property bool fanSwitchOn: fanSwitch1 ? fanSwitch1.checked : false
    
    // 操作条件是否满足
    // 类型：bool
    // 用途：判断所有操作条件是否满足，用于控制按钮和内容的可见性
    // 调试模式下，操作条件始终满足
    property bool operationConditionsMet: debugMode || (serialPortOpen && fanSwitchOn && modbusManager.hasFanStateData && modbusManager.fanState === 1 && !emergencyStopped)
    
    // 当前操作状态信息
    // 类型：string
    // 用途：根据当前条件显示相应的提示信息
    property string operationStatusMessage: {
        if (!serialPortOpen) {
            return "请打开串口 →"
        } else if (emergencyStopped) {
            return "请关闭并重新开启风机开关 →"
        } else if (!modbusManager.hasFanStateData) {
            return "等待串口连接中..."
        } else if (!fanSwitchOn) {
            return "请打开风机开关 →"
        } else if (modbusManager.fanState !== 1) {
            return "风机未运行，请检查风机状态"
        }
        return ""
    }
    
    // 引用分步运行页面对象，用于访问分步运行页面的属性和方法
    // 类型：var
    // 用途：获取分步运行页面的状态和控制分步运行
    property var stepRunPage

    // 分步运行模式状态
    // 类型：bool
    // 用途：标识是否处于分步运行模式，与手动电流设置互斥
    property bool stepRunActive: false
    
    // 急停状态
    // 类型：bool
    // 用途：标识是否处于急停状态
    property bool emergencyStopped: false
    
    // 三相电参数显示状态
    property bool showThreePhaseParams: false
    
    // 三相电参数数据
    property double threePhaseVoltageA: 0
    property double threePhaseVoltageB: 0
    property double threePhaseVoltageC: 0
    property double threePhaseCurrentA: 0
    property double threePhaseCurrentB: 0
    property double threePhaseCurrentC: 0
    property double threePhaseFrequency: 0
    
    // 调试模式状态
    // 类型：bool
    // 用途：标识是否处于调试模式，调试模式下可以单独控制风机2
    property bool debugMode: false
    
    // 风机状态日志上次输出时间
    // 类型：int
    // 用途：控制风机状态日志输出频率，每10秒输出一次
    property int lastFanStateLogTime: 0
    
    // 运行时间相关属性
    // 类型：int
    // 用途：存储累计运行时间（秒）
    property int totalRunTime: 0
    
    // 类型：int
    // 用途：存储本次运行时间（秒）
    property int currentRunTime: 0
    
    // 类型：Timer
    // 用途：用于计算运行时间
    Timer {
        id: runTimeTimer
        interval: 1000 // 1秒
        repeat: true
        onTriggered: {
            totalRunTime++
            currentRunTime++
        }
    }
    
    // ========================================================================//
    // 通信管理器
    // ========================================================================//

    // 串口管理器
    // 功能：负责串口通信的底层操作，包括端口刷新、打开、关闭等
    SerialPortManager {
        id: serialPortManager

        // 可用串口列表变化时更新下拉框数据
        onAvailablePortsChanged: {
            updateSerialPortModel()
        }

        // 串口错误处理回调
        onErrorOccurred: function(error) {
            console.log("串口错误:", error)
        }
    }



    // 数据更新状态标记
    // 类型：bool
    // 用途：标记是否有数据更新待处理（已废弃，保留仅供参考）
    property bool dataUpdatePending: false

    // 与波形数据管理器相关的Timer组件（已注释）
    // Timer {
    //     id: dataUpdateTimer
    //     interval: 100
    //     repeat: false
    //     onTriggered: {
    //         if (modbusManager.voltage > 0 || modbusManager.current > 0 || modbusManager.power > 0) {
    //             waveformDataManager.addDataPoint(modbusManager.voltage, modbusManager.current, modbusManager.power)
    //         }
    //         window.dataUpdatePending = false
    //     }
    // }

    // Modbus管理器
    // 功能：负责Modbus RTU通信，读取电气参数数据，控制设备状态
    ModbusManager {
        id: modbusManager

        // 电压值变化回调（已注释掉与波形数据管理器相关的代码）
        // onVoltageChanged: {
        //     // if (!window.dataUpdatePending) {
        //     //     window.dataUpdatePending = true
        //     //     dataUpdateTimer.start()
        //     // }
        // }

        // 风机状态变化回调
        onFanStateChanged: {
            var currentTime = Date.now()
            if (currentTime - parent.lastFanStateLogTime >= 10000) {
                console.log("【主页】风机状态变化:", modbusManager.fanState)
                parent.lastFanStateLogTime = currentTime
            }
        }

        // 连接超时回调
        onConnectionTimeout: {
            console.log("【主页】连接超时")
            connectionTimeoutDialog.open()
        }

        // Modbus错误处理回调
        onErrorOccurred: function(error) {
            console.log("Modbus错误:", error)
        }

        // Modbus连接状态变化回调
        onConnectedChanged: function() {
            // 当连接建立时，发送电压输入框中的电压值到设备
            if (modbusManager.connected && voltageInput.text !== "") {
                var voltage = parseFloat(voltageInput.text)
                modbusManager.writeVoltageValue(voltage)
            }
        }
    }

    // 发电机测试管理器
    // 功能：负责发电机测试通信，通过 SerialPortManager 发送和接收数据
    GeneratorTestManager {
        id: generatorTestManager

        // 数据接收回调
        onDataReceived: function(data) {
            console.log("发电机测试 - 接收到数据:", data)
            // 处理三相电参数响应（主页或分步页面打开时都解析）
            if (showThreePhaseParams || (stepRunPage && stepRunPage.showThreePhaseParams)) {
                generatorTestManager.parseThreePhaseParamsResponse(data)
            }
        }

        // 三相电参数更新回调
        onThreePhaseParamsUpdated: {
            console.log("三相电参数已更新")
            // 从 generatorTestManager 复制数据到 QML 属性
            threePhaseVoltageA = generatorTestManager.getThreePhaseVoltageA()
            threePhaseVoltageB = generatorTestManager.getThreePhaseVoltageB()
            threePhaseVoltageC = generatorTestManager.getThreePhaseVoltageC()
            threePhaseCurrentA = generatorTestManager.getThreePhaseCurrentA()
            threePhaseCurrentB = generatorTestManager.getThreePhaseCurrentB()
            threePhaseCurrentC = generatorTestManager.getThreePhaseCurrentC()
            threePhaseFrequency = generatorTestManager.getThreePhaseFrequency()
            console.log("更新后 - A相电压:", threePhaseVoltageA, "频率:", threePhaseFrequency)
        }

        // 错误处理回调
        onErrorOccurred: function(error) {
            console.log("发电机测试错误:", error)
        }
    }
    
    // 组件加载完成后设置管理器的SerialPortManager
    Component.onCompleted: {
        serialPortManager.refreshPorts()
        modbusManager.setSerialPortManager(serialPortManager)
        generatorTestManager.setSerialPortManager(serialPortManager)
        // 初始化时发送默认电压值200V到设备
        if (modbusManager && modbusManager.connected) {
            modbusManager.writeVoltageValue(200)
        }
    }
    
    // 暴露modbusManager属性供其他页面访问
    property var modbusManagerInstance: modbusManager
    
    // 暴露serialPortManager属性供其他页面访问
    property var serialPortManagerInstance: serialPortManager

    // 暴露generatorTestManager属性供其他页面访问
    property var generatorTestManagerInstance: generatorTestManager
    
    // 三相电参数定时器
    Timer {
        id: threePhaseParamsTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (showThreePhaseParams) {
                generatorTestManager.requestThreePhaseParams()
            } else {
                threePhaseParamsTimer.stop()
            }
        }
    }

    // ========================================================================//
    // 功能函数
    // ========================================================================//

    // 更新串口下拉框数据模型
    // 功能：将串口管理器返回的端口列表转换为下拉框可用的格式
    // 说明：遍历可用串口列表，创建下拉框数据模型
    function updateSerialPortModel() {
        var ports = serialPortManager.availablePorts
        var newModel = []
        for (var i = 0; i < ports.length; i++) {
            newModel.push({ text: ports[i] })
        }
        serialPortDropdown.model = newModel
    }

    // 获取当前电压模式的配置
    // 功能：返回固定的电流范围配置
    function getVoltageModeConfig() {
        // 固定配置
        return { minCurrent: 0.1, maxCurrent: 40, step: 0.1 }
    }

    // 验证电压输入值
    // 功能：验证用户输入的电压值是否符合要求
    // 参数：
    // - value: 输入的电压值
    // 返回值：验证结果对象，包含 isValid（是否有效）和 message（错误信息）字段
    function validateVoltageInput(value) {
        if (value === "") {
            return { isValid: false, message: "电压输入不能为空！请输入200~270内的数值，步进为1V。" }
        }
        
        var voltage = parseFloat(value)
        if (isNaN(voltage)) {
            return { isValid: false, message: "电压输入必须是数字！请输入200~270内的数值，步进为1V。" }
        }
        
        // 检查是否为整数（步进为1）
        if (voltage !== Math.floor(voltage)) {
            return { isValid: false, message: "电压输入必须为整数！请输入200~270内的数值，步进为1V。" }
        }
        
        if (voltage < 200) {
            return { isValid: false, message: "电压输入不能小于200！请输入200~270内的数值，步进为1V。" }
        }
        
        if (voltage > 270) {
            return { isValid: false, message: "电压输入不能大于270！请输入200~270内的数值，步进为1V。" }
        }
        
        return { isValid: true, message: "" }
    }

    // 验证电流输入值
    // 功能：验证用户输入的电流值是否符合要求
    // 参数：
    // - value: 输入的电流值
    // 返回值：验证结果对象，包含 isValid（是否有效）和 message（错误信息）字段
    function validateCurrentInput(value) {
        var config = getVoltageModeConfig()
        
        if (value === "") {
            return { isValid: false, message: "电流输入不能为空！请输入" + config.minCurrent + "~" + config.maxCurrent + "内的数值，步进为" + config.step + "A。" }
        }
        
        var current = parseFloat(value)
        if (isNaN(current)) {
            return { isValid: false, message: "电流输入必须是数字！请输入" + config.minCurrent + "~" + config.maxCurrent + "内的数值，步进为" + config.step + "A。" }
        }
        
        // 检查小数点后是否只有一位
        var parts = value.toString().split(".")
        if (parts.length > 1 && parts[1].length > 1) {
            return { isValid: false, message: "电流输入最多只能有一位小数！请输入" + config.minCurrent + "~" + config.maxCurrent + "内的数值，步进为" + config.step + "A。" }
        }
        
        if (current < config.minCurrent) {
            return { isValid: false, message: "电流输入不能小于" + config.minCurrent + "！请输入" + config.minCurrent + "~" + config.maxCurrent + "内的数值，步进为" + config.step + "A。" }
        }
        
        if (current > config.maxCurrent) {
            return { isValid: false, message: "电流输入不能大于" + config.maxCurrent + "！请输入" + config.minCurrent + "~" + config.maxCurrent + "内的数值，步进为" + config.step + "A。" }
        }
        
        return { isValid: true, message: "" }
    }
    
    // 检查风机状态是否满足操作条件
    // 功能：检查风机状态是否满足操作条件
    // 返回值：true表示满足条件，false表示不满足条件
    function checkFanStatus() {
        // 检查串口是否打开
        if (!serialPortOpen) {
            return true; // 串口未打开时，不弹出提示
        }
        
        // 调试模式下，不检查风机1的状态
        if (debugMode) {
            return true;
        }
        
        // 检查风机开关1是否打开
        if (!fanSwitchOn) {
            fanStatusWarningDialog.open();
            return false;
        }
        
        // 检查风机1是否就绪
        if (!modbusManager.hasFanStateData) {
            fanStatusWarningDialog.open();
            return false;
        }
        
        // 检查风机1是否运行
        if (modbusManager.fanState !== 1) {
            fanStatusWarningDialog.open();
            return false;
        }
        
        // 从站2不再使用，移除对从站2风机状态的检查
        
        return true;
    }

    // ========================================================================//
    // 界面布局
    // ========================================================================//

    // 页面背景
    // 类型：Rectangle
    // 用途：设置页面背景为透明，允许底层背景显示
    background: Rectangle {
        color: "transparent"
    }

    // ========================================================================//
    // 串口控制区域
    // ========================================================================//

    // 风机开关1
    // 类型：ESwitchButton
    // 功能：控制从站1设备风机的运行状态
    // 说明：通过Modbus协议向设备发送风机状态命令
    ESwitchButton {
        id: fanSwitch1
        text: "风机开关1"
        size: "s"
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        thumbColor: "#FFFFFF"
        trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"
        trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"
        shadowEnabled: true
        enabled: serialPortOpen && modbusManager.connected && modbusManager.hasFanStateData
        anchors.top: serialPortSwitch.bottom
        anchors.topMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: function(checked) {
            modbusManager.writeFanState(checked)
            console.log("风机开关1状态:", checked ? "开启(1)" : "关闭(0)")
            
            // 更新风机开关状态属性
            fanSwitchOn = checked
            
            // 从站2不再使用，移除对风机2的自动关闭逻辑
            
            // 当风机关闭时，停止分步运行（如果正在运行）
            if (!checked) {
                if (stepRunPage && stepRunPage.isRunning) {
                    console.log("风机关闭，停止分步运行")
                    stepRunPage.stopRun()
                }
                
            } else {
                // 当风机开启时，重置急停状态
                emergencyStopped = false
            }
        }
    }

    // 风机开关2（已注释，从站2不再使用）
    // ESwitchButton {
    //     id: fanSwitch2
    //     text: "风机开关2"
    //     size: "s"
    //     containerColor: theme.secondaryColor
    //     textColor: theme.textColor
    //     thumbColor: "#FFFFFF"
    //     trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"
    //     trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"
    //     shadowEnabled: true
    //     enabled: debugMode || (serialPortOpen && modbusManager.connected && fanSwitchOn && modbusManager.hasFanStateData && modbusManager.fanState === 1)
    //     anchors.top: fanSwitch1.bottom
    //     anchors.topMargin: 8
    //     anchors.right: parent.right
    //     anchors.rightMargin: 16
    //     onToggled: function(checked) {
    //         // 控制从站2的风机
    //         modbusManager.writeFanState(checked, 2)
    //         modbusManager.setFanSwitch2State(checked)
    //         console.log("风机开关2状态:", checked ? "开启(1)" : "关闭(0)")
    //     }
    // }

    /*
    // 调试模式按钮
    // 类型：EButton
    // 功能：切换调试模式，调试模式下可以单独控制风机2
    EButton {
        id: debugModeButton
        text: debugMode ? "退出调试" : "调试模式"
        size: "s"
        containerColor: debugMode ? (theme.isDark ? "#FF5722" : "#E64A19") : theme.secondaryColor
        textColor: theme.textColor
        shadowEnabled: true
        visible: true
        anchors.top: fanSwitch2.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onClicked: {
            debugMode = !debugMode
            console.log("调试模式:", debugMode ? "开启" : "关闭")
            
            // 当退出调试模式时，如果风机1未运行，自动关闭风机2
            if (!debugMode && fanSwitch2.checked && (!fanSwitchOn || modbusManager.fanState !== 1)) {
                fanSwitch2.checked = false
                console.log("退出调试模式，风机1未运行，自动关闭风机2")
            }
        }
    }
    */

    EButton {
        id: threePhaseParamsButton
        text: showThreePhaseParams ? "关闭三相参数" : "三相电气参数"
        size: "s"
        containerColor: showThreePhaseParams ? (theme.isDark ? "#FF9800" : "#FF9800") : theme.secondaryColor
        textColor: showThreePhaseParams ? "white" : theme.textColor
        shadowEnabled: true
        width: fanSwitch1.width
        anchors.top: fanSwitch1.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        enabled: serialPortOpen
        visible: false // 隐藏三相电气参数按钮
        onClicked: {
            showThreePhaseParams = !showThreePhaseParams
            if (showThreePhaseParams) {
                threePhaseParamsTimer.start()
                generatorTestManager.requestThreePhaseParams()
            } else {
                threePhaseParamsTimer.stop()
            }
        }
    }



    // 运行时间卡片
    // 类型：EHoverCard
    // 功能：显示设备的累计运行时间和本次运行时间
    EHoverCard {
        id: runTimeCard
        z: 1
        width: fanSwitch1.width
        height: 160
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        visible: false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            Text {
                text: "累计运行时间"
                color: theme.textColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: totalRunTime + " 秒"
                color: theme.textColor
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.preferredWidth: parent.width
                Layout.preferredHeight: 1
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "本次运行时间"
                color: theme.textColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: currentRunTime + " 秒"
                color: theme.textColor
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // 单相电参数卡片
    // 类型：EHoverCard
    // 功能：显示单相的电压、电流、功率
    EHoverCard {
        id: singlePhaseParamsCard
        z: 1
        width: fanSwitch1.width
        height: 220
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            Text {
                text: "电压"
                color: theme.textColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: modbusManager.singlePhaseVoltage.toFixed(1) + " V"
                color: theme.textColor
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.preferredWidth: parent.width
                Layout.preferredHeight: 1
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "电流"
                color: theme.textColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: modbusManager.singlePhaseCurrent.toFixed(1) + " A"
                color: theme.textColor
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.preferredWidth: parent.width
                Layout.preferredHeight: 1
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "功率"
                color: theme.textColor
                font.pixelSize: 12
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: modbusManager.singlePhasePower.toFixed(1) + " kW"
                color: theme.textColor
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // 风机状态指示灯（从站1）
    // 类型：ECard
    // 功能：显示从站1风机的实际开关状态（读取从站1寄存器2）
    // 说明：根据Modbus读取的风机状态数据显示不同颜色的指示灯
    ECard {
        id: fanStatusIndicator
        width: fanSwitch1.width
        height: 40
        cardColor: theme.secondaryColor
        radius: 20
        padding: 10
        shadowEnabled: true
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: fanSwitch1.left
        anchors.rightMargin: 24

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: !serialPortOpen ? (theme.isDark ? "#555555" : "#CCCCCC") : (!modbusManager.hasFanStateData ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.fanState === 1 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336")))
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: !serialPortOpen ? "风机1状态：未连接" : (!modbusManager.hasFanStateData ? "风机1状态：连接中" : (modbusManager.fanState === 1 ? "风机1状态：运行" : "风机1状态：停止"))
                color: theme.textColor
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
    
    // 急停按钮
    // 类型：EButton
    // 功能：点击后弹出确认窗口，用于紧急停止设备
    // 说明：红色背景，带有禁止图标，点击后显示确认对话框
    EButton {
        id: emergencyStopButton
        text: "急停"
        iconCharacter: ""           // Font Awesome 禁止图标
        size: "s"
        containerColor: theme.isDark ? "#B71C1C" : "#F44336" // 红色背景
        textColor: "#FFFFFF"              // 白色文字
        iconColor: "#FFFFFF"              // 白色图标
        shadowEnabled: true
        width: 100
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: highTempIndicator.left
        anchors.rightMargin: 8
        onClicked: {
            emergencyStopDialog.open()
        }
    }

    // 高温报警状态指示灯（从站1）
    // 类型：ECard
    // 功能：显示设备高温报警状态（读取从站1寄存器3）
    // 说明：根据Modbus读取的温度状态数据显示不同颜色的指示灯
    ECard {
        id: highTempIndicator
        width: fanSwitch1.width
        height: 40
        cardColor: theme.secondaryColor
        radius: 20
        padding: 10
        shadowEnabled: true
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.right: fanStatusIndicator.left
        anchors.rightMargin: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: !serialPortOpen ? (theme.isDark ? "#555555" : "#CCCCCC") : (!modbusManager.hasHighTempData ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.highTempState === 0 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336")))
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: !serialPortOpen ? "温度1状态： 未连接" : (!modbusManager.hasHighTempData ? "温度1状态： 连接中" : (modbusManager.highTempState === 0 ? "温度1状态：   正常" : "温度1状态：高温报警"))
                color: theme.textColor
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // 风机状态指示灯（从站2，已注释，从站2不再使用）
    // ECard {
    //     id: fanStatusIndicator2
    //     width: fanSwitch1.width
    //     height: 40
    //     cardColor: theme.secondaryColor
    //     radius: 20
    //     padding: 10
    //     shadowEnabled: true
    //     anchors.top: fanStatusIndicator.bottom
    //     anchors.topMargin: 8
    //     anchors.right: fanSwitch1.left
    //     anchors.rightMargin: 24

    //     RowLayout {
    //         spacing: 8
    //         Layout.fillWidth: true
    //         Layout.fillHeight: true

    //         Rectangle {
    //             width: 16
    //             height: 16
    //             radius: 8
    //             color: !serialPortOpen ? (theme.isDark ? "#555555" : "#CCCCCC") : (!modbusManager.hasFanStateData2 ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.fanState2 === 1 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336")))
    //             Layout.alignment: Qt.AlignVCenter
    //         }

    //         Text {
    //             text: !serialPortOpen ? "风机2状态：未连接" : (!modbusManager.hasFanStateData2 ? "风机2状态：连接中" : (modbusManager.fanState2 === 1 ? "风机2状态：运行" : "风机2状态：停止"))
    //             color: theme.textColor
    //             font.pixelSize: 12
    //             Layout.fillWidth: true
    //             Layout.alignment: Qt.AlignVCenter
    //         }
    //     }
    // }

    // 高温报警状态指示灯（从站2，已注释，从站2不再使用）
    // ECard {
    //     id: highTempIndicator2
    //     width: fanSwitch1.width
    //     height: 40
    //     cardColor: theme.secondaryColor
    //     radius: 20
    //     padding: 10
    //     shadowEnabled: true
    //     anchors.top: highTempIndicator.bottom
    //     anchors.topMargin: 8
    //     anchors.right: fanStatusIndicator2.left
    //     anchors.rightMargin: 8

    //     RowLayout {
    //         spacing: 8
    //         Layout.fillWidth: true
    //         Layout.fillHeight: true

    //         Rectangle {
    //             width: 16
    //             height: 16
    //             radius: 8
    //             color: !serialPortOpen ? (theme.isDark ? "#555555" : "#CCCCCC") : (!modbusManager.hasHighTempData2 ? (theme.isDark ? "#555555" : "#CCCCCC") : (modbusManager.highTempState2 === 0 ? (theme.isDark ? "#66BB6A" : "#4CAF50") : (theme.isDark ? "#EF5350" : "#F44336")))
    //             Layout.alignment: Qt.AlignVCenter
    //         }

    //         Text {
    //             text: !serialPortOpen ? "温度2状态： 未连接" : (!modbusManager.hasHighTempData2 ? "温度2状态： 连接中" : (modbusManager.highTempState2 === 0 ? "温度2状态：   正常" : "温度2状态：高温报警"))
    //             color: theme.textColor
    //             font.pixelSize: 12
    //             Layout.fillWidth: true
    //             Layout.alignment: Qt.AlignVCenter
    //         }
    //     }
    // }

    // 数字时钟卡片
    // 类型：EClockCard
    // 功能：显示当前时间和天气信息
    // 说明：使用网络天气API，图标随天气自动切换
    EClockCard {
        id: clockCard
        useNetworkWeather: true
        weatherApiKey: "SLKpiXphkV7ch3vZp"
        weatherLocation: "ip"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: 200
        height: 70
    }

    // 刷新串口按钮
    // 类型：EButton
    // 功能：点击后刷新可用串口列表
    // 说明：带有刷新图标，点击时图标旋转
    EButton {
        id: refreshSerialButton
        text: "刷新串口"
        iconCharacter: "\uf021"           // Font Awesome 刷新图标
        iconRotateOnClick: true            // 点击时图标旋转
        size: "s"                          // 小号尺寸
        containerColor: theme.secondaryColor // 背景颜色（自适应深色模式）
        textColor: theme.textColor         // 文字颜色（自适应深色模式）
        iconColor: theme.textColor         // 图标颜色（自适应深色模式）
        shadowEnabled: true                // 启用阴影效果
        width: fanSwitch1.width
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 16
        onClicked: {
            serialPortManager.refreshPorts()
        }
    }

    // 串口选择下拉框
    // 类型：EDropdown
    // 功能：显示可用串口列表，供用户选择
    // 说明：串口打开时自动禁用选择
    EDropdown {
        id: serialPortDropdown
        z: 10
        title: "选择串口"                   // 默认提示文字
        width: fanSwitch1.width                          // 宽度
        headerHeight: 40                    // 头部高度（与按钮一致）
        radius: 20                          // 圆角半径
        containerColor: theme.secondaryColor // 背景颜色
        textColor: theme.textColor          // 文字颜色
        shadowEnabled: true                 // 启用阴影效果
        enabled: !serialPortSwitch.checked  // 串口打开时禁用选择
        anchors.top: refreshSerialButton.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onSelectionChanged: function(index) {
            selectedSerialPortIndex = index
        }
    }

    // 波特率选择下拉框
    // 类型：EDropdown
    // 功能：显示常用波特率列表，供用户选择
    // 说明：默认选中9600波特率
    EDropdown {
        id: baudRateDropdown
        z: 9
        title: "波特率"
        width: fanSwitch1.width
        headerHeight: 40
        radius: 20
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        shadowEnabled: true
        enabled: !serialPortSwitch.checked
        anchors.top: serialPortDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        model: [
            { text: "1200" },
            { text: "2400" },
            { text: "4800" },
            { text: "9600" },
            { text: "19200" },
            { text: "38400" },
            { text: "57600" },
            { text: "115200" }
        ]
        Component.onCompleted: {
            selectedIndex = 3
        }
    }

    // 奇偶校验位选择下拉框
    // 类型：EDropdown
    // 功能：显示校验方式列表，供用户选择
    // 说明：默认选中无校验
    EDropdown {
        id: parityDropdown
        z: 8
        title: "校验位"
        width: fanSwitch1.width
        headerHeight: 40
        radius: 20
        containerColor: theme.secondaryColor
        textColor: theme.textColor
        shadowEnabled: true
        enabled: !serialPortSwitch.checked
        anchors.top: baudRateDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        model: [
            { text: "无校验" },
            { text: "奇校验" },
            { text: "偶校验" }
        ]
        Component.onCompleted: {
            selectedIndex = 0
        }
    }

    // 串口开关
    // 类型：ESwitchButton
    // 功能：控制串口的连接/断开状态
    // 说明：打开时连接串口并开始读取数据，关闭时断开连接并停止读取
    ESwitchButton {
        id: serialPortSwitch
        text: "串口开关"
        size: "s"                          // 小号尺寸
        containerColor: theme.secondaryColor // 背景颜色
        textColor: theme.textColor          // 文字颜色
        thumbColor: "#FFFFFF"               // 滑块颜色（白色）
        trackUncheckedColor: theme.isDark ? "#555555" : "#CCCCCC"  // 轨道未选中颜色
        trackCheckedColor: theme.isDark ? "#66BB6A" : "#4CAF50"    // 轨道选中颜色（绿色）
        shadowEnabled: true                 // 启用阴影效果
        width: fanSwitch1.width
        anchors.top: parityDropdown.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 16
        onToggled: function(checked) {
            serialPortOpen = checked
            if (checked) {
                if (selectedSerialPortIndex >= 0 && serialPortDropdown.model[selectedSerialPortIndex]) {
                    var portName = serialPortDropdown.model[selectedSerialPortIndex].text
                    var baudRate = parseInt(baudRateDropdown.model[baudRateDropdown.selectedIndex].text)
                    var parity = parityDropdown.selectedIndex
                    // 只通过SerialPortManager打开一次串口
                    var serialSuccess = serialPortManager.openPort(portName, baudRate)
                    if (serialSuccess) {
                        // 串口打开成功后，初始化ModbusManager状态
                        modbusManager.connectToPort(portName, baudRate, parity)
                        modbusManager.startReading(1000)
                        // 开始计时
                        currentRunTime = 0
                        runTimeTimer.start()
                    } else {
                        serialPortSwitch.checked = false
                        serialPortOpen = false
                    }
                } else {
                    serialPortSwitch.checked = false
                    serialPortOpen = false
                }
            } else {
                    modbusManager.stopReading()
                    modbusManager.disconnectPort()
                    serialPortManager.closePort()
                    // 停止计时
                    runTimeTimer.stop()
                    // 重置风机状态和高温状态显示
                    console.log("串口关闭，重置设备状态显示")

                    // 退出分步运行模式
                    if (stepRunActive) {
                        console.log("串口关闭，退出分步运行模式")
                        stepRunActive = false
                        // 如果分步运行页面正在运行，停止运行
                        if (stepRunPage && stepRunPage.isRunning) {
                            stepRunPage.stopRun()
                        }
                    }
                }
        }
    }



    // ========================================================================//
    // 电气参数显示区域
    // ========================================================================//

    // 三相电气参数卡片（已注释）
    // 类型：EHoverCard
    // 功能：显示A、B、C三相的电压、电流、功率
    /*
    EHoverCard {
        id: electricCard
        width: 420
        height: 220
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 10
        anchors.verticalCenterOffset: -40
        visible: !stepRunActive

        // 内容布局：网格排列三相数据
        GridLayout {
            anchors.fill: parent
            anchors.margins: 12
            columns: 6
            rowSpacing: 8
            columnSpacing: 8

            Text {
                text: ""
                Layout.preferredWidth: 40
            }

            Text {
                text: "A相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "B相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "C相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电压"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "220.0 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "221.5 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "219.8 V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电流"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "10.5 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "10.2 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "10.8 A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "功率"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: "2.31 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "2.26 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "2.37 kW"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }
        }
    }
    */

    // 分步运行模式提示
    // 类型：RowLayout
    // 功能：当分步运行模式启用时显示提示信息
    // 说明：显示橙色提示，告知用户电流由分步运行控制
    RowLayout {
        id: stepRunTipRow
        spacing: 8
        anchors.centerIn: parent
        visible: stepRunActive

        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: theme.isDark ? "#FF9800" : "#FF9800"
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: "分步运行模式已启用，电流由分步运行控制"
            color: theme.isDark ? "#FF9800" : "#FF9800"
            font.pixelSize: 20
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // 主输入区域
    // 类型：Column
    // 功能：包含电流输入控制
    // 说明：仅在非分步运行模式下显示，且操作条件满足时显示
    Column {
        id: mainInputColumn
        spacing: 16
        anchors.top: parent.top
        anchors.topMargin: 210
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -90
        visible: !stepRunActive && operationConditionsMet
        
        // 输入行容器
        // 类型：Column
        // 功能：包含电流输入控件
        Column {
            id: inputRow
            spacing: 32
            anchors.horizontalCenter: parent.horizontalCenter

            // 电压和电流输入
            // 类型：Row
            // 功能：电压和电流的输入和控制
            Row {
                spacing: 40

                Column {
                    spacing: 8

                    Text {
                        text: "请输入电压/V"
                        color: theme.textColor
                        font.pixelSize: 14
                    }

                    // 电压输入框
                    // 类型：EInput
                    // 功能：直接输入电压值，范围200-270V
                    EInput {
                        id: voltageInput
                        placeholderText: ""
                        width: 120
                        height: 50
                        radius: 25
                        enabled: !stepRunActive
                        property bool validationError: false
                        text: "200"
                        onTextChanged: {
                            var text = voltageInput.text
                            var filtered = ""
                            
                            // 只允许输入数字
                            for (var i = 0; i < text.length; i++) {
                                var ch = text.charAt(i)
                                if (ch >= '0' && ch <= '9') {
                                    filtered += ch
                                }
                            }
                            
                            if (filtered !== text) {
                                voltageInput.text = filtered
                            }
                        }
                        onAccepted: {
                            if (voltageInput.text !== "") {
                                var voltage = parseFloat(voltageInput.text)
                                
                                // 根据步进1V四舍五入
                                voltage = Math.round(voltage)
                                
                                // 自动更正输入值
                                if (voltage > 270) {
                                    voltage = 270
                                    console.log("电压输入值大于最大值，自动更正为: 270V")
                                }
                                if (voltage < 200) {
                                    voltage = 200
                                    console.log("电压输入值小于最小值，自动更正为: 200V")
                                }
                                
                                // 更新输入框显示
                                voltageInput.text = voltage.toString()
                                
                                var validation = validateVoltageInput(voltageInput.text)
                                voltageInput.validationError = !validation.isValid
                                if (!validation.isValid) {
                                    console.log("电压输入验证失败:", validation.message)
                                }
                            } else {
                                voltageInput.validationError = false
                            }
                        }
                    }

                    // 电压输入提示
                    Text {
                        text: "范围：200~270V，步进：1V"
                        color: theme.textColor
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Column {
                    spacing: 8

                    Text {
                        text: "请输入电流/A"
                        color: theme.textColor
                        font.pixelSize: 14
                    }

                    // 电流输入框
                    // 类型：EInput
                    // 功能：直接输入电流值
                    EInput {
                        id: currentInput
                        placeholderText: ""
                        width: 120
                        height: 50
                        radius: 25
                        enabled: !stepRunActive
                        property bool validationError: false
                        onTextChanged: {
                            var text = currentInput.text
                            var filtered = ""
                            var hasDecimalPoint = false
                            
                            // 只允许输入数字和一个小数点
                            for (var i = 0; i < text.length; i++) {
                                var ch = text.charAt(i)
                                if (ch >= '0' && ch <= '9') {
                                    filtered += ch
                                } else if (ch === '.' && !hasDecimalPoint) {
                                    filtered += ch
                                    hasDecimalPoint = true
                                }
                            }
                            
                            if (filtered !== text) {
                                currentInput.text = filtered
                            }
                        }
                        onAccepted: {
                            if (currentInput.text !== "") {
                                var current = parseFloat(currentInput.text)
                                var config = getVoltageModeConfig()
                                
                                // 根据步进0.1A四舍五入
                                current = Math.round(current * 10) / 10
                                
                                // 自动更正输入值
                                if (current > config.maxCurrent) {
                                    current = config.maxCurrent
                                    console.log("输入值大于最大值，自动更正为:", config.maxCurrent)
                                }
                                if (current < config.minCurrent && current > 0) {
                                    current = config.minCurrent
                                    console.log("输入值小于最小值，自动更正为:", config.minCurrent)
                                }
                                
                                // 更新输入框显示，确保只有一位小数
                                currentInput.text = current.toFixed(1)
                                
                                var validation = validateCurrentInput(currentInput.text)
                                currentInput.validationError = !validation.isValid
                                if (!validation.isValid) {
                                    console.log("输入验证失败:", validation.message)
                                }
                            } else {
                                currentInput.validationError = false
                            }
                        }
                    }

                    // 电流输入提示
                    Text {
                        text: {
                            var config = getVoltageModeConfig()
                            return "范围：" + config.minCurrent + "~" + config.maxCurrent + "A，步进：" + config.step + "A"
                        }
                        color: theme.textColor
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item {
                    width: childrenRect.width
                    height: childrenRect.height
                    y: 30

                    // 显示载入和卸载按钮
                    Row {
                        id: loadUnloadButtons
                        spacing: 8
                        visible: !stepRunActive

                        // 载入按钮
                        // 类型：EButton
                        // 功能：将电流值写入设备
                        EButton {
                            id: load1Button
                            text: "载入"
                            iconCharacter: "\uf019"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            iconColor: theme.textColor
                            shadowEnabled: true
                            enabled: !stepRunActive
                            opacity: stepRunActive ? 0.5 : 1.0
                            onClicked: {
                                var clickStartTime = Date.now()
                                console.log("【计时】载入按钮点击开始 - 时间戳:", clickStartTime)
                                
                                if (!checkFanStatus()) {
                                    console.log("【计时】风机状态检查失败")
                                    return;
                                }
                                var afterFanCheck = Date.now()
                                console.log("【计时】风机状态检查耗时:", (afterFanCheck - clickStartTime), "ms")
                                
                                voltageInput.focus = false
                                currentInput.focus = false
                                
                                var beforeValidation = Date.now()
                                var voltageValidation = validateVoltageInput(voltageInput.text)
                                var currentValidation = validateCurrentInput(currentInput.text)
                                var afterValidation = Date.now()
                                console.log("【计时】输入验证耗时:", (afterValidation - beforeValidation), "ms")
                                
                                if (!voltageValidation.isValid) {
                                    powerWarningDialog.message = voltageValidation.message
                                    powerWarningDialog.open()
                                    return
                                }
                                if (!currentValidation.isValid) {
                                    powerWarningDialog.message = currentValidation.message
                                    powerWarningDialog.open()
                                    return
                                }
                                
                                var beforeParse = Date.now()
                                var voltage = parseFloat(voltageInput.text)
                                var current = parseFloat(currentInput.text)
                                var afterParse = Date.now()
                                console.log("【计时】解析电压和电流值耗时:", (afterParse - beforeParse), "ms")
                                
                                var message = "确定要载入以下数值？\n电压: " + voltage + " V\n电流: " + current + " A"
                                loadConfirmDialog.message = message
                                
                                var beforeOpen = Date.now()
                                loadConfirmDialog.open()
                                var afterOpen = Date.now()
                                console.log("【计时】打开确认对话框耗时:", (afterOpen - beforeOpen), "ms")
                                
                                var clickEndTime = Date.now()
                                console.log("【计时】载入按钮点击处理总耗时:", (clickEndTime - clickStartTime), "ms")
                            }
                        }

                        // 卸载按钮
                        // 类型：EButton
                        // 功能：执行卸载操作
                        EButton {
                            id: unload1Button
                            text: "卸载"
                            iconCharacter: "\uf1f8"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            iconColor: theme.textColor
                            shadowEnabled: true
                            enabled: !stepRunActive
                            opacity: stepRunActive ? 0.5 : 1.0
                            onClicked: {
                                if (!checkFanStatus()) {
                                    return;
                                }
                                unloadConfirmDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 操作条件提示信息
    // 类型：Text
    // 功能：当操作条件不满足时显示提示信息
    // 说明：仅在非分步运行模式下显示，且操作条件不满足时显示
    Text {
        anchors.top: parent.top
        anchors.topMargin: 280
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -90
        text: operationStatusMessage
        color: theme.textColor
        font.pixelSize: 32
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !stepRunActive && !operationConditionsMet
    }
    


    // ========================================================================//
    // 对话框
    // ========================================================================//

    // 载入确认对话框
    // 类型：EAlertDialog
    // 功能：确认电流值载入操作
    // 说明：根据消息内容判断是哪一路电流，然后执行写入操作
    EAlertDialog {
        id: loadConfirmDialog
        title: "确认载入"
        message: ""
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            var startTime = Date.now()
            console.log("【计时】载入确认对话框onConfirm开始 - 时间戳:", startTime)
            
            // 检查串口是否打开（调试模式下跳过）
            if (!serialPortOpen && !debugMode) {
                console.log("串口链接失败，无法写入电压和电流值")
                messageToast.show("载入失败，请检查串口链接")
                return
            }
            
            var afterCheck = Date.now()
            console.log("【计时】检查串口状态耗时:", (afterCheck - startTime), "ms")
            
            // 写入电压值
            var beforeParse = Date.now()
            var voltage = parseFloat(voltageInput.text)
            var current = parseFloat(currentInput.text)
            var afterParse = Date.now()
            console.log("【计时】解析电压和电流值耗时:", (afterParse - beforeParse), "ms")
            console.log("【计时】准备调用writeVoltageValue，电压值:", voltage, "V")
            
            var beforeWrite = Date.now()
            modbusManager.writeVoltageValue(voltage)
            var afterVoltageWrite = Date.now()
            console.log("【计时】调用writeVoltageValue耗时:", (afterVoltageWrite - beforeWrite), "ms")
            
            // 写入电流值
            console.log("【计时】准备调用writeCurrent，电流值:", current, "A")
            modbusManager.writeCurrent(current, 1)
            var afterWrite = Date.now()
            console.log("【计时】调用writeCurrent耗时:", (afterWrite - afterVoltageWrite), "ms")
            
            console.log("载入: 电压 " + voltage + " V -> 寄存器30, 电流 " + current + " A -> 寄存器50")
            messageToast.show("载入成功，当前电压：" + voltage + " V，电流： " + current + " A")
            
            var endTime = Date.now()
            console.log("【计时】载入确认对话框onConfirm总耗时:", (endTime - startTime), "ms")
        }
    }

    // 卸载确认对话框
    // 类型：EAlertDialog
    // 功能：确认卸载操作
    // 说明：执行卸载命令，将设备电流设置为0
    EAlertDialog {
        id: unloadConfirmDialog
        title: "确认卸载"
        message: "确定要执行卸载操作吗？"
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            // 检查串口是否打开（调试模式下跳过）
            if (!serialPortOpen && !debugMode) {
                console.log("串口未打开，无法执行卸载操作")
                messageToast.show("串口未打开，卸载失败")
                return
            }
            
            // 执行卸载操作
            modbusManager.writeUnload(1)
            console.log("卸载: 从站1寄存器35写1 (功能码06)")
            
            // 显示卸载成功提示
            messageToast.show("卸载成功")
            
            // 清空输入框
            currentInput.text = ""
        }
    }
    


    // 急停确认对话框
    // 类型：EAlertDialog
    // 功能：确认紧急停止操作
    // 说明：执行紧急停止命令，立即停止所有设备运行
    EAlertDialog {
        id: emergencyStopDialog
        title: "紧急停止确认"
        message: "确定要执行紧急停止操作吗？\n此操作将立即停止所有设备运行！"
        confirmText: "确定"
        cancelText: "取消"
        onConfirm: {
            // 执行急停操作
            console.log("执行紧急停止操作")
            modbusManager.writeEmergencyStop(false) // 写入0到寄存器5，触发急停
            
            // 等待急停命令发送完成后再执行后续操作
            var emergencyStopConnection = modbusManager.emergencyStopSent.connect(function() {
                // 停止分步运行（如果正在运行）
                if (stepRunPage && stepRunPage.isRunning) {
                    stepRunPage.stopRun()
                }
                
                // 停止运行时间计时器
                runTimeTimer.stop()
                
                // 设置急停状态
                homePage.emergencyStopped = true
                
                // 显示提醒信息
                messageToast.show("紧急停止操作已执行，请关闭并重新开启风机开关以继续操作")
                
                // 断开连接
                emergencyStopConnection.disconnect()
            })
        }
    }

    // 电流输入警告对话框
    // 类型：EAlertDialog
    // 功能：显示电流输入验证失败的警告信息
    EAlertDialog {
        id: powerWarningDialog
        title: "输入验证失败"
        message: ""
        confirmText: "确定"
        cancelText: ""
    }
    
    // 风机状态警告对话框
    // 类型：EAlertDialog
    // 功能：显示风机状态不满足条件的警告信息
    EAlertDialog {
        id: fanStatusWarningDialog
        title: "风机状态警告"
        message: "请检查风机状态，风机运行时才能进行此操作"
        confirmText: "确定"
        cancelText: ""
    }

    // 连接超时对话框
    // 类型：EAlertDialog
    // 功能：显示连接超时警告信息
    EAlertDialog {
        id: connectionTimeoutDialog
        title: "连接超时"
        message: "串口无法连接，请检查连接线或检查是否开启电源"
        confirmText: "确定"
        cancelText: ""
    }

    // 动画窗口包装器
    // 类型：EAnimatedWindow
    // 功能：用于页面切换动画效果
    EAnimatedWindow {
        id: animationWrapper
    }
    
    // 消息提示组件
    // 类型：MessageToast
    // 功能：显示操作成功的消息提示
    MessageToast {
        id: messageToast
        anchors.top: parent.top
        anchors.topMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        bgColor: theme.isDark ? "#333333" : "#E9EEF6"
        fgColor: theme.isDark ? "#FFFFFF" : "#000000"
    }

    // 三相电参数卡片
    EHoverCard {
        id: threePhaseParamsCard
        width: 420
        height: 220
        anchors.top: mainInputColumn.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        visible: showThreePhaseParams

        GridLayout {
            anchors.fill: parent
            anchors.margins: 12
            columns: 6
            rowSpacing: 8
            columnSpacing: 8

            Text {
                text: ""
                Layout.preferredWidth: 40
            }

            Text {
                text: "A相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "B相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: "C相"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电压"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: threePhaseVoltageA.toFixed(1) + " V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: threePhaseVoltageB.toFixed(1) + " V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: threePhaseVoltageC.toFixed(1) + " V"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "电流"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: threePhaseCurrentA.toFixed(1) + " A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: threePhaseCurrentB.toFixed(1) + " A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: theme.textColor
                opacity: 0.3
            }

            Text {
                text: threePhaseCurrentC.toFixed(1) + " A"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
            }

            Text {
                text: "频率"
                color: theme.textColor
                font.pixelSize: 12
                Layout.preferredWidth: 40
            }

            Text {
                text: threePhaseFrequency.toFixed(1) + " Hz"
                color: theme.textColor
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.columnSpan: 5
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
