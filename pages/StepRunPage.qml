// ============================================================================//
// 分步运行页面 (StepRunPage.qml)
// 功能：实现设备的分步运行控制，支持多步骤配置、顺序执行和循环运行
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    id: window

    background: Rectangle {
        color: "transparent"
    }

    // ========================================================================//
    // 属性定义
    // ========================================================================//

    // 引用首页对象，用于访问首页的属性和方法
    // 类型：var
    // 用途：获取首页的modbusManager和控制首页的stepRunActive状态
    property var homePage
    
    // 串口开关状态
    // 类型：bool
    // 用途：监测串口开关是否打开，用于控制按钮的启用状态
    property bool isSerialPortOpen: homePage ? homePage.serialPortOpen : false
    
    // 风机开关状态
    // 类型：bool
    // 用途：监测风机开关是否打开，用于控制按钮的启用状态
    property bool isFanSwitchOn: homePage ? homePage.fanSwitchOn : false
    
    // 风机实际状态
    // 类型：bool
    // 用途：监测风机的实际运行状态，用于控制按钮的启用状态
    property bool isFanRunning: homePage && homePage.modbusManagerInstance ? (homePage.modbusManagerInstance.hasFanStateData && homePage.modbusManagerInstance.fanState === 1) : false
    
    // 风机是否就绪
    // 类型：bool
    // 用途：判断风机是否就绪，用于控制按钮的启用状态
    property bool isFanReady: homePage && homePage.modbusManagerInstance ? homePage.modbusManagerInstance.hasFanStateData : false
    
    // 操作条件是否满足
    // 类型：bool
    // 用途：判断所有操作条件是否满足，用于控制按钮和内容的可见性
    property bool operationConditionsMet: isSerialPortOpen && isFanSwitchOn && isFanReady && isFanRunning && !(homePage && homePage.emergencyStopped)
    
    // 当前操作状态信息
    // 类型：string
    // 用途：根据当前条件显示相应的提示信息
    property string operationStatusMessage: {
        if (!isSerialPortOpen) {
            return "请在主页中打开串口"
        } else if (homePage && homePage.emergencyStopped) {
            return "请在主页中关闭并重新开启风机开关"
        } else if (!isFanSwitchOn) {
            return "请在主页中打开风机开关"
        } else if (!isFanReady) {
            return "等待串口连接中..."
        } else if (!isFanRunning) {
            return "风机未运行，请检查风机状态"
        }
        return ""
    }

    // Modbus管理器，用于向设备发送功率设置命令
    // 类型：function
    // 用途：通过Modbus协议与设备通信，设置各通道电流值
    function getModbusManager() {
        console.log("【分步运行】获取Modbus管理器 - homePage对象:", homePage)
        if (homePage) {
            console.log("【分步运行】homePage对象存在，类型:", typeof homePage)
            console.log("【分步运行】homePage是否有modbusManagerInstance属性:", homePage.hasOwnProperty("modbusManagerInstance"))
            console.log("【分步运行】homePage.modbusManagerInstance值:", homePage.modbusManagerInstance)
            if (homePage.modbusManagerInstance) {
                console.log("【分步运行】成功获取到modbusManager实例")
            } else {
                console.log("【分步运行】homePage.modbusManagerInstance为null或undefined")
            }
            return homePage.modbusManagerInstance
        } else {
            console.log("【分步运行】homePage对象为null，无法获取modbusManager")
            return null
        }
    }

    // 分步运行模式状态，与首页功率设置互斥
    // 类型：bool
    // 用途：标识当前是否处于分步运行模式，用于禁用首页的功率控制
    property bool stepRunActive: homePage ? homePage.stepRunActive : false
    
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
    
    // 三相电参数定时器
    Timer {
        id: threePhaseParamsTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (showThreePhaseParams) {
                if (homePage && homePage.generatorTestManagerInstance) {
                    homePage.generatorTestManagerInstance.requestThreePhaseParams()
                }
            } else {
                threePhaseParamsTimer.stop()
            }
        }
    }
    
    // 连接到generatorTestManager的数据回调
    Component.onCompleted: {
        if (homePage && homePage.generatorTestManagerInstance) {
            homePage.generatorTestManagerInstance.threePhaseParamsUpdated.connect(function() {
                threePhaseVoltageA = homePage.generatorTestManagerInstance.getThreePhaseVoltageA()
                threePhaseVoltageB = homePage.generatorTestManagerInstance.getThreePhaseVoltageB()
                threePhaseVoltageC = homePage.generatorTestManagerInstance.getThreePhaseVoltageC()
                threePhaseCurrentA = homePage.generatorTestManagerInstance.getThreePhaseCurrentA()
                threePhaseCurrentB = homePage.generatorTestManagerInstance.getThreePhaseCurrentB()
                threePhaseCurrentC = homePage.generatorTestManagerInstance.getThreePhaseCurrentC()
                threePhaseFrequency = homePage.generatorTestManagerInstance.getThreePhaseFrequency()
            })
        }
    }

    // 最大步骤数量限制
    // 类型：int
    // 用途：限制用户可添加的步骤数量，防止界面过于复杂
    property int maxSteps: 10

    // 当前正在执行的步骤索引，-1表示未运行
    // 类型：int
    // 用途：跟踪当前执行的步骤位置，用于状态显示和步骤切换
    property int currentStepIndex: -1

    // 是否正在执行分步运行
    // 类型：bool
    // 用途：控制UI元素的启用状态和定时器的运行
    property bool isRunning: false

    // 是否正在循环运行
    // 类型：bool
    // 用途：标识是否启用循环运行模式，决定步骤执行完毕后的行为
    property bool isLooping: false

    // 当前步骤剩余时间（秒）
    // 类型：int
    // 用途：显示当前步骤的剩余执行时间
    property int remainingTime: 0

    // 累计已运行时间（秒）
    // 类型：int
    // 用途：记录整个分步运行过程的总时长
    property int totalElapsedTime: 0
    
    // 设备状态监测定时器
    // 功能：定期检查串口和风机状态，确保按钮启用状态与设备状态同步
    Timer {
        id: deviceStatusCheckTimer
        interval: 500 // 每500毫秒检查一次
        repeat: true
        running: true
        


        
        onTriggered: {
            if (homePage) {
                // 检查串口开关状态
                var currentSerialState = homePage.serialPortOpen
                if (isSerialPortOpen !== currentSerialState) {
                    console.log("【分步运行】串口开关状态更新:", currentSerialState)
                    isSerialPortOpen = currentSerialState
                }
                
                // 检查风机开关状态
                var currentFanSwitchState = homePage.fanSwitchOn
                if (isFanSwitchOn !== currentFanSwitchState) {
                    console.log("【分步运行】风机开关状态更新:", currentFanSwitchState)
                    isFanSwitchOn = currentFanSwitchState
                }
                
                // 检查风机实际状态
                var currentFanState = homePage.modbusManagerInstance ? (homePage.modbusManagerInstance.hasFanStateData && homePage.modbusManagerInstance.fanState === 1) : false
                if (isFanRunning !== currentFanState) {
                    console.log("【分步运行】风机实际状态更新:", currentFanState)
                    isFanRunning = currentFanState
                }
                
                // 检查风机是否就绪
                var currentFanReadyState = homePage.modbusManagerInstance ? homePage.modbusManagerInstance.hasFanStateData : false
                if (isFanReady !== currentFanReadyState) {
                    console.log("【分步运行】风机就绪状态更新:", currentFanReadyState)
                    isFanReady = currentFanReadyState
                }
                

            }
        }
    }

    // ========================================================================//
    // 数据模型
    // ========================================================================//

    // 步骤列表模型，存储每个步骤的配置信息
    // 字段说明：
    // - stepName: 步骤名称，格式为"第X步"
    // - power: 1路功率值（单位：KW）
    // - duration: 运行时间（单位：秒）
    ListModel {
        id: stepModel
        // 默认包含一个步骤
        ListElement {
            stepName: "第1步"      // 步骤名称
            power: 0            // 1路功率(KW)
            duration: 1            // 运行时间(秒)
        }
    }

    // ========================================================================//
    // 步骤管理函数
    // ========================================================================//

    // 添加新步骤
    // 功能：在步骤列表末尾添加一个新的默认步骤
    // 条件：当前步骤数量未达到最大限制（maxSteps）
    // 默认值：功率为0KW，运行时间为1秒
    function addStep() {
        if (stepModel.count < maxSteps) {
            stepModel.append({
                stepName: "第" + (stepModel.count + 1) + "步",
                power: 0,
                duration: 1
            })
        }
    }

    // 删除指定索引的步骤
    // 功能：删除指定位置的步骤，并更新剩余步骤的名称
    // 参数：index - 要删除的步骤索引
    // 条件：步骤数量大于1且索引有效
    function removeStep(index) {
        if (stepModel.count > 1 && index >= 0 && index < stepModel.count) {
            stepModel.remove(index)
            // 更新剩余步骤的名称，确保步骤编号连续
            for (var i = 0; i < stepModel.count; i++) {
                stepModel.set(i, { stepName: "第" + (i + 1) + "步" })
            }
        }
    }

    // ========================================================================//
    // 运行控制
    // ========================================================================//

    // 定时器，用于定时更新剩余时间和切换步骤
    // 配置：
    // - interval: 1000ms（1秒）
    // - repeat: true（重复执行）
    // - running: 与isRunning状态同步
    // 功能：每秒更新一次剩余时间，时间到则切换到下一个步骤
    Timer {
        id: runTimer
        interval: 1000          // 定时周期1秒
        repeat: true            // 重复执行
        running: isRunning      // 与运行状态同步
        onTriggered: {
            // 如果还有剩余时间
            if (remainingTime > 0) {
                remainingTime--      // 剩余时间减1
                totalElapsedTime++    // 累计时间加1
            } else {
                // 当前步骤时间已到，切换到下一个步骤
                if (currentStepIndex < stepModel.count - 1) {
                    currentStepIndex++
                    startStep(currentStepIndex)
                } else {
                    // 所有步骤执行完毕
                    if (isLooping) {
                        // 循环模式：从第一个步骤重新开始
                        currentStepIndex = 0
                        startStep(0)
                    } else {
                        // 普通模式：停止运行
                        stopRun()
                    }
                }
            }
        }
    }

    // 开始执行指定索引的步骤
    // 功能：设置当前步骤的剩余时间，并向设备发送电流设置
    // 参数：index - 要执行的步骤索引
    // 条件：索引有效（0 <= index < stepModel.count）
    function startStep(index) {
        if (index >= 0 && index < stepModel.count) {
            var step = stepModel.get(index)
            remainingTime = step.duration    // 设置当前步骤的剩余时间
            // 向设备写入功率设置
            var modbusManager = getModbusManager()
            console.log("modbusManager:", modbusManager)
            console.log("homePage:", homePage)
            if (modbusManager) {
                console.log("准备写入功率值: 1路=" + step.power + "KW")
                modbusManager.writeCurrent(step.power, 1)
            } else {
                console.log("modbusManager为null，无法写入功率值")
            }
            console.log("分步运行 - " + step.stepName + ": 1路=" + step.power + "KW, 时长=" + step.duration + "s")
        }
    }

    // 开始分步运行
    // 功能：启动分步运行流程，执行第一个步骤
    // 步骤：
    // 1. 检查步骤列表是否为空
    // 2. 设置首页的stepRunActive状态为true
    // 3. 更新运行状态变量
    // 4. 执行第一个步骤
    // 5. 启动定时器
    function startRun() {
        if (stepModel.count === 0) return

        // 设置首页的分步运行模式状态，禁用首页的功率控制
        if (homePage) {
            homePage.stepRunActive = true
        }
        // 更新运行状态
        isRunning = true
        currentStepIndex = 0
        totalElapsedTime = 0
        // 开始执行第一个步骤
        startStep(0)
        // 启动定时器
        runTimer.running = true
    }

    // 停止分步运行
    // 功能：停止当前运行的分步流程，恢复初始状态
    // 步骤：
    // 1. 更新运行状态变量
    // 2. 停止定时器
    // 3. 恢复首页的stepRunActive状态
    // 4. 发送卸载命令到设备
    function stopRun() {
        isRunning = false
        isLooping = false
        currentStepIndex = -1
        remainingTime = 0
        // 停止定时器
        runTimer.running = false
        // 取消首页的分步运行模式状态
        if (homePage) {
            homePage.stepRunActive = false
        }
        // 发送卸载命令
        var modbusManager = getModbusManager()
        if (modbusManager) {
            modbusManager.writeUnload()
        }
        console.log("分步运行停止")
    }

    // 循环分步运行
    // 功能：启动循环模式的分步运行流程
    // 步骤：
    // 1. 检查步骤列表是否为空
    // 2. 设置首页的stepRunActive状态为true
    // 3. 更新运行状态变量，启用循环模式
    // 4. 执行第一个步骤
    // 5. 启动定时器
    function loopRun() {
        if (stepModel.count === 0) return

        // 设置首页的分步运行模式状态，禁用首页的功率控制
        if (homePage) {
            homePage.stepRunActive = true
        }
        // 更新运行状态
        isRunning = true
        isLooping = true
        currentStepIndex = 0
        totalElapsedTime = 0
        // 开始执行第一个步骤
        startStep(0)
        // 启动定时器
        runTimer.running = true
    }

    // 退出页面时的清理操作
    // 功能：在页面退出时停止运行并恢复状态
    // 步骤：
    // 1. 如果正在运行，停止运行
    // 2. 恢复stepRunActive状态
    function onExitPage() {
        if (isRunning) {
            stopRun()
        }
        stepRunActive = false
    }

    // 页面销毁时自动调用清理函数
    // 功能：确保在页面销毁时执行清理操作，防止资源泄漏
    Component.onDestruction: {
        onExitPage()
    }

    // ========================================================================//
    // 界面布局
    // ========================================================================//
    
    // 操作条件提示信息
    // 类型：Text
    // 功能：当操作条件不满足时显示提示信息
    // 说明：仅在操作条件不满足时显示
    Text {
        anchors.centerIn: parent
        text: operationStatusMessage
        color: theme.textColor
        font.pixelSize: 30
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !operationConditionsMet
    }

    // 左侧面板 - 步骤配置区域
    // 功能：用于配置和管理分步运行的各个步骤参数
    // 布局：垂直布局，包含标题、步骤卡片滚动区域和添加步骤按钮
    Rectangle {
        id: leftPanel
        width: 480
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.topMargin: 24
        anchors.bottomMargin: 8
        color: "transparent"
        visible: operationConditionsMet

        ColumnLayout {
            anchors.fill: parent
            spacing: 32

            // 标题
            Text {
                text: "分步运行配置"
                color: theme.textColor
                font.pixelSize: 20
                font.bold: true
                Layout.topMargin: 8
            }

            // 步骤卡片滚动区域
            // 功能：显示和管理多个步骤配置卡片
            // 布局：2列网格布局，支持滚动
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 步骤卡片网格布局（2列）
                GridLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 16
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 12
                    width: leftPanel.width - 48

                    // 步骤列表 Repeater
                    // 功能：根据stepModel动态生成步骤卡片
                    Repeater {
                        model: stepModel
                        delegate: ECard {
                            // 卡片宽度 = (面板宽度 - 边距 - 列间距) / 2
                            width: (leftPanel.width - 48 - 12) / 2
                            height: 210
                            padding: 12

                            // 当前步骤在模型中的索引
                            property int stepIndex: index

                            ColumnLayout {
                                spacing: 8

                                // 步骤名称行
                                // 功能：显示步骤名称和删除按钮
                                RowLayout {
                                    Text {
                                        text: stepName
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    // 删除按钮
                                    // 功能：删除当前步骤
                                    // 可见条件：步骤数量大于1且未运行
                                    EButton {
                                        text: "删除"
                                        size: "xs"
                                        containerColor: theme.isDark ? "#EF5350" : "#F44336"
                                        textColor: "white"
                                        visible: stepModel.count > 1 && !isRunning   // 运行时隐藏
                                        onClicked: removeStep(stepIndex)
                                    }
                                }

                                // 参数输入区域（纵向排列）
                                // 功能：输入和显示步骤的电流和时间参数
                                ColumnLayout {
                                    spacing: 10

                                    // 1路功率输入行
                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: "请输入功率/KW"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 90
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning    // 运行时禁用输入
                                            text: model.power
                                            onTextChanged: {
                                                // 只允许输入数字和小数点
                                                var text = this.text
                                                var filtered = ""
                                                var dotFound = false
                                                var decimalCount = 0
                                                for (var i = 0; i < text.length; i++) {
                                                    var ch = text.charAt(i)
                                                    if (ch >= '0' && ch <= '9') {
                                                        if (!dotFound || decimalCount < 1) {
                                                            filtered += ch
                                                            if (dotFound) decimalCount++
                                                        }
                                                    } else if (ch === '.' && !dotFound) {
                                                        filtered += ch
                                                        dotFound = true
                                                    }
                                                }
                                                if (filtered !== text) {
                                                    this.text = filtered
                                                    return
                                                }
                                                
                                                var value = parseFloat(filtered)
                                                if (!isNaN(value)) {
                                                    // 检查小数位是否为0.3、0.5、0.8
                                                    var decimalPart = (value % 1).toFixed(1);
                                                    if (decimalPart !== "0.0" && decimalPart !== "0.3" && decimalPart !== "0.5" && decimalPart !== "0.8") {
                                                        // 找到最近的0.3、0.5或0.8
                                                        var integerPart = Math.floor(value);
                                                        var possibleValues = [integerPart, integerPart + 0.3, integerPart + 0.5, integerPart + 0.8, integerPart + 1];
                                                        var closestValue = possibleValues.reduce(function(prev, curr) {
                                                            return (Math.abs(curr - value) < Math.abs(prev - value) ? curr : prev);
                                                        });
                                                        value = closestValue;
                                                        this.text = closestValue.toString();
                                                    }
                                                    // 根据风机状态指示灯限制最大值
                                                var maxPower = homePage && homePage.modbusManagerInstance ? 
                                                    ((homePage.modbusManagerInstance.hasFanStateData2 && homePage.modbusManagerInstance.fanState2 === 1) ? 400.8 : 200.8) : 200.8
                                                    if (value > maxPower) {
                                                        value = maxPower
                                                        this.text = maxPower.toString()
                                                    }
                                                    stepModel.set(stepIndex, { power: value })
                                                } else if (filtered === "") {
                                                    stepModel.set(stepIndex, { power: 0 })
                                                }
                                            }
                                        }
                                    }

                                    // 功率输入提示
                                    RowLayout {
                                        Text {
                                            text: "范围：0~" + (homePage && homePage.modbusManagerInstance ? ((homePage.modbusManagerInstance.hasFanStateData2 && homePage.modbusManagerInstance.fanState2 === 1) ? "400.8" : "200.8") : "200.8")
                                            color: theme.textColor
                                            font.pixelSize: 10
                                            Layout.preferredWidth: 160
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    // 运行时间输入行
                                    RowLayout {
                                        Text {
                                            text: "运行时间/秒"
                                            color: theme.textColor
                                            font.pixelSize: 12
                                            Layout.preferredWidth: 80
                                        }
                                        EInput {
                                            placeholderText: ""
                                            Layout.preferredWidth: 80
                                            height: 48
                                            radius: 18
                                            enabled: !isRunning
                                            text: model.duration
                                            onTextChanged: {
                                                // 只允许输入数字
                                                var cleanText = text.replace(/[^0-9]/g, "")
                                                if (cleanText !== text) {
                                                    text = cleanText
                                                }
                                                var value = parseInt(cleanText)
                                                if (!isNaN(value) && value > 0) {
                                                    stepModel.set(stepIndex, { duration: value })
                                                } else if (cleanText === "") {
                                                    stepModel.set(stepIndex, { duration: 0 })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 添加底部空间，确保滚动条可以滚动到最下方
                    Item {
                        width: 1
                        height: 100
                    }
                }
            }
        }

        // 添加步骤按钮（居中显示）
        // 功能：添加新的步骤配置
        // 可见条件：步骤数量未达到最大值且未运行
        RowLayout {
            Layout.topMargin: 32
            width: leftPanel.width - 48

            Item {
                Layout.fillWidth: true
            }

            EButton {
                text: "添加步骤"
                size: "s"
                containerColor: theme.secondaryColor
                textColor: theme.textColor
                iconCharacter: "\uf067"
                iconColor: theme.textColor
                visible: stepModel.count < maxSteps      // 未达到最大数量时显示
                enabled: !isRunning                     // 运行时禁用
                Layout.leftMargin: 100
                onClicked: addStep()
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    // 右侧面板 - 运行控制和状态显示
    // 功能：控制分步运行的启动/停止/循环，显示运行状态信息
    // 布局：垂直布局，包含控制按钮和状态显示卡片
    Rectangle {
        id: rightPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftPanel.right
        anchors.right: parent.right
        anchors.margins: 16
        color: "transparent"
        visible: operationConditionsMet

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            // 开始/停止按钮行
            // 功能：提供运行控制按钮
            RowLayout {
                spacing: 16

                // 开始运行按钮
                // 功能：启动普通模式的分步运行
                // 启用条件：未运行状态、串口开关打开、风机开关打开、风机就绪且运行
                EButton {
                    id: startButton
                    text: "开始运行"
                    size: "s"
                    containerColor: theme.isDark ? "#66BB6A" : "#4CAF50"
                    textColor: "white"
                    iconCharacter: "\uf04b"
                    iconColor: "white"
                    enabled: !isRunning && isSerialPortOpen && isFanSwitchOn && isFanReady && isFanRunning
                    onClicked: startRun()
                    onEnabledChanged: {
                        console.log("【分步运行】开始按钮启用状态变化:", enabled)
                        console.log("  条件检查:")
                        console.log("    isRunning:", isRunning)
                        console.log("    isSerialPortOpen:", isSerialPortOpen)
                        console.log("    isFanSwitchOn:", isFanSwitchOn)
                        console.log("    isFanReady:", isFanReady)
                        console.log("    isFanRunning:", isFanRunning)
                    }
                }

                // 停止按钮
                // 功能：停止当前运行的分步流程
                // 启用条件：正在运行状态
                EButton {
                    id: stopButton
                    text: "停止"
                    size: "s"
                    containerColor: theme.isDark ? "#EF5350" : "#F44336"
                    textColor: "white"
                    iconCharacter: "\uf04d"
                    iconColor: "white"
                    enabled: isRunning
                    onClicked: {
                        stopRun()
                    }
                }

                // 循环运行按钮
                // 功能：启动循环模式的分步运行
                // 启用条件：未运行状态、串口开关打开、风机开关打开、风机就绪且运行
                EButton {
                    id: loopButton
                    text: "循环运行"
                    size: "s"
                    containerColor: theme.isDark ? "#42A5F5" : "#2196F3"
                    textColor: "white"
                    iconCharacter: "\uf01e"
                    iconColor: "white"
                    enabled: !isRunning && isSerialPortOpen && isFanSwitchOn && isFanReady && isFanRunning
                    onClicked: {
                        loopRun()
                    }
                }
            }

            // 运行状态卡片
            // 功能：显示当前运行状态，包括当前步骤、剩余时间和累计时间
            EHoverCard {
                height: 80
                Layout.fillWidth: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        spacing: 20

                        // 当前步骤显示
                        ColumnLayout {
                            Text {
                                text: "当前步骤"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: isRunning ? (currentStepIndex >= 0 ? stepModel.get(currentStepIndex).stepName : "已完成") : "未运行"
                                color: isRunning ? (theme.isDark ? "#66BB6A" : "#4CAF50") : theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        // 剩余时间显示
                        ColumnLayout {
                            Text {
                                text: "剩余时间"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: isRunning ? remainingTime + " 秒" : "--"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }

                        // 累计时间显示
                        ColumnLayout {
                            Text {
                                text: "累计时间"
                                color: theme.textColor
                                font.pixelSize: 12
                            }
                            Text {
                                text: totalElapsedTime + " 秒"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // 三相电气参数按钮
            EButton {
                id: threePhaseParamsButton
                text: showThreePhaseParams ? "关闭三相参数" : "三相电气参数"
                size: "s"
                containerColor: showThreePhaseParams ? (theme.isDark ? "#FF9800" : "#FF9800") : theme.secondaryColor
                textColor: showThreePhaseParams ? "white" : theme.textColor
                shadowEnabled: true
                Layout.topMargin: 40
                Layout.fillWidth: true
                enabled: homePage && homePage.serialPortOpen
                onClicked: {
                    showThreePhaseParams = !showThreePhaseParams
                    if (showThreePhaseParams) {
                        threePhaseParamsTimer.start()
                        if (homePage && homePage.generatorTestManagerInstance) {
                            homePage.generatorTestManagerInstance.requestThreePhaseParams()
                        }
                    } else {
                        threePhaseParamsTimer.stop()
                    }
                }
            }

            // 三相电参数卡片
            EHoverCard {
                id: threePhaseParamsCard
                height: 220
                Layout.topMargin: 16
                Layout.fillWidth: true
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

            // 填充项，保持布局位置
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
