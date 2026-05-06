import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as LabsPlatform
import QtCore
import EvolveUI

/**
 * GeneratorTestPage - 发电机测试页面
 * 
 * 功能描述：
 * 该页面用于发电机性能测试，包括以下测试功能：
 * - 波动实验：测量电压和频率的波动率
 * - 突加实验：突加负载时测量电压和频率的瞬态特性
 * - 突卸实验：突卸负载时测量电压和频率的瞬态特性
 * - 谐波实验：测量电压波形畸变率和谐波含量
 * - 电压整定：测量电压整定范围
 * - 频率整定：测量频率整定范围
 * - 一键测试：自动完成所有测试并导出报表
 * 
 * 测试负载范围：0% → 25% → 50% → 75% → 100% → 110% → 100% → 75% → 50% → 25% → 0%
 */
Page {
    id: window

    // 页面背景 - 透明背景
    background: Rectangle {
        color: "transparent"
    }

    // 主页引用 - 用于访问主页的组件和状态
    property var homePage

    // 串口状态 - 从主页获取串口打开状态
    property bool isSerialPortOpen: homePage ? homePage.serialPortOpen : false
    // 调试模式状态 - 从主页获取调试模式状态
    property bool isDebugMode: homePage ? homePage.debugMode : false

    // 操作条件是否满足 - 调试模式或串口打开时可操作
    property bool operationConditionsMet: isDebugMode || isSerialPortOpen

    // 操作状态提示信息 - 根据当前状态显示提示信息
    property string operationStatusMessage: {
        if (isDebugMode) {
            return "调试模式已启用"
        }
        if (!isSerialPortOpen) {
            return "请在主页中打开串口"
        }
        return ""
    }

    // 接收到的数据 - 用于显示串口接收到的原始数据
    property string receivedData: ""

    // 最后发送的命令 - 记录最近一次发送的十六进制命令
    property string lastSentCommand: ""

    // 数据缓冲区 - 用于处理分批接收的数据
    property string dataBuffer: ""
    // 期望数据长度 - 用于校验接收数据的完整性
    property int expectedDataLength: 0

    // 导出对话框显示状态
    property bool showExportDialog: false
    // 选中的导出格式 - txt或pdf
    property string selectedExportFormat: "txt"
    // 参数输入对话框显示状态
    property bool showParameterInput: false
    // 报表预览对话框显示状态
    property bool showReportPreview: false
    // 报表配置对话框显示状态
    property bool showReportConfigDialog: false

    // 报表参数配置 - 定义报表各章节和列的显示/隐藏
    property int reportConfigRefreshCounter: 0
    property var reportConfig: [
        { id: "techSpec", name: "技术规格", enabled: true },
        { id: "testItems", name: "试验项目", enabled: false },
        { id: "staticParams", name: "测量电压和额定频率的稳态参数", enabled: true },
        { id: "testResults", name: "测试结果", enabled: true },
        { id: "transientTest", name: "瞬态测试", enabled: true },
        { id: "conclusion", name: "实验结论", enabled: true },
        { id: "load", name: "负载", enabled: true, section: "staticParams" },
        { id: "power", name: "功率", enabled: true, section: "staticParams" },
        { id: "ua", name: "UA", enabled: true, section: "staticParams" },
        { id: "ub", name: "UB", enabled: true, section: "staticParams" },
        { id: "uc", name: "UC", enabled: true, section: "staticParams" },
        { id: "ia", name: "IA", enabled: true, section: "staticParams" },
        { id: "ib", name: "IB", enabled: true, section: "staticParams" },
        { id: "ic", name: "IC", enabled: true, section: "staticParams" },
        { id: "pf", name: "稳态功率因数", enabled: true, section: "staticParams" },
        { id: "freq", name: "频率F1", enabled: true, section: "staticParams" },
        { id: "steadyFreqBand", name: "稳态频率带", enabled: false, section: "staticParams" },
        { id: "freqRangeUp", name: "频率整定范围上升", enabled: false, section: "staticParams" },
        { id: "freqRangeDown", name: "频率整定范围下降", enabled: false, section: "staticParams" },
        { id: "voltageDistortionRate", name: "电压波形畸变率", enabled: false, section: "testResults" },
        { id: "steadyVoltageDeviation", name: "稳态电压偏差", enabled: false, section: "testResults" },
        { id: "steadyFrequencyBand", name: "稳态频率带", enabled: false, section: "testResults" },
        { id: "steadyFrequencyDeviation", name: "频率降", enabled: false, section: "testResults" },
        { id: "voltageSettingRange", name: "电压整定范围", enabled: true, section: "testResults" },
        { id: "suddenAddVoltageDeviation", name: "突加电压瞬态电压偏差", enabled: true, section: "transientTest" },
        { id: "suddenAddVoltageStableTime", name: "突加电压稳定时间", enabled: true, section: "transientTest" },
        { id: "suddenAddFrequencyDeviation", name: "突加频率瞬态频率偏差", enabled: true, section: "transientTest" },
        { id: "suddenAddFrequencyStableTime", name: "突加频率稳定时间", enabled: true, section: "transientTest" },
        { id: "suddenLoadVoltageDeviation", name: "突卸电压瞬态电压偏差", enabled: true, section: "transientTest" },
        { id: "suddenLoadVoltageStableTime", name: "突卸电压稳定时间", enabled: true, section: "transientTest" },
        { id: "suddenLoadFrequencyDeviation", name: "突卸频率瞬态频率偏差", enabled: true, section: "transientTest" },
        { id: "suddenLoadFrequencyStableTime", name: "突卸频率稳定时间", enabled: true, section: "transientTest" }
    ]

    /**
     * 检查报表章节是否启用
     * @param id 章节ID
     * @returns 是否启用
     */
    function isReportSectionEnabled(id) {
        for (var i = 0; i < reportConfig.length; i++) {
            if (reportConfig[i].id === id && !reportConfig[i].section) {
                return reportConfig[i].enabled
            }
        }
        return true
    }

    /**
     * 检查报表列是否启用
     * @param id 列ID
     * @returns 是否启用
     */
    function isReportColumnEnabled(id) {
        for (var i = 0; i < reportConfig.length; i++) {
            if (reportConfig[i].id === id) {
                return reportConfig[i].enabled
            }
        }
        return true
    }
    
    /**
     * 重置报表配置到默认值
     */
    function resetReportConfig() {
        var defaultConfig = [
            { id: "techSpec", name: "技术规格", enabled: true },
            { id: "testItems", name: "试验项目", enabled: false },
            { id: "staticParams", name: "测量电压和额定频率的稳态参数", enabled: true },
            { id: "testResults", name: "测试结果", enabled: true },
            { id: "transientTest", name: "瞬态测试", enabled: true },
            { id: "conclusion", name: "实验结论", enabled: true },
            { id: "load", name: "负载", enabled: true, section: "staticParams" },
            { id: "power", name: "功率", enabled: true, section: "staticParams" },
            { id: "ua", name: "UA", enabled: true, section: "staticParams" },
            { id: "ub", name: "UB", enabled: true, section: "staticParams" },
            { id: "uc", name: "UC", enabled: true, section: "staticParams" },
            { id: "ia", name: "IA", enabled: true, section: "staticParams" },
            { id: "ib", name: "IB", enabled: true, section: "staticParams" },
            { id: "ic", name: "IC", enabled: true, section: "staticParams" },
            { id: "pf", name: "稳态功率因数", enabled: true, section: "staticParams" },
            { id: "freq", name: "频率F1", enabled: true, section: "staticParams" },
            { id: "steadyFreqBand", name: "稳态频率带", enabled: false, section: "staticParams" },
            { id: "freqRangeUp", name: "频率整定范围上升", enabled: false, section: "staticParams" },
            { id: "freqRangeDown", name: "频率整定范围下降", enabled: false, section: "staticParams" },
            { id: "voltageDistortionRate", name: "电压波形畸变率", enabled: false, section: "testResults" },
            { id: "steadyVoltageDeviation", name: "稳态电压偏差", enabled: false, section: "testResults" },
            { id: "steadyFrequencyBand", name: "稳态频率带", enabled: false, section: "testResults" },
            { id: "steadyFrequencyDeviation", name: "频率降", enabled: false, section: "testResults" },
            { id: "voltageSettingRange", name: "电压整定范围", enabled: true, section: "testResults" },
            { id: "suddenAddVoltageDeviation", name: "突加电压瞬态电压偏差", enabled: true, section: "transientTest" },
            { id: "suddenAddVoltageStableTime", name: "突加电压稳定时间", enabled: true, section: "transientTest" },
            { id: "suddenAddFrequencyDeviation", name: "突加频率瞬态频率偏差", enabled: true, section: "transientTest" },
            { id: "suddenAddFrequencyStableTime", name: "突加频率稳定时间", enabled: true, section: "transientTest" },
            { id: "suddenLoadVoltageDeviation", name: "突卸电压瞬态电压偏差", enabled: true, section: "transientTest" },
            { id: "suddenLoadVoltageStableTime", name: "突卸电压稳定时间", enabled: true, section: "transientTest" },
            { id: "suddenLoadFrequencyDeviation", name: "突卸频率瞬态频率偏差", enabled: true, section: "transientTest" },
            { id: "suddenLoadFrequencyStableTime", name: "突卸频率稳定时间", enabled: true, section: "transientTest" }
        ]
        
        // 复制默认配置到 reportConfig 并刷新显示
        reportConfig = defaultConfig
        reportConfigRefreshCounter++
    }

    // 等待对话框相关属性
    property bool showWaitingDialog: false           // 是否显示等待对话框
    property string waitingDialogTitle: ""            // 等待对话框标题
    property int waitingDialogSeconds: 0              // 等待总秒数
    property int waitingDialogRemaining: 0            // 剩余等待秒数

    // 波动实验相关属性
    property bool waveTestInProgress: false           // 波动实验是否进行中
    property bool waveTestDataRequested: false        // 波动实验数据是否已请求
    property int waveTestRetryCount: 0                // 波动实验重试次数
    property string waveTestStatus: ""                 // 波动实验状态信息
    property int waveTestStep: 0                       // 0=初始, 1=请求数据

    property string waveTestRefPhase: ""              // 波动实验参考相
    property double waveTestVoltageMax: 0             // 波动实验电压最大值
    property double waveTestVoltageMin: 0             // 波动实验电压最小值
    property double waveTestFrequencyMax: 0           // 波动实验频率最大值
    property double waveTestFrequencyMin: 0           // 波动实验频率最小值

    // 参数发送相关属性
    property bool parameterSendInProgress: false      // 参数发送是否进行中
    property int currentSendCommandIndex: 0           // 当前发送命令索引
    property var sendCommandList: []                   // 待发送命令列表
    property bool showParameterSendResult: false       // 是否显示参数发送结果
    property string parameterSendResultMessage: ""     // 参数发送结果消息

    // 突加实验相关属性
    property bool suddenAddTestInProgress: false       // 突加实验是否进行中
    property bool suddenAddTestDataRequested: false    // 突加实验数据是否已请求
    property int suddenAddTestRetryCount: 0            // 突加实验重试次数
    property string suddenAddTestStatus: ""             // 突加实验状态信息
    property int suddenAddTestStep: 0                   // 0=初始, 1=请求电压数据, 2=请求频率数据, 3=请求电流数据
    property int suddenAddTestPhase: 0                  // 0=初始, 1=发送卸载后等待, 2=突加实验已启动, 3=发送功率

    // 突卸实验相关属性
    property bool suddenLoadTestInProgress: false       // 突卸实验是否进行中
    property bool suddenLoadTestDataRequested: false    // 突卸实验数据是否已请求
    property int suddenLoadTestRetryCount: 0            // 突卸实验重试次数
    property string suddenLoadTestStatus: ""             // 突卸实验状态信息
    property int suddenLoadTestStep: 0                   // 0=初始, 1=请求电压数据, 2=请求频率数据, 3=请求电流数据
    property int suddenLoadTestPhase: 0                  // 0=初始, 1=发送功率后等待, 2=突卸实验已启动, 3=发送卸载

    // 谐波实验相关属性
    property bool harmonicTestInProgress: false       // 谐波实验是否进行中
    property bool harmonicTestDataRequested: false    // 谐波实验数据是否已请求
    property int harmonicTestRetryCount: 0            // 谐波实验重试次数
    property string harmonicTestStatus: ""             // 谐波实验状态信息
    property int harmonicTestStep: 0                   // 0=初始, 1=等待启动响应, 2=等待60秒, 3=请求波形数据, 4=请求谐波数据, 5=请求退出
    property int harmonicTestStepFlag: 0               // 0=初始, 1=已请求启动, 2=已请求波形, 3=已请求谐波, 4=已请求退出
    
    property string harmonicTestRefPhase: ""          // 谐波实验参考相
    property var harmonicTestVoltageWaveform: []      // 128个电压波形采样点
    property var harmonicTestCurrentWaveform: []      // 128个电流波形采样点
    property var harmonicTestVoltageHarmonics: []     // 电压谐波数据，索引0为基波，1-50为各次谐波
    property var harmonicTestCurrentHarmonics: []     // 电流谐波数据，索引0为基波，1-50为各次谐波
    property double harmonicTestVoltageDistortionRate: 0  // 电压波形畸变率 Ku%

    // 电压整定相关属性
    property bool voltageCalibrationInProgress: false  // 电压整定是否进行中
    property string voltageCalibrationStatus: ""        // 电压整定状态信息

    // 频率整定相关属性
    property bool frequencyCalibrationInProgress: false // 频率整定是否进行中
    property string frequencyCalibrationStatus: ""       // 频率整定状态信息
    
    property string voltageCalibrationRefPhase: ""     // 电压整定参考相
    property double voltageCalibrationUmax: 0          // 电压整定最大值
    property double voltageCalibrationUmin: 0          // 电压整定最小值
    property string frequencyCalibrationRefPhase: ""   // 频率整定参考相
    property double frequencyCalibrationFmax: 0        // 频率整定最大值
    property double frequencyCalibrationFmin: 0        // 频率整定最小值
    
    // 校准测试通用属性
    property bool calibrationTestInProgress: false     // 校准测试是否进行中
    property bool calibrationTestDataRequested: false  // 校准测试数据是否已请求
    property int calibrationTestRetryCount: 0          // 校准测试重试次数
    property string currentCalibrationType: ""         // "voltage", "frequency", ""
    property int calibrationTestStep: 0                 // 0=初始, 1=已启动, 2=已请求数据

    // 录波测试相关属性
    property bool waveformRecordTestInProgress: false  // 录波测试是否进行中
    property string waveformRecordTestStatus: ""        // 录波测试状态信息

    // 标签页相关属性 - 定义11个负载点的测试数据
    property var tabLabels: ["0%", "25%", "50%", "75%", "100%", "110%", "100%", "75%", "50%", "25%", "0%"]
    property int currentTabIndex: 0                     // 当前选中的标签页索引

    /**
     * 标签页数据存储 - 为11个负载点分别存储所有测试数据
     * 每个负载点包含：波动实验、突加实验、突卸实验、谐波实验、电压/频率整定、静态三相参数等数据
     */
    property var tabDataStorage: {
        var storage = []
        for (var i = 0; i < 11; i++) {
            storage.push({
                waveTestRefPhase: "",
                waveTestVoltageMax: 0,
                waveTestVoltageMin: 0,
                waveTestFrequencyMax: 0,
                waveTestFrequencyMin: 0,
                waveTestStatus: "",
                suddenAddTestRefPhase: "",
                suddenAddTestTolerance: 0,
                suddenAddTestStableTime: 0,
                suddenAddTestExtremeValue: 0,
                suddenAddTestMultiplier: 0,
                suddenAddFrequencyTolerance: 0,
                suddenAddFrequencyStableTime: 0,
                suddenAddFrequencyExtremeValue: 0,
                suddenAddRatedNoLoadFrequency: 0,
                suddenAddCurrentTolerance: 0,
                suddenAddCurrentStableTime: 0,
                suddenAddCurrentExtremeValue: 0,
                suddenAddCurrentMultiplier: 0,
                suddenAddTestStatus: "",
                suddenLoadTestRefPhase: "",
                suddenLoadTestTolerance: 0,
                suddenLoadTestStableTime: 0,
                suddenLoadTestExtremeValue: 0,
                suddenLoadTestMultiplier: 0,
                suddenLoadFrequencyTolerance: 0,
                suddenLoadFrequencyStableTime: 0,
                suddenLoadFrequencyExtremeValue: 0,
                suddenLoadRatedNoLoadFrequency: 0,
                suddenLoadCurrentTolerance: 0,
                suddenLoadCurrentStableTime: 0,
                suddenLoadCurrentExtremeValue: 0,
                suddenLoadCurrentMultiplier: 0,
                suddenLoadTestStatus: "",
                harmonicTestRefPhase: "",
                harmonicTestVoltageWaveform: [],
                harmonicTestCurrentWaveform: [],
                harmonicTestStatus: "",
                voltageCalibrationRefPhase: "",
                voltageCalibrationUmax: 0,
                voltageCalibrationUmin: 0,
                frequencyCalibrationRefPhase: "",
                frequencyCalibrationFmax: 0,
                frequencyCalibrationFmin: 0,
                voltageCalibrationStatus: "",
                frequencyCalibrationStatus: "",
                staticThreePhaseParamsReceived: false,
                staticVoltageA: 0,
                staticVoltageB: 0,
                staticVoltageC: 0,
                staticCurrentA: 0,
                staticCurrentB: 0,
                staticCurrentC: 0,
                staticTotalPower: 0,
                staticPowerFactor: 0,
                staticFrequency: 0,
                testDataHistory: {
                    "wave": null,
                    "suddenAdd": null,
                    "suddenLoad": null,
                    "harmonic": null
                }
            })
        }
        return storage
    }

    // 当前测试类型 - "wave", "suddenAdd", "suddenLoad", "harmonic", "history", "voltageCalibration", "frequencyCalibration", "waveformRecord", ""
    property string currentTestType: ""
    // 测试数据历史 - 存储当前标签的测试结果
    property var testDataHistory: {
        "wave": null,
        "suddenAdd": null,
        "suddenLoad": null,
        "harmonic": null
    }

    // 一键测试相关属性
    property bool autoTestInProgress: false              // 全标签一键测试是否进行中
    property bool singleTabAutoTestInProgress: false     // 单标签一键测试是否进行中
    property int autoTestStep: 0                          // 一键测试步骤
    property int autoTestCurrentTab: 0                    // 一键测试当前标签页
    property int autoTestStepInCurrentTab: 0              // 当前标签内的测试步骤
    property bool autoTestStaticParamsRequested: false    // 静态参数是否已请求
    property bool isStaticParamsStep: false               // 是否在静态参数步骤
    property int autoTestRetryCount: 0                    // 一键测试重试次数
    property bool autoTestWaitingForRetry: false          // 是否等待重试
    property string autoTestRetryType: ""                 // 重试类型
    property string autoTestStatus: ""                     // 一键测试状态信息
    
    // ============================================
    // 一键测试设置项 - 选择、排序和等待时间配置
    // ============================================
    property bool showTestConfigDialog: false              // 是否显示测试配置对话框
    property int testConfigRefreshCounter: 0               // 测试配置刷新计数器，用于强制刷新Repeater
    
    /**
     * 功率标签切换等待时间（分钟）
     * 功能：设置一键测试在不同功率标签之间切换时的等待时间
     * 默认值：3分钟
     * 范围：0-10分钟
     * 用途：根据设备响应速度调整标签切换等待时间，确保设备稳定后再进行下一标签的测试
     */
    property int powerTabSwitchWaitTime: 3                 
    
    /**
     * 可用测试列表
     * 每个测试项包含：
     * - id: 测试唯一标识
     * - name: 测试显示名称
     * - enabled: 是否默认启用
     * - order: 执行顺序
     * 
     * 默认启用的测试：静态三相参数、电压整定、突加实验、突卸实验
     * 默认禁用的测试：波动实验、谐波实验、频率整定
     */
    property var availableTests: [                          
        { id: "static", name: "静态三相参数", enabled: true, order: 1 },
        { id: "wave", name: "波动实验", enabled: false, order: 2 },
        { id: "harmonic", name: "谐波实验", enabled: false, order: 3 },
        { id: "voltageCalibration", name: "电压整定", enabled: true, order: 4 },
        { id: "frequencyCalibration", name: "频率整定", enabled: false, order: 5 },
        { id: "suddenAdd", name: "突加实验", enabled: true, order: 6 },
        { id: "suddenLoad", name: "突卸实验", enabled: true, order: 7 }
    ]
    
    // 三相参数显示相关属性
    property bool showThreePhaseParams: false             // 是否显示三相参数
    property bool threePhaseParamsReading: false         // 三相参数是否正在读取
    property double threePhaseVoltageA: 0                 // 实时A相电压
    property double threePhaseVoltageB: 0                 // 实时B相电压
    property double threePhaseVoltageC: 0                 // 实时C相电压
    property double threePhaseCurrentA: 0                 // 实时A相电流
    property double threePhaseCurrentB: 0                 // 实时B相电流
    property double threePhaseCurrentC: 0                 // 实时C相电流
    property double threePhaseFrequency: 0                // 实时频率
    
    // 静态三相参数（保存到报表用）
    property bool staticThreePhaseParamsReceived: false   // 静态三相参数是否已接收
    property double staticVoltageA: 0                      // 静态A相电压
    property double staticVoltageB: 0                      // 静态B相电压
    property double staticVoltageC: 0                      // 静态C相电压
    property double staticCurrentA: 0                      // 静态A相电流
    property double staticCurrentB: 0                      // 静态B相电流
    property double staticCurrentC: 0                      // 静态C相电流
    property double staticTotalPower: 0                    // 静态总有功功率
    property double staticPowerFactor: 0                   // 静态功率因数
    property double staticFrequency: 0                      // 静态频率

    // Modbus管理器 - 用于控制负载
    property var modbusManager: null

    // 突加实验详细数据
    property string suddenAddTestRefPhase: ""             // 突加实验参考相
    property double suddenAddTestTolerance: 0              // 突加电压容差
    property int suddenAddTestStableTime: 0                // 突加电压稳定时间
    property int suddenAddTestExtremeValue: 0              // 突加电压极值
    property double suddenAddTestMultiplier: 0             // 突加电压倍率

    property double suddenAddFrequencyTolerance: 0          // 突加频率容差
    property int suddenAddFrequencyStableTime: 0            // 突加频率稳定时间
    property int suddenAddFrequencyExtremeValue: 0          // 突加频率极值
    property double suddenAddRatedNoLoadFrequency: 0        // 突加额定空载频率

    property double suddenAddCurrentTolerance: 0            // 突加电流容差
    property int suddenAddCurrentStableTime: 0              // 突加电流稳定时间
    property int suddenAddCurrentExtremeValue: 0            // 突加电流极值
    property double suddenAddCurrentMultiplier: 0           // 突加电流倍率

    // 突卸实验详细数据
    property string suddenLoadTestRefPhase: ""             // 突卸实验参考相
    property double suddenLoadTestTolerance: 0              // 突卸电压容差
    property int suddenLoadTestStableTime: 0                // 突卸电压稳定时间
    property int suddenLoadTestExtremeValue: 0              // 突卸电压极值
    property double suddenLoadTestMultiplier: 0             // 突卸电压倍率

    property double suddenLoadFrequencyTolerance: 0          // 突卸频率容差
    property int suddenLoadFrequencyStableTime: 0            // 突卸频率稳定时间
    property int suddenLoadFrequencyExtremeValue: 0          // 突卸频率极值
    property double suddenLoadRatedNoLoadFrequency: 0        // 突卸额定空载频率

    property double suddenLoadCurrentTolerance: 0            // 突卸电流容差
    property int suddenLoadCurrentStableTime: 0              // 突卸电流稳定时间
    property int suddenLoadCurrentExtremeValue: 0            // 突卸电流极值
    property double suddenLoadCurrentMultiplier: 0           // 突卸电流倍率

    // 参数设置临时变量 - 用于参数编辑对话框
    property double tempRatedVoltage: paramSettings.ratedVoltage
    property double tempVoltageMultiplier: paramSettings.voltageMultiplier
    property double tempCurrentMultiplier: paramSettings.currentMultiplier
    property double tempPowerFactor: paramSettings.powerFactor
    property double tempRatedPower: paramSettings.ratedPower
    property double tempRatedFrequency: paramSettings.ratedFrequency
    property double tempNoLoadFrequency: paramSettings.noLoadFrequency
    property double tempFullLoadFrequency: paramSettings.fullLoadFrequency
    property string tempPrimeMover: paramSettings.primeMover
    property string tempGovernor: paramSettings.governor
    property string tempExcitationMode: paramSettings.excitationMode
    property string tempAmbientTemperature: paramSettings.ambientTemperature
    property string tempRelativeHumidity: paramSettings.relativeHumidity
    property string tempAtmosphericPressure: paramSettings.atmosphericPressure
    property string tempSurveyor: paramSettings.surveyor
    property string tempVerifier: paramSettings.verifier
    property int tempReferencePhase: paramSettings.referencePhase

    // 设备参数相关属性 - 从设备读取的参数
    property bool deviceParamsRequested: false             // 设备参数是否已请求
    property bool deviceParamsReceived: false              // 设备参数是否已接收
    property double devicePtRatio: 0                        // 设备PT比
    property double deviceCtRatio: 0                        // 设备CT比
    property double deviceVoltageSteady: 0                  // 设备稳态电压
    property double deviceCurrentSteady: 0                  // 设备稳态电流
    property double deviceFrequencySteady: 0                // 设备稳态频率
    property double deviceRatedVoltage: 0                   // 设备额定电压
    property double deviceRatedCurrent: 0                   // 设备额定电流
    property double deviceRatedFrequency: 0                 // 设备额定频率
    property double deviceFrequencyDrop: 0                  // 设备频率降
    property bool deviceFrequencyDropReceived: false         // 设备频率降是否已接收
    property string pendingExportFormat: ""                  // 待处理的导出格式

    /**
     * 参数设置组件 - 存储发电机测试的基本参数
     */
    Settings {
        id: paramSettings
        property double ratedVoltage: 400                    // 额定电压(V)
        property double voltageMultiplier: 1                  // 电压倍率
        property double currentMultiplier: 1                  // 电流倍率
        property double powerFactor: 1                         // 功率因数
        property double ratedPower: 100                        // 额定功率(kW)
        property double ratedFrequency: 50                      // 额定频率(Hz)
        property double noLoadFrequency: 50                    // 空载频率(Hz)
        property double fullLoadFrequency: 50                  // 满载频率(Hz)
        property int referencePhase: 0                          // 0=A相, 1=B相, 2=C相
        property string primeMover: ""                          // 原动机型号
        property string governor: ""                            // 调速器型号
        property string excitationMode: ""                      // 励磁方式
        property string ambientTemperature: ""                  // 环境温度
        property string relativeHumidity: ""                    // 相对湿度
        property string atmosphericPressure: ""                 // 大气压力
        property string surveyor: ""                             // 测试人员
        property string verifier: "1"                           // 检验人员
    }

    /**
     * 重置临时参数 - 将临时参数重置为当前保存的参数值
     */
    function resetTempParameters() {
        tempRatedVoltage = paramSettings.ratedVoltage
        tempVoltageMultiplier = paramSettings.voltageMultiplier
        tempCurrentMultiplier = paramSettings.currentMultiplier
        tempPowerFactor = paramSettings.powerFactor
        tempRatedPower = paramSettings.ratedPower
        tempRatedFrequency = paramSettings.ratedFrequency
        tempNoLoadFrequency = paramSettings.noLoadFrequency
        tempFullLoadFrequency = paramSettings.fullLoadFrequency
        tempReferencePhase = paramSettings.referencePhase
        tempPrimeMover = paramSettings.primeMover
        tempGovernor = paramSettings.governor
        tempExcitationMode = paramSettings.excitationMode
        tempAmbientTemperature = paramSettings.ambientTemperature
        tempRelativeHumidity = paramSettings.relativeHumidity
        tempAtmosphericPressure = paramSettings.atmosphericPressure
        tempSurveyor = paramSettings.surveyor
        tempVerifier = paramSettings.verifier
    }

    // ============================================
    // 一键测试设置项相关函数
    // ============================================
    
    /**
     * 获取已启用的测试列表
     * @returns 已启用并按顺序排序的测试列表
     */
    function getEnabledTests() {
        var enabled = availableTests.filter(function(test) { return test.enabled })
        enabled.sort(function(a, b) { return a.order - b.order })
        return enabled
    }

    /**
     * 获取排序后的测试列表
     * @returns 按顺序排序的所有测试列表
     */
    function getSortedTests() {
        var sorted = availableTests.slice()
        sorted.sort(function(a, b) { return a.order - b.order })
        return sorted
    }

    /**
     * 上移测试项（索引方式）
     * @param index 测试项索引
     */
    function moveTestUp(index) {
        if (index <= 0) return
        var temp = availableTests[index].order
        availableTests[index].order = availableTests[index - 1].order
        availableTests[index - 1].order = temp
    }

    /**
     * 下移测试项（索引方式）
     * @param index 测试项索引
     */
    function moveTestDown(index) {
        if (index >= availableTests.length - 1) return
        var temp = availableTests[index].order
        availableTests[index].order = availableTests[index + 1].order
        availableTests[index + 1].order = temp
    }

    /**
     * 切换测试项启用状态（索引方式）
     * @param index 测试项索引
     */
    function toggleTestEnabled(index) {
        availableTests[index].enabled = !availableTests[index].enabled
    }

    /**
     * 切换测试项启用状态（ID方式）
     * @param testId 测试项ID
     */
    function toggleTestEnabledById(testId) {
        for (var i = 0; i < availableTests.length; i++) {
            if (availableTests[i].id === testId) {
                availableTests[i].enabled = !availableTests[i].enabled
                testConfigRefreshCounter++
                return
            }
        }
    }

    /**
     * 上移测试项（ID方式）
     * @param testId 测试项ID
     */
    function moveTestUpById(testId) {
        for (var i = 0; i < availableTests.length; i++) {
            if (availableTests[i].id === testId && i > 0) {
                // 交换 order
                var temp = availableTests[i].order
                availableTests[i].order = availableTests[i - 1].order
                availableTests[i - 1].order = temp
                testConfigRefreshCounter++
                return
            }
        }
    }

    /**
     * 下移测试项（ID方式）
     * @param testId 测试项ID
     */
    function moveTestDownById(testId) {
        for (var i = 0; i < availableTests.length; i++) {
            if (availableTests[i].id === testId && i < availableTests.length - 1) {
                // 交换 order
                var temp = availableTests[i].order
                availableTests[i].order = availableTests[i + 1].order
                availableTests[i + 1].order = temp
                testConfigRefreshCounter++
                return
            }
        }
    }

    /**
     * 全选/全不选测试项
     * @param enabled 是否启用
     */
    function selectAllTests(enabled) {
        for (var i = 0; i < availableTests.length; i++) {
            availableTests[i].enabled = enabled
        }
        testConfigRefreshCounter++
    }

    /**
     * 重置测试配置到默认值
     */
    function resetTests() {
        availableTests = [
            { id: "static", name: "静态三相参数", enabled: true, order: 1 },
            { id: "wave", name: "波动实验", enabled: true, order: 2 },
            { id: "harmonic", name: "谐波实验", enabled: true, order: 3 },
            { id: "voltageCalibration", name: "电压整定", enabled: true, order: 4 },
            { id: "frequencyCalibration", name: "频率整定", enabled: true, order: 5 },
            { id: "suddenAdd", name: "突加实验", enabled: true, order: 6 },
            { id: "suddenLoad", name: "突卸实验", enabled: true, order: 7 }
        ]
        testConfigRefreshCounter++
    }

    // ============================================
    // 标签页数据管理函数
    // ============================================
    
    /**
     * 保存当前标签页的数据到存储
     */
    function saveCurrentTabData() {
        if (currentTabIndex >= 0 && currentTabIndex < tabDataStorage.length) {
            tabDataStorage[currentTabIndex].waveTestRefPhase = waveTestRefPhase
            tabDataStorage[currentTabIndex].waveTestVoltageMax = waveTestVoltageMax
            tabDataStorage[currentTabIndex].waveTestVoltageMin = waveTestVoltageMin
            tabDataStorage[currentTabIndex].waveTestFrequencyMax = waveTestFrequencyMax
            tabDataStorage[currentTabIndex].waveTestFrequencyMin = waveTestFrequencyMin
            tabDataStorage[currentTabIndex].waveTestStatus = waveTestStatus
            tabDataStorage[currentTabIndex].suddenAddTestRefPhase = suddenAddTestRefPhase
            tabDataStorage[currentTabIndex].suddenAddTestTolerance = suddenAddTestTolerance
            tabDataStorage[currentTabIndex].suddenAddTestStableTime = suddenAddTestStableTime
            tabDataStorage[currentTabIndex].suddenAddTestExtremeValue = suddenAddTestExtremeValue
            tabDataStorage[currentTabIndex].suddenAddTestMultiplier = suddenAddTestMultiplier
            tabDataStorage[currentTabIndex].suddenAddFrequencyTolerance = suddenAddFrequencyTolerance
            tabDataStorage[currentTabIndex].suddenAddFrequencyStableTime = suddenAddFrequencyStableTime
            tabDataStorage[currentTabIndex].suddenAddFrequencyExtremeValue = suddenAddFrequencyExtremeValue
            tabDataStorage[currentTabIndex].suddenAddRatedNoLoadFrequency = suddenAddRatedNoLoadFrequency
            tabDataStorage[currentTabIndex].suddenAddCurrentTolerance = suddenAddCurrentTolerance
            tabDataStorage[currentTabIndex].suddenAddCurrentStableTime = suddenAddCurrentStableTime
            tabDataStorage[currentTabIndex].suddenAddCurrentExtremeValue = suddenAddCurrentExtremeValue
            tabDataStorage[currentTabIndex].suddenAddCurrentMultiplier = suddenAddCurrentMultiplier
            tabDataStorage[currentTabIndex].suddenAddTestStatus = suddenAddTestStatus
            tabDataStorage[currentTabIndex].suddenLoadTestRefPhase = suddenLoadTestRefPhase
            tabDataStorage[currentTabIndex].suddenLoadTestTolerance = suddenLoadTestTolerance
            tabDataStorage[currentTabIndex].suddenLoadTestStableTime = suddenLoadTestStableTime
            tabDataStorage[currentTabIndex].suddenLoadTestExtremeValue = suddenLoadTestExtremeValue
            tabDataStorage[currentTabIndex].suddenLoadTestMultiplier = suddenLoadTestMultiplier
            tabDataStorage[currentTabIndex].suddenLoadFrequencyTolerance = suddenLoadFrequencyTolerance
            tabDataStorage[currentTabIndex].suddenLoadFrequencyStableTime = suddenLoadFrequencyStableTime
            tabDataStorage[currentTabIndex].suddenLoadFrequencyExtremeValue = suddenLoadFrequencyExtremeValue
            tabDataStorage[currentTabIndex].suddenLoadRatedNoLoadFrequency = suddenLoadRatedNoLoadFrequency
            tabDataStorage[currentTabIndex].suddenLoadCurrentTolerance = suddenLoadCurrentTolerance
            tabDataStorage[currentTabIndex].suddenLoadCurrentStableTime = suddenLoadCurrentStableTime
            tabDataStorage[currentTabIndex].suddenLoadCurrentExtremeValue = suddenLoadCurrentExtremeValue
            tabDataStorage[currentTabIndex].suddenLoadCurrentMultiplier = suddenLoadCurrentMultiplier
            tabDataStorage[currentTabIndex].suddenLoadTestStatus = suddenLoadTestStatus
            tabDataStorage[currentTabIndex].harmonicTestRefPhase = harmonicTestRefPhase
            tabDataStorage[currentTabIndex].harmonicTestVoltageWaveform = harmonicTestVoltageWaveform
            tabDataStorage[currentTabIndex].harmonicTestCurrentWaveform = harmonicTestCurrentWaveform
            tabDataStorage[currentTabIndex].harmonicTestStatus = harmonicTestStatus
            tabDataStorage[currentTabIndex].voltageCalibrationRefPhase = voltageCalibrationRefPhase
            tabDataStorage[currentTabIndex].voltageCalibrationUmax = voltageCalibrationUmax
            tabDataStorage[currentTabIndex].voltageCalibrationUmin = voltageCalibrationUmin
            tabDataStorage[currentTabIndex].frequencyCalibrationRefPhase = frequencyCalibrationRefPhase
            tabDataStorage[currentTabIndex].frequencyCalibrationFmax = frequencyCalibrationFmax
            tabDataStorage[currentTabIndex].frequencyCalibrationFmin = frequencyCalibrationFmin
            tabDataStorage[currentTabIndex].voltageCalibrationStatus = voltageCalibrationStatus
            tabDataStorage[currentTabIndex].frequencyCalibrationStatus = frequencyCalibrationStatus
            tabDataStorage[currentTabIndex].staticThreePhaseParamsReceived = staticThreePhaseParamsReceived
            tabDataStorage[currentTabIndex].staticVoltageA = staticVoltageA
            tabDataStorage[currentTabIndex].staticVoltageB = staticVoltageB
            tabDataStorage[currentTabIndex].staticVoltageC = staticVoltageC
            tabDataStorage[currentTabIndex].staticCurrentA = staticCurrentA
            tabDataStorage[currentTabIndex].staticCurrentB = staticCurrentB
            tabDataStorage[currentTabIndex].staticCurrentC = staticCurrentC
            tabDataStorage[currentTabIndex].staticTotalPower = staticTotalPower
            tabDataStorage[currentTabIndex].staticPowerFactor = staticPowerFactor
            tabDataStorage[currentTabIndex].staticFrequency = staticFrequency
            tabDataStorage[currentTabIndex].testDataHistory = testDataHistory
        }
    }

    /**
     * 从存储加载指定标签页的数据
     * @param tabIndex 标签页索引
     */
    function loadTabData(tabIndex) {
        if (tabIndex >= 0 && tabIndex < tabDataStorage.length) {
            waveTestRefPhase = tabDataStorage[tabIndex].waveTestRefPhase
            waveTestVoltageMax = tabDataStorage[tabIndex].waveTestVoltageMax
            waveTestVoltageMin = tabDataStorage[tabIndex].waveTestVoltageMin
            waveTestFrequencyMax = tabDataStorage[tabIndex].waveTestFrequencyMax
            waveTestFrequencyMin = tabDataStorage[tabIndex].waveTestFrequencyMin
            waveTestStatus = tabDataStorage[tabIndex].waveTestStatus
            suddenAddTestRefPhase = tabDataStorage[tabIndex].suddenAddTestRefPhase
            suddenAddTestTolerance = tabDataStorage[tabIndex].suddenAddTestTolerance
            suddenAddTestStableTime = tabDataStorage[tabIndex].suddenAddTestStableTime
            suddenAddTestExtremeValue = tabDataStorage[tabIndex].suddenAddTestExtremeValue
            suddenAddTestMultiplier = tabDataStorage[tabIndex].suddenAddTestMultiplier
            suddenAddFrequencyTolerance = tabDataStorage[tabIndex].suddenAddFrequencyTolerance
            suddenAddFrequencyStableTime = tabDataStorage[tabIndex].suddenAddFrequencyStableTime
            suddenAddFrequencyExtremeValue = tabDataStorage[tabIndex].suddenAddFrequencyExtremeValue
            suddenAddRatedNoLoadFrequency = tabDataStorage[tabIndex].suddenAddRatedNoLoadFrequency
            suddenAddCurrentTolerance = tabDataStorage[tabIndex].suddenAddCurrentTolerance
            suddenAddCurrentStableTime = tabDataStorage[tabIndex].suddenAddCurrentStableTime
            suddenAddCurrentExtremeValue = tabDataStorage[tabIndex].suddenAddCurrentExtremeValue
            suddenAddCurrentMultiplier = tabDataStorage[tabIndex].suddenAddCurrentMultiplier
            suddenAddTestStatus = tabDataStorage[tabIndex].suddenAddTestStatus
            suddenLoadTestRefPhase = tabDataStorage[tabIndex].suddenLoadTestRefPhase
            suddenLoadTestTolerance = tabDataStorage[tabIndex].suddenLoadTestTolerance
            suddenLoadTestStableTime = tabDataStorage[tabIndex].suddenLoadTestStableTime
            suddenLoadTestExtremeValue = tabDataStorage[tabIndex].suddenLoadTestExtremeValue
            suddenLoadTestMultiplier = tabDataStorage[tabIndex].suddenLoadTestMultiplier
            suddenLoadFrequencyTolerance = tabDataStorage[tabIndex].suddenLoadFrequencyTolerance
            suddenLoadFrequencyStableTime = tabDataStorage[tabIndex].suddenLoadFrequencyStableTime
            suddenLoadFrequencyExtremeValue = tabDataStorage[tabIndex].suddenLoadFrequencyExtremeValue
            suddenLoadRatedNoLoadFrequency = tabDataStorage[tabIndex].suddenLoadRatedNoLoadFrequency
            suddenLoadCurrentTolerance = tabDataStorage[tabIndex].suddenLoadCurrentTolerance
            suddenLoadCurrentStableTime = tabDataStorage[tabIndex].suddenLoadCurrentStableTime
            suddenLoadCurrentExtremeValue = tabDataStorage[tabIndex].suddenLoadCurrentExtremeValue
            suddenLoadCurrentMultiplier = tabDataStorage[tabIndex].suddenLoadCurrentMultiplier
            suddenLoadTestStatus = tabDataStorage[tabIndex].suddenLoadTestStatus
            harmonicTestRefPhase = tabDataStorage[tabIndex].harmonicTestRefPhase
            harmonicTestVoltageWaveform = tabDataStorage[tabIndex].harmonicTestVoltageWaveform
            harmonicTestCurrentWaveform = tabDataStorage[tabIndex].harmonicTestCurrentWaveform
            harmonicTestStatus = tabDataStorage[tabIndex].harmonicTestStatus
            voltageCalibrationRefPhase = tabDataStorage[tabIndex].voltageCalibrationRefPhase
            voltageCalibrationUmax = tabDataStorage[tabIndex].voltageCalibrationUmax
            voltageCalibrationUmin = tabDataStorage[tabIndex].voltageCalibrationUmin
            frequencyCalibrationRefPhase = tabDataStorage[tabIndex].frequencyCalibrationRefPhase
            frequencyCalibrationFmax = tabDataStorage[tabIndex].frequencyCalibrationFmax
            frequencyCalibrationFmin = tabDataStorage[tabIndex].frequencyCalibrationFmin
            voltageCalibrationStatus = tabDataStorage[tabIndex].voltageCalibrationStatus
            frequencyCalibrationStatus = tabDataStorage[tabIndex].frequencyCalibrationStatus
            staticThreePhaseParamsReceived = tabDataStorage[tabIndex].staticThreePhaseParamsReceived
            staticVoltageA = tabDataStorage[tabIndex].staticVoltageA
            staticVoltageB = tabDataStorage[tabIndex].staticVoltageB
            staticVoltageC = tabDataStorage[tabIndex].staticVoltageC
            staticCurrentA = tabDataStorage[tabIndex].staticCurrentA
            staticCurrentB = tabDataStorage[tabIndex].staticCurrentB
            staticCurrentC = tabDataStorage[tabIndex].staticCurrentC
            staticTotalPower = tabDataStorage[tabIndex].staticTotalPower
            staticPowerFactor = tabDataStorage[tabIndex].staticPowerFactor
            staticFrequency = tabDataStorage[tabIndex].staticFrequency
            testDataHistory = tabDataStorage[tabIndex].testDataHistory
        }
    }

    /**
     * 切换标签页
     * @param newTabIndex 新标签页索引
     */
    function switchTab(newTabIndex) {
        if (newTabIndex === currentTabIndex) return
        saveCurrentTabData()         // 保存当前标签页数据
        currentTabIndex = newTabIndex
        loadTabData(newTabIndex)     // 加载新标签页数据
        sendPowerByCurrentTab()      // 根据新标签页发送相应功率
    }

    /**
     * 保存参数 - 将临时参数保存到Settings
     */
    function saveParameters() {
        paramSettings.ratedVoltage = tempRatedVoltage
        paramSettings.voltageMultiplier = tempVoltageMultiplier
        paramSettings.currentMultiplier = tempCurrentMultiplier
        paramSettings.powerFactor = tempPowerFactor
        paramSettings.ratedPower = tempRatedPower
        paramSettings.ratedFrequency = tempRatedFrequency
        paramSettings.noLoadFrequency = tempNoLoadFrequency
        paramSettings.fullLoadFrequency = tempFullLoadFrequency
        paramSettings.referencePhase = tempReferencePhase
        paramSettings.primeMover = tempPrimeMover
        paramSettings.governor = tempGovernor
        paramSettings.excitationMode = tempExcitationMode
        paramSettings.ambientTemperature = tempAmbientTemperature
        paramSettings.relativeHumidity = tempRelativeHumidity
        paramSettings.atmosphericPressure = tempAtmosphericPressure
        paramSettings.surveyor = tempSurveyor
        paramSettings.verifier = tempVerifier
        showParameterInput = false
    }

    // ============================================
    // IEEE754浮点数转换函数
    // ============================================
    
    /**
     * 将浮点数转换为IEEE754十六进制字符串（大端序）
     * @param value 浮点数
     * @returns IEEE754十六进制字符串
     */
    function parseFloatToIEEE754(value) {
        var buffer = new ArrayBuffer(4)
        var view = new DataView(buffer)
        view.setFloat32(0, value, false)
        var hexBytes = []
        for (var i = 3; i >= 0; i--) {
            var byteValue = view.getUint8(i)
            var hex = byteValue.toString(16).toUpperCase()
            if (hex.length === 1) {
                hex = "0" + hex
            }
            hexBytes.push(hex)
        }
        return hexBytes.join(" ")
    }

    /**
     * 将IEEE754十六进制字符串解析为浮点数（小端序）
     * @param hexString 十六进制字符串
     * @returns 解析后的浮点数
     */
    function parseIEEE754Float(hexString) {
        var bytes = hexString.split(" ")
        var byteArray = []
        for (var i = 0; i < bytes.length; i++) {
            byteArray.push(parseInt(bytes[i], 16))
        }
        var buffer = new ArrayBuffer(4)
        var view = new DataView(buffer)
        view.setUint8(0, byteArray[0])
        view.setUint8(1, byteArray[1])
        view.setUint8(2, byteArray[2])
        view.setUint8(3, byteArray[3])
        var val1 = view.getFloat32(0, true)
        var val2 = view.getFloat32(0, false)
        console.log("解析字节:", hexString, "小端序:", val1, "大端序:", val2)
        return val1
    }

    /**
     * 解析设备参数响应
     * @param hexData 十六进制数据
     * @returns 是否解析成功
     */
    function parseDeviceParamsResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        console.log("接收到设备参数响应，总字节数:", bytes.length)
        console.log("完整数据:", hexData)
        if (bytes.length !== 36) {
            console.log("设备参数响应长度错误，需要36字节，实际:", bytes.length)
            return false
        }
        
        // 验证帧头和命令码
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "4A") {
            console.log("设备参数响应格式错误，帧头或命令码不正确")
            return false
        }
        
        // 计算校验和
        var checksum = 0
        for (var i = 0; i < 35; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[35], 16)
        console.log("校验码计算:", checksum.toString(16), "接收:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("设备参数校验码错误 - 计算值:", checksum.toString(16), ", 接收值:", receivedChecksum.toString(16))
            return false
        }
        
        // 解析各个参数
        console.log("--- 开始解析各个参数 ---")
        devicePtRatio = parseIEEE754Float(bytes[3] + " " + bytes[4] + " " + bytes[5] + " " + bytes[6])
        deviceCtRatio = parseIEEE754Float(bytes[7] + " " + bytes[8] + " " + bytes[9] + " " + bytes[10])
        deviceVoltageSteady = parseIEEE754Float(bytes[11] + " " + bytes[12] + " " + bytes[13] + " " + bytes[14])
        deviceCurrentSteady = parseIEEE754Float(bytes[15] + " " + bytes[16] + " " + bytes[17] + " " + bytes[18])
        deviceFrequencySteady = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22])
        deviceRatedVoltage = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22])
        deviceRatedCurrent = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26])
        deviceRatedFrequency = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26])
        
        console.log("设备参数读取成功 - 额定电压:", deviceRatedVoltage, ", 额定频率:", deviceRatedFrequency)
        return true
    }
    
    // 解析三相参数实时数据响应
    // hexData: 16进制数据字符串，包含32字节
    function parseThreePhaseParamsResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        // 验证数据长度是否为32字节
        if (bytes.length !== 32) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(39)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "39") {
            return false
        }
        
        // 计算并验证校验和
        var checksum = 0
        for (var i = 0; i < 31; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[31], 16)
        if (checksum !== receivedChecksum) {
            return false
        }
        
        // 解析各相电压、电流和频率（IEEE754浮点数格式）
        threePhaseVoltageA = parseIEEE754Float(bytes[3] + " " + bytes[4] + " " + bytes[5] + " " + bytes[6])
        threePhaseVoltageB = parseIEEE754Float(bytes[7] + " " + bytes[8] + " " + bytes[9] + " " + bytes[10])
        threePhaseVoltageC = parseIEEE754Float(bytes[11] + " " + bytes[12] + " " + bytes[13] + " " + bytes[14])
        threePhaseCurrentA = parseIEEE754Float(bytes[15] + " " + bytes[16] + " " + bytes[17] + " " + bytes[18])
        threePhaseCurrentB = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22])
        threePhaseCurrentC = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26])
        threePhaseFrequency = parseIEEE754Float(bytes[27] + " " + bytes[28] + " " + bytes[29] + " " + bytes[30])
        
        return true
    }
    
    // 解析静态三相参数响应
    // hexData: 16进制数据字符串，包含44字节
    function parseStaticThreePhaseParamsResponse(hexData) {
        console.log("parseStaticThreePhaseParamsResponse 被调用，数据:", hexData)
        var bytes = hexData.trim().split(" ")
        console.log("字节数:", bytes.length)
        // 验证数据长度是否为44字节
        if (bytes.length !== 44) {
            console.log("parseStaticThreePhaseParamsResponse 失败：字节数不对，需要44，实际:", bytes.length)
            return false
        }
        
        // 验证帧头(AA 01)和命令码(34)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "34") {
            console.log("parseStaticThreePhaseParamsResponse 失败：帧头或命令码不对")
            return false
        }
        
        // 计算并验证校验和
        var checksum = 0
        for (var i = 0; i < 43; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[43], 16)
        console.log("校验码 - 计算值:", checksum.toString(16), "接收值:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("parseStaticThreePhaseParamsResponse 失败：校验码不对")
            return false
        }
        
        // 解析静态参数（IEEE754浮点数格式）
        staticVoltageA = parseIEEE754Float(bytes[3] + " " + bytes[4] + " " + bytes[5] + " " + bytes[6])
        staticVoltageB = parseIEEE754Float(bytes[7] + " " + bytes[8] + " " + bytes[9] + " " + bytes[10])
        staticVoltageC = parseIEEE754Float(bytes[11] + " " + bytes[12] + " " + bytes[13] + " " + bytes[14])
        staticCurrentA = parseIEEE754Float(bytes[15] + " " + bytes[16] + " " + bytes[17] + " " + bytes[18])
        staticCurrentB = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22])
        staticCurrentC = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26])
        staticTotalPower = parseIEEE754Float(bytes[27] + " " + bytes[28] + " " + bytes[29] + " " + bytes[30])
        staticPowerFactor = parseIEEE754Float(bytes[31] + " " + bytes[32] + " " + bytes[33] + " " + bytes[34])
        staticFrequency = parseIEEE754Float(bytes[35] + " " + bytes[36] + " " + bytes[37] + " " + bytes[38])
        staticThreePhaseParamsReceived = true
        
        // 保存数据到当前标签页
        saveCurrentTabData()
        
        // 如果是在一键测试中，并且是静态参数步骤，提前关闭提示框并继续下一步
        if (autoTestInProgress && isStaticParamsStep) {
            hideWaitingPopup()
            autoTestNextStepTimer.stop()
            isStaticParamsStep = false
            onAutoTestStepCompleted()
        }
        
        // 重新启动三相参数定时器
        if (showThreePhaseParams && !threePhaseParamsTimer.running) {
            threePhaseParamsTimer.start()
        }
        
        return true
    }
    
    // 请求三相参数实时数据
    function requestThreePhaseParams() {
        // 如果有任何测试正在进行，则不请求
        if (waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || 
            harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || 
            frequencyCalibrationInProgress) {
            return
        }
        // 发送命令：55 01 39 8F
        sendHexMessage("55 01 39 8F")
    }

    // 请求设备参数
    function requestDeviceParams() {
        console.log("请求设备参数...")
        deviceParamsRequested = true
        deviceParamsReceived = false
        // 发送命令：55 01 4A A0
        sendHexMessage("55 01 4A A0")
    }

    // 计算校验和
    // hexString: 16进制字符串，空格分隔
    function calculateChecksum(hexString) {
        var bytes = hexString.trim().split(" ")
        var sum = 0
        // 累加所有字节值
        for (var i = 0; i < bytes.length; i++) {
            sum += parseInt(bytes[i], 16)
        }
        // 取模256
        var checksum = sum % 256
        // 转换为两位16进制字符串
        var hex = checksum.toString(16).toUpperCase()
        if (hex.length === 1) {
            hex = "0" + hex
        }
        return hex
    }

    // 发送参数设置命令
    // commandCode: 命令码
    // valueHex: 参数值的16进制表示（可选）
    function sendParameterCommand(commandCode, valueHex) {
        var frame = "55 01 " + commandCode
        if (valueHex) {
            frame += " " + valueHex
        }
        // 计算并添加校验和
        var checksum = calculateChecksum(frame)
        frame += " " + checksum
        sendHexMessage(frame)
    }

    // 发送所有参数到设备
    function sendAllParameters() {
        sendCommandList = []

        // 额定电压
        var ratedVoltageHex = parseFloatToIEEE754(paramSettings.ratedVoltage)
        sendCommandList.push({
            name: "额定电压",
            command: "5A",
            value: ratedVoltageHex,
            successResponse: "AA 01 5A 05"
        })

        // 额定频率
        var ratedFrequencyHex = parseFloatToIEEE754(paramSettings.ratedFrequency)
        sendCommandList.push({
            name: "额定频率",
            command: "5B",
            value: ratedFrequencyHex,
            successResponse: "AA 01 5B 06"
        })

        // 电压倍率(PT比)
        var ptRatioHex = parseFloatToIEEE754(paramSettings.voltageMultiplier)
        sendCommandList.push({
            name: "电压倍率",
            command: "3A",
            value: ptRatioHex,
            successResponse: "AA 01 3A E5"
        })

        // 电流倍率(CT比)
        var ctRatioHex = parseFloatToIEEE754(paramSettings.currentMultiplier)
        sendCommandList.push({
            name: "电流倍率",
            command: "3B",
            value: ctRatioHex,
            successResponse: "AA 01 3B E6"
        })

        // 基准相选择
        var refPhaseCommand = ""
        var refPhaseSuccessResponse = ""
        if (paramSettings.referencePhase === 0) {
            refPhaseCommand = "50"
            refPhaseSuccessResponse = "AA 01 50 FB"
        } else if (paramSettings.referencePhase === 1) {
            refPhaseCommand = "51"
            refPhaseSuccessResponse = "AA 01 51 FC"
        } else if (paramSettings.referencePhase === 2) {
            refPhaseCommand = "52"
            refPhaseSuccessResponse = "AA 01 52 FD"
        }
        if (refPhaseCommand) {
            sendCommandList.push({
                name: "基准相",
                command: refPhaseCommand,
                value: null,
                successResponse: refPhaseSuccessResponse
            })
        }

        // 额定空载频率
        var noLoadFreqHex = parseFloatToIEEE754(paramSettings.noLoadFrequency)
        sendCommandList.push({
            name: "额定空载频率",
            command: "5C",
            value: noLoadFreqHex,
            successResponse: "AA 01 5C 07"
        })

        // 开始发送命令
        parameterSendInProgress = true
        currentSendCommandIndex = 0
        sendNextParameterCommand()
    }

    // 发送下一个参数命令
    function sendNextParameterCommand() {
        // 如果所有命令都已发送完成
        if (currentSendCommandIndex >= sendCommandList.length) {
            parameterSendInProgress = false
            parameterSendResultMessage = "所有参数设置成功！"
            showParameterSendResult = true
            return
        }

        // 发送当前命令
        var cmd = sendCommandList[currentSendCommandIndex]
        sendParameterCommand(cmd.command, cmd.value)
    }

    // 检查参数设置命令的响应
    // hexData: 接收到的16进制数据
    function checkParameterResponse(hexData) {
        if (!parameterSendInProgress) {
            return false
        }

        var trimmedData = hexData.trim()

        // 检查是否为失败响应
        if (trimmedData === "AA 01 FF AA") {
            var failedCmd = sendCommandList[currentSendCommandIndex]
            parameterSendInProgress = false
            parameterSendResultMessage = "设置 " + failedCmd.name + " 失败，请重试"
            showParameterSendResult = true
            return true
        }

        // 检查是否为成功响应
        var expectedCmd = sendCommandList[currentSendCommandIndex]
        if (trimmedData === expectedCmd.successResponse) {
            currentSendCommandIndex++
            sendNextParameterCommand()
            return true
        }

        return false
    }

    // 解析波动实验响应
    // hexData: 16进制数据字符串，包含21字节
    function parseWaveTestResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        // 验证数据长度
        if (bytes.length !== 21) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(61)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "61") {
            return false
        }
        
        // 计算并验证校验和
        var checksum = 0
        for (var i = 0; i < 20; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[20], 16)
        if (checksum !== receivedChecksum) {
            console.log("校验码错误: 计算值=" + checksum.toString(16) + ", 接收值=" + receivedChecksum.toString(16))
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            waveTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            waveTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            waveTestRefPhase = "C相"
        } else {
            waveTestRefPhase = "未知"
        }
        
        // 解析电压和频率的最大值、最小值
        waveTestVoltageMax = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        waveTestVoltageMin = parseIEEE754Float(bytes[8] + " " + bytes[9] + " " + bytes[10] + " " + bytes[11])
        waveTestFrequencyMax = parseIEEE754Float(bytes[12] + " " + bytes[13] + " " + bytes[14] + " " + bytes[15])
        waveTestFrequencyMin = parseIEEE754Float(bytes[16] + " " + bytes[17] + " " + bytes[18] + " " + bytes[19])
        
        return true
    }

    // 解析突加实验电压响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenAddTestResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        // 验证数据长度
        if (bytes.length < 417) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(64)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "64") {
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenAddTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenAddTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenAddTestRefPhase = "C相"
        } else {
            suddenAddTestRefPhase = "未知"
        }
        
        // 解析电压容差
        suddenAddTestTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        
        // 解析稳定时间和极值（16位整数）
        if (bytes.length >= 412) {
            suddenAddTestStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            suddenAddTestExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
        }
        
        // 解析倍率
        if (bytes.length >= 417) {
            suddenAddTestMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
        }
        
        return true
    }

    // 解析突加实验频率响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenAddFrequencyResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        if (bytes.length < 417) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(65)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "65") {
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenAddTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenAddTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenAddTestRefPhase = "C相"
        } else {
            suddenAddTestRefPhase = "未知"
        }
        
        // 解析频率容差
        suddenAddFrequencyTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        
        // 解析稳定时间和极值
        if (bytes.length >= 412) {
            suddenAddFrequencyStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            suddenAddFrequencyExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
        }
        
        // 解析额定空载频率
        if (bytes.length >= 417) {
            suddenAddRatedNoLoadFrequency = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
        }
        
        return true
    }

    // 解析突加实验电流响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenAddCurrentResponse(hexData) {
        console.log("parseSuddenAddCurrentResponse 被调用，数据长度:", hexData.length)
        var bytes = hexData.trim().split(" ")
        console.log("字节数:", bytes.length)
        console.log("前30个字节:", bytes.slice(0, 30).join(" "))
        console.log("字节400-420:", bytes.slice(400, 420).join(" "))
        
        // 验证数据长度
        if (bytes.length < 417) {
            console.log("数据长度不足，需要417字节，实际:", bytes.length)
            return false
        }
        
        // 验证帧头(AA 01)和命令码(66)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "66") {
            console.log("帧头或命令码不正确")
            return false
        }
        
        // 计算校验和
        var checksum = 0
        for (var i = 0; i < 416; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[416], 16)
        console.log("突加电流数据校验码 - 计算值:", checksum.toString(16), ", 接收值:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("突加电流数据校验码错误，跳过此响应")
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenAddTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenAddTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenAddTestRefPhase = "C相"
        } else {
            suddenAddTestRefPhase = "未知"
        }
        
        // 解析电流容差
        suddenAddCurrentTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        console.log("突加电流容差:", suddenAddCurrentTolerance)
        
        var tempStableTime = 0
        var tempExtremeValue = 0
        var tempMultiplier = 0
        
        // 解析稳定时间和极值
        if (bytes.length >= 412) {
            tempStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            tempExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
            console.log("突加电流稳定时间:", tempStableTime, "极值:", tempExtremeValue)
        }
        
        // 解析倍率
        if (bytes.length >= 417) {
            let raw = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
            tempMultiplier = raw
            console.log("突加电流倍率 - 原始:", raw, " 修正后:", tempMultiplier)
        }
        
        // 验证数据是否有效（稳定时间、极值、倍率都不能全为0）
        if (tempStableTime === 0 && tempExtremeValue === 0 && tempMultiplier === 0) {
            console.log("突加电流数据无效（全为0），跳过此响应")
            return false
        }
        
        // 数据有效，更新属性
        suddenAddCurrentStableTime = tempStableTime
        suddenAddCurrentExtremeValue = tempExtremeValue
        suddenAddCurrentMultiplier = tempMultiplier
        
        console.log("parseSuddenAddCurrentResponse 解析成功，返回true")
        return true
    }

    // 解析突卸实验电压响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenLoadTestResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        if (bytes.length < 417) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(67)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "67") {
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenLoadTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenLoadTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenLoadTestRefPhase = "C相"
        } else {
            suddenLoadTestRefPhase = "未知"
        }
        
        // 解析电压容差
        suddenLoadTestTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        
        // 解析稳定时间和极值
        if (bytes.length >= 412) {
            suddenLoadTestStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            suddenLoadTestExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
        }
        
        // 解析倍率
        if (bytes.length >= 417) {
            suddenLoadTestMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
        }
        
        return true
    }

    // 解析突卸实验频率响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenLoadFrequencyResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        if (bytes.length < 417) {
            return false
        }
        
        // 验证帧头(AA 01)和命令码(68)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "68") {
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenLoadTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenLoadTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenLoadTestRefPhase = "C相"
        } else {
            suddenLoadTestRefPhase = "未知"
        }
        
        // 解析频率容差
        suddenLoadFrequencyTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        
        // 解析稳定时间和极值
        if (bytes.length >= 412) {
            suddenLoadFrequencyStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            suddenLoadFrequencyExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
        }
        
        // 解析额定空载频率
        if (bytes.length >= 417) {
            suddenLoadRatedNoLoadFrequency = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
        }
        
        return true
    }

    // 解析突卸实验电流响应
    // hexData: 16进制数据字符串，包含417字节
    function parseSuddenLoadCurrentResponse(hexData) {
        console.log("parseSuddenLoadCurrentResponse 被调用，数据长度:", hexData.length)
        var bytes = hexData.trim().split(" ")
        console.log("字节数:", bytes.length)
        console.log("前30个字节:", bytes.slice(0, 30).join(" "))
        console.log("字节400-420:", bytes.slice(400, 420).join(" "))
        
        // 验证数据长度
        if (bytes.length < 417) {
            console.log("数据长度不足，需要417字节，实际:", bytes.length)
            return false
        }
        
        // 验证帧头(AA 01)和命令码(69)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "69") {
            console.log("帧头或命令码不正确")
            return false
        }
        
        // 计算校验和
        var checksum = 0
        for (var i = 0; i < 416; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[416], 16)
        console.log("突卸电流数据校验码 - 计算值:", checksum.toString(16), ", 接收值:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("突卸电流数据校验码错误，跳过此响应")
            return false
        }
        
        // 解析基准相
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            suddenLoadTestRefPhase = "A相"
        } else if (refPhaseByte === 1) {
            suddenLoadTestRefPhase = "B相"
        } else if (refPhaseByte === 2) {
            suddenLoadTestRefPhase = "C相"
        } else {
            suddenLoadTestRefPhase = "未知"
        }
        
        // 解析电流容差
        suddenLoadCurrentTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
        console.log("突卸电流容差:", suddenLoadCurrentTolerance)
        
        var tempStableTime = 0
        var tempExtremeValue = 0
        var tempMultiplier = 0
        
        // 解析稳定时间和极值
        if (bytes.length >= 412) {
            tempStableTime = (parseInt(bytes[408], 16) << 8) | parseInt(bytes[409], 16)
            tempExtremeValue = (parseInt(bytes[410], 16) << 8) | parseInt(bytes[411], 16)
            console.log("突卸电流稳定时间:", tempStableTime, "极值:", tempExtremeValue)
        }
        
        // 解析倍率
        if (bytes.length >= 417) {
            let raw = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415])
            tempMultiplier = raw
        }
        
        // 验证数据是否有效（稳定时间、极值、倍率都不能全为0）
        if (tempStableTime === 0 && tempExtremeValue === 0 && tempMultiplier === 0) {
            console.log("突卸电流数据无效（全为0），跳过此响应")
            return false
        }
        
        // 数据有效，更新属性
        suddenLoadCurrentStableTime = tempStableTime
        suddenLoadCurrentExtremeValue = tempExtremeValue
        suddenLoadCurrentMultiplier = tempMultiplier
        
        console.log("parseSuddenLoadCurrentResponse 解析成功，返回true")
        return true
    }



    // 解析谐波波形响应
    // hexData: 16进制数据字符串，包含517字节
    function parseHarmonicWaveformResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        console.log("解析波形数据，字节数:", bytes.length)
        if (bytes.length < 517) {
            console.log("波形数据长度不足，需要517字节，实际:", bytes.length)
            return false
        }
        
        // 验证帧头(AA 01)和命令码(71)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "71") {
            console.log("波形数据格式错误，帧头或命令码不正确")
            return false
        }
        
        // 计算校验和
        var checksum = 0
        for (var i = 0; i < 516; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[516], 16)
        console.log("波形数据校验码 - 计算值:", checksum.toString(16), ", 接收值:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("波形数据校验码错误")
            // 暂时允许校验码错误，继续解析数据
        }
        
        // 提取基准相信息
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            harmonicTestRefPhase = "A 相"
        } else if (refPhaseByte === 1) {
            harmonicTestRefPhase = "B 相"
        } else if (refPhaseByte === 2) {
            harmonicTestRefPhase = "C 相"
        } else {
            harmonicTestRefPhase = "未知"
        }
        
        // 提取电压波形数据（128个采样点，每个点2字节）
        var voltageData = []
        for (var i = 0; i < 128; i++) {
            var offset = 4 + i * 2
            var value = (parseInt(bytes[offset], 16) << 8) | parseInt(bytes[offset + 1], 16)
            // 转换为有符号整数
            if (value > 32767) {
                value -= 65536
            }
            voltageData.push(value)
        }
        
        // 提取电流波形数据（128个采样点，每个点2字节）
        var currentData = []
        for (var j = 0; j < 128; j++) {
            var offsetJ = 260 + j * 2
            var valueJ = (parseInt(bytes[offsetJ], 16) << 8) | parseInt(bytes[offsetJ + 1], 16)
            // 转换为有符号整数
            if (valueJ > 32767) {
                valueJ -= 65536
            }
            currentData.push(valueJ)
        }
        
        harmonicTestRefPhase = harmonicTestRefPhase
        harmonicTestVoltageWaveform = voltageData
        harmonicTestCurrentWaveform = currentData
        
        console.log("波形数据解析成功，基准相:", harmonicTestRefPhase)
        console.log("电压波形数据长度:", harmonicTestVoltageWaveform.length)
        console.log("电流波形数据长度:", harmonicTestCurrentWaveform.length)
        return true
    }

    // 解析谐波测试响应
    // hexData: 16进制数据字符串，包含485字节
    function parseHarmonicTestResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        console.log("解析谐波数据，字节数:", bytes.length)
        
        // 假设50次谐波数据，每谐波4字节IEEE754浮点数，共51次（基波+50次谐波）
        if (bytes.length < 485) {
            console.log("谐波数据长度不足，需要485字节，实际:", bytes.length)
            return false
        }
        
        // 验证帧头(AA 01)和命令码(73)
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "73") {
            console.log("谐波数据格式错误，帧头或命令码不正确")
            return false
        }
        
        // 计算校验和
        var checksum = 0
        for (var i = 0; i < 484; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[484], 16)
        console.log("谐波数据校验码 - 计算值:", checksum.toString(16), ", 接收值:", receivedChecksum.toString(16))
        if (checksum !== receivedChecksum) {
            console.log("谐波数据校验码错误")
            // 暂时允许校验码错误，继续解析数据
        }
        
        // 提取基准相信息
        var refPhaseByte = parseInt(bytes[3], 16)
        if (refPhaseByte === 0) {
            harmonicTestRefPhase = "A 相"
        } else if (refPhaseByte === 1) {
            harmonicTestRefPhase = "B 相"
        } else if (refPhaseByte === 2) {
            harmonicTestRefPhase = "C 相"
        } else {
            harmonicTestRefPhase = "未知"
        }
        
        // 提取电压谐波数据（基波+50次谐波，每个4字节IEEE754浮点数）
        var voltageHarmonics = []
        for (var v = 0; v < 51; v++) {
            var offsetV = 4 + v * 4
            var hexStrV = bytes[offsetV] + " " + bytes[offsetV + 1] + " " + bytes[offsetV + 2] + " " + bytes[offsetV + 3]
            var valueV = parseIEEE754Float(hexStrV)
            voltageHarmonics.push(valueV)
        }
        
        // 提取电流谐波数据（基波+50次谐波，每个4字节IEEE754浮点数）
        var currentHarmonics = []
        for (var c = 0; c < 51; c++) {
            var offsetC = 208 + c * 4
            var hexStrC = bytes[offsetC] + " " + bytes[offsetC + 1] + " " + bytes[offsetC + 2] + " " + bytes[offsetC + 3]
            var valueC = parseIEEE754Float(hexStrC)
            currentHarmonics.push(valueC)
        }
        
        harmonicTestVoltageHarmonics = voltageHarmonics
        harmonicTestCurrentHarmonics = currentHarmonics
        
        // 计算电压波形畸变率
        harmonicTestVoltageDistortionRate = calculateVoltageDistortionRate(voltageHarmonics)
        
        console.log("谐波数据解析成功，基准相:", harmonicTestRefPhase)
        console.log("电压波形畸变率 Ku%:", harmonicTestVoltageDistortionRate.toFixed(4))
        return true
    }

    // 计算电压波形畸变率(THD)
    // harmonics: 谐波数据数组，索引0为基波，索引1-50为1-50次谐波
    function calculateVoltageDistortionRate(harmonics) {
        if (!harmonics || harmonics.length < 2) {
            return 0
        }
        
        // 基波幅值（索引0）
        var fundamental = harmonics[0]
        console.log("基波值:", fundamental)
        
        if (fundamental <= 0) {
            return 0
        }
        
        // 计算各次谐波平方和（h=1到h=50）- 谐波值是相对于基波的百分比
        var harmonicSum = 0
        for (var h = 1; h <= 50; h++) {
            var harmonic = harmonics[h]
            if (h <= 5) {
                console.log("第" + (h) + "次谐波:", harmonic, "%")
            }
            harmonicSum += harmonic * harmonic
        }
        
        console.log("谐波平方和:", harmonicSum)
        console.log("谐波平方和开方:", Math.sqrt(harmonicSum))
        
        // 计算畸变率: THD = √(ΣUh²) % （因为Uh已经是相对于基波的百分比）
        var thd = Math.sqrt(harmonicSum)
        console.log("计算的THD:", thd, "%")
        return thd
    }

    // 启动波动实验
    /**
     * 启动波动实验
     * 功能：测量电压和频率的波动率
     * 
     * 执行步骤：
     * 1. 初始化波动实验相关状态和数据
     * 2. 发送启动波动实验的十六进制命令
     * 3. 显示等待弹窗，等待60秒
     * 4. 启动实验开始定时器
     */
    function startWaveTest() {
        currentTestType = "wave"
        waveTestInProgress = true
        waveTestDataRequested = false
        waveTestRetryCount = 0
        waveTestStep = 0
        waveTestStatus = "正在启动波动实验..."
        waveTestRefPhase = ""
        waveTestVoltageMax = 0
        waveTestVoltageMin = 0
        waveTestFrequencyMax = 0
        waveTestFrequencyMin = 0
        sendHexMessage("55 01 60 B6")
        showWaitingPopup("波动实验进行中...", 60)
        waveTestStartTimer.start()
    }

    /**
     * 请求波动实验数据
     * 功能：向设备发送请求，获取波动实验的测试数据
     * 注意：防止重复请求，只在未请求过时发送
     */
    function requestWaveTestData() {
        if (waveTestStep >= 1) {
            console.log("波动实验数据请求已发送，跳过重复发送")
            return
        }
        waveTestStep = 1
        waveTestStatus = "正在请求波动实验数据..."
        sendHexMessage("55 01 61 B7")
        waveTestDataRequestTimer.start()
    }

    /**
     * 停止波动实验
     * 功能：停止正在进行的波动实验，保存数据并清理资源
     * 
     * 执行步骤：
     * 1. 标记波动实验状态为停止
     * 2. 停止所有相关的定时器
     * 3. 隐藏等待弹窗
     * 4. 保存当前标签页的数据
     * 5. 保存测试数据到历史
     * 6. 如果在一键测试中，继续下一步
     */
    function stopWaveTest() {
        waveTestInProgress = false
        waveTestDataRequested = false
        waveTestStartTimer.stop()
        waveTestDataRequestTimer.stop()
        waveTestRetryTimer.stop()
        hideWaitingPopup()
        saveCurrentTabData()
        saveTestData()
        if (autoTestInProgress || singleTabAutoTestInProgress) {
            onAutoTestStepCompleted()
        }
    }

    /**
     * 启动突加实验
     * 功能：突加负载时测量电压和频率的瞬态特性
     * 
     * 执行步骤：
     * 1. 初始化突加实验相关状态和数据
     * 2. 通过Modbus发送卸载报文（功率0）
     * 3. 显示等待弹窗，等待32秒
     * 4. 启动等待定时器
     */
    function startSuddenAddTest() {
        currentTestType = "suddenAdd"
        suddenAddTestInProgress = true
        suddenAddTestDataRequested = false
        suddenAddTestRetryCount = 0
        suddenAddTestStep = 0
        suddenAddTestPhase = 0
        suddenAddTestStatus = "正在发送卸载报文..."
        suddenAddTestRefPhase = ""
        suddenAddTestTolerance = 0
        suddenAddTestStableTime = 0
        suddenAddTestExtremeValue = 0
        suddenAddTestMultiplier = 0
        suddenAddFrequencyTolerance = 0
        suddenAddFrequencyStableTime = 0
        suddenAddFrequencyExtremeValue = 0
        suddenAddRatedNoLoadFrequency = 0
        suddenAddCurrentTolerance = 0
        suddenAddCurrentStableTime = 0
        suddenAddCurrentExtremeValue = 0
        suddenAddCurrentMultiplier = 0
        
        if (modbusManager) {
            modbusManager.writeCurrent(0, 1)
            console.log("突加实验：已发送卸载报文（功率0）")
        }
        showWaitingPopup("突加实验进行中...", 32)
        suddenAddTestPhase = 1
        suddenAddTestWaitTimer.start()
    }

    /**
     * 请求突加实验电压数据
     * 功能：向设备发送请求，获取突加实验的电压测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 1）
     */
    function requestSuddenAddTestData() {
        if (suddenAddTestStep >= 1) {
            console.log("电压数据请求已发送，跳过重复发送")
            return
        }
        suddenAddTestStep = 1
        suddenAddTestStatus = "正在请求突加实验电压数据..."
        sendHexMessage("55 01 64 BA")
        suddenAddTestDataRequestTimer.start()
    }

    /**
     * 请求突加实验频率数据
     * 功能：向设备发送请求，获取突加实验的频率测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 2）
     */
    function requestSuddenAddFrequencyData() {
        if (suddenAddTestStep >= 2) {
            console.log("频率数据请求已发送，跳过重复发送")
            return
        }
        suddenAddTestStep = 2
        suddenAddTestStatus = "正在请求突加实验频率数据..."
        sendHexMessage("55 01 65 BB")
        suddenAddTestDataRequestTimer.start()
    }

    /**
     * 请求突加实验电流数据
     * 功能：向设备发送请求，获取突加实验的电流测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 3）
     */
    function requestSuddenAddCurrentData() {
        if (suddenAddTestStep >= 3) {
            console.log("电流数据请求已发送，跳过重复发送")
            return
        }
        suddenAddTestStep = 3
        suddenAddTestStatus = "正在请求突加实验电流数据..."
        sendHexMessage("55 01 66 BC")
        suddenAddTestDataRequestTimer.start()
    }

    /**
     * 停止突加实验
     * 功能：停止正在进行的突加实验，保存数据并清理资源
     * 
     * 执行步骤：
     * 1. 标记突加实验状态为停止
     * 2. 停止所有相关的定时器
     * 3. 隐藏等待弹窗
     * 4. 保存当前标签页的数据
     * 5. 保存测试数据到历史
     * 6. 如果在一键测试中，继续下一步
     */
    function stopSuddenAddTest() {
        suddenAddTestInProgress = false
        suddenAddTestDataRequested = false
        suddenAddTestStartTimer.stop()
        suddenAddTestWaitTimer.stop()
        suddenAddTestDataRequestTimer.stop()
        suddenAddTestRetryTimer.stop()
        suddenAddPowerSendTimer.stop()
        hideWaitingPopup()
        saveCurrentTabData()
        saveTestData()
        if (autoTestInProgress || singleTabAutoTestInProgress) {
            onAutoTestStepCompleted()
        }
    }

    /**
     * 启动突卸实验
     * 功能：突卸负载时测量电压和频率的瞬态特性
     * 
     * 执行步骤：
     * 1. 初始化突卸实验相关状态和数据
     * 2. 通过Modbus发送加载功率报文（当前标签的功率）
     * 3. 显示等待弹窗，等待32秒
     * 4. 启动等待定时器
     */
    function startSuddenLoadTest() {
        currentTestType = "suddenLoad"
        suddenLoadTestInProgress = true
        suddenLoadTestDataRequested = false
        suddenLoadTestRetryCount = 0
        suddenLoadTestStep = 0
        suddenLoadTestPhase = 0
        suddenLoadTestStatus = "正在发送加载功率报文..."
        suddenLoadTestRefPhase = ""
        suddenLoadTestTolerance = 0
        suddenLoadTestStableTime = 0
        suddenLoadTestExtremeValue = 0
        suddenLoadTestMultiplier = 0
        suddenLoadFrequencyTolerance = 0
        suddenLoadFrequencyStableTime = 0
        suddenLoadFrequencyExtremeValue = 0
        suddenLoadRatedNoLoadFrequency = 0
        suddenLoadCurrentTolerance = 0
        suddenLoadCurrentStableTime = 0
        suddenLoadCurrentExtremeValue = 0
        suddenLoadCurrentMultiplier = 0
        
        if (modbusManager) {
            sendPowerByCurrentTab()
            console.log("突卸实验：已发送加载功率报文")
        }
        showWaitingPopup("突卸实验进行中...", 32)
        suddenLoadTestPhase = 1
        suddenLoadTestWaitTimer.start()
    }

    /**
     * 请求突卸实验电压数据
     * 功能：向设备发送请求，获取突卸实验的电压测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 1）
     */
    function requestSuddenLoadTestData() {
        if (suddenLoadTestStep >= 1) {
            console.log("电压数据请求已发送，跳过重复发送")
            return
        }
        suddenLoadTestStep = 1
        suddenLoadTestStatus = "正在请求突卸实验电压数据..."
        sendHexMessage("55 01 67 BD")
        suddenLoadTestDataRequestTimer.start()
    }

    /**
     * 请求突卸实验频率数据
     * 功能：向设备发送请求，获取突卸实验的频率测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 2）
     */
    function requestSuddenLoadFrequencyData() {
        if (suddenLoadTestStep >= 2) {
            console.log("频率数据请求已发送，跳过重复发送")
            return
        }
        suddenLoadTestStep = 2
        suddenLoadTestStatus = "正在请求突卸实验频率数据..."
        sendHexMessage("55 01 68 BE")
        suddenLoadTestDataRequestTimer.start()
    }

    /**
     * 请求突卸实验电流数据
     * 功能：向设备发送请求，获取突卸实验的电流测试数据
     * 注意：防止重复请求，只在未请求过时发送（step < 3）
     */
    function requestSuddenLoadCurrentData() {
        if (suddenLoadTestStep >= 3) {
            console.log("电流数据请求已发送，跳过重复发送")
            return
        }
        suddenLoadTestStep = 3
        suddenLoadTestStatus = "正在请求突卸实验电流数据..."
        sendHexMessage("55 01 69 BF")
        suddenLoadTestDataRequestTimer.start()
    }

    /**
     * 停止突卸实验
     * 功能：停止正在进行的突卸实验，保存数据并清理资源
     * 
     * 执行步骤：
     * 1. 标记突卸实验状态为停止
     * 2. 停止所有相关的定时器
     * 3. 隐藏等待弹窗
     * 4. 保存当前标签页的数据
     * 5. 保存测试数据到历史
     * 6. 如果在一键测试中，继续下一步
     */
    function stopSuddenLoadTest() {
        suddenLoadTestInProgress = false
        suddenLoadTestDataRequested = false
        suddenLoadTestStartTimer.stop()
        suddenLoadTestWaitTimer.stop()
        suddenLoadTestDataRequestTimer.stop()
        suddenLoadTestRetryTimer.stop()
        suddenLoadUnloadTimer.stop()
        hideWaitingPopup()
        saveCurrentTabData()
        saveTestData()
        if (autoTestInProgress || singleTabAutoTestInProgress) {
            onAutoTestStepCompleted()
        }
    }

    /**
     * 启动谐波实验
     * 功能：测量电压和电流的谐波含量
     * 
     * 执行步骤：
     * 1. 初始化谐波实验相关状态和数据
     * 2. 发送启动谐波实验的十六进制命令
     * 3. 显示等待弹窗，等待60秒
     * 4. 启动实验开始定时器
     */
    function startHarmonicTest() {
        currentTestType = "harmonic"
        harmonicTestInProgress = true
        harmonicTestDataRequested = false
        harmonicTestRetryCount = 0
        harmonicTestStep = 1
        harmonicTestStepFlag = 0
        harmonicTestStatus = "正在启动谐波实验..."
        harmonicTestRefPhase = ""
        harmonicTestVoltageWaveform = []
        harmonicTestCurrentWaveform = []
        sendHexMessage("55 01 70 C6")
        showWaitingPopup("谐波实验进行中...", 60)
        harmonicTestStartTimer.start()
    }

    /**
     * 请求谐波波形数据
     * 功能：向设备发送请求，获取谐波实验的基准相波形数据
     * 注意：防止重复请求，只在未请求过时发送（stepFlag < 2）
     */
    function requestHarmonicWaveformData() {
        if (harmonicTestStepFlag >= 2) {
            console.log("谐波波形数据请求已发送，跳过重复发送")
            return
        }
        harmonicTestStepFlag = 2
        harmonicTestStatus = "正在请求基准相波形数据..."
        sendHexMessage("55 01 71 C7")
        harmonicTestDataRequestTimer.start()
    }

    /**
     * 请求谐波测试数据
     * 功能：向设备发送请求，获取谐波实验的全量数据
     * 注意：防止重复请求，只在未请求过时发送（stepFlag < 3）
     */
    function requestHarmonicTestData() {
        if (harmonicTestStepFlag >= 3) {
            console.log("谐波全量数据请求已发送，跳过重复发送")
            return
        }
        harmonicTestStepFlag = 3
        harmonicTestStatus = "正在请求谐波全量数据..."
        sendHexMessage("55 01 73 C9")
        harmonicTestDataRequestTimer.start()
    }

    /**
     * 请求退出谐波模式
     * 功能：向设备发送请求，退出谐波实验模式，返回静态模式
     * 注意：防止重复请求，只在未请求过时发送（stepFlag < 4）
     */
    function requestHarmonicExit() {
        if (harmonicTestStepFlag >= 4) {
            console.log("谐波退出请求已发送，跳过重复发送")
            return
        }
        harmonicTestStepFlag = 4
        harmonicTestStatus = "正在退出谐波模式..."
        sendHexMessage("55 01 72 C8")
        harmonicTestDataRequestTimer.start()
    }

    /**
     * 停止谐波实验
     * 功能：停止正在进行的谐波实验，保存数据并清理资源
     * 
     * 执行步骤：
     * 1. 标记谐波实验状态为停止
     * 2. 停止所有相关的定时器
     * 3. 隐藏等待弹窗
     * 4. 保存测试数据到历史
     * 5. 如果在一键测试中，继续下一步
     */
    function stopHarmonicTest() {
        harmonicTestInProgress = false
        harmonicTestDataRequested = false
        harmonicTestStep = 0
        harmonicTestStartTimer.stop()
        harmonicTestDataRequestTimer.stop()
        harmonicTestRetryTimer.stop()
        hideWaitingPopup()
        saveTestData()
        if (autoTestInProgress || singleTabAutoTestInProgress) {
            onAutoTestStepCompleted()
        }
    }
    
    /**
     * 启动电压整定测试
     * 功能：测量电压整定范围（可调节的电压最大值和最小值）
     * 
     * 执行步骤：
     * 1. 初始化电压整定测试相关状态和数据
     * 2. 发送启动电压整定的十六进制命令
     * 3. 显示等待弹窗，等待105秒
     * 4. 启动测试开始定时器
     */
    function startVoltageCalibrationTest() {
        currentTestType = "voltageCalibration"
        currentCalibrationType = "voltage"
        calibrationTestInProgress = true
        calibrationTestDataRequested = false
        calibrationTestRetryCount = 0
        calibrationTestStep = 0
        voltageCalibrationStatus = "正在启动电压整定，等待105秒..."
        voltageCalibrationRefPhase = ""
        voltageCalibrationUmax = 0
        voltageCalibrationUmin = 0
        sendHexMessage("55 01 76 CC")
        showWaitingPopup("电压整定进行中...", 105)
        calibrationTestStartTimer.start()
    }
    
    /**
     * 启动频率整定测试
     * 功能：测量频率整定范围（可调节的频率最大值和最小值）
     * 
     * 执行步骤：
     * 1. 初始化频率整定测试相关状态和数据
     * 2. 发送启动频率整定的十六进制命令
     * 3. 显示等待弹窗，等待105秒
     * 4. 启动测试开始定时器
     */
    function startFrequencyCalibrationTest() {
        currentTestType = "frequencyCalibration"
        currentCalibrationType = "frequency"
        calibrationTestInProgress = true
        calibrationTestDataRequested = false
        calibrationTestRetryCount = 0
        calibrationTestStep = 0
        frequencyCalibrationStatus = "正在启动频率整定，等待105秒..."
        frequencyCalibrationRefPhase = ""
        frequencyCalibrationFmax = 0
        frequencyCalibrationFmin = 0
        sendHexMessage("55 01 77 CD")
        showWaitingPopup("频率整定进行中...", 105)
        calibrationTestStartTimer.start()
    }
    
    /**
     * 请求整定测试数据
     * 功能：向设备发送请求，获取电压或频率整定的测试数据
     * 根据currentCalibrationType判断是请求电压还是频率数据
     * 注意：防止重复请求，只在未请求过时发送（step < 2）
     */
    function requestCalibrationTestData() {
        if (calibrationTestStep >= 2) {
            console.log("校准测试数据请求已发送，跳过重复发送")
            return
        }
        calibrationTestStep = 2
        if (currentCalibrationType === "voltage") {
            voltageCalibrationStatus = "正在请求电压整定数据..."
        } else if (currentCalibrationType === "frequency") {
            frequencyCalibrationStatus = "正在请求频率整定数据..."
        }
        sendHexMessage("55 01 74 CA")
        calibrationTestDataRequestTimer.start()
    }
    
    /**
     * 停止整定测试
     * 功能：停止正在进行的电压或频率整定测试，清理资源
     * 
     * 执行步骤：
     * 1. 标记整定测试状态为停止
     * 2. 停止所有相关的定时器
     * 3. 隐藏等待弹窗
     * 4. 如果在一键测试中，继续下一步
     */
    function stopCalibrationTest() {
        calibrationTestInProgress = false
        calibrationTestDataRequested = false
        calibrationTestStartTimer.stop()
        calibrationTestDataRequestTimer.stop()
        calibrationTestRetryTimer.stop()
        voltageCalibrationInProgress = false
        frequencyCalibrationInProgress = false
        hideWaitingPopup()
        if (autoTestInProgress || singleTabAutoTestInProgress) {
            onAutoTestStepCompleted()
        }
    }
    
    /**
     * 刷新波动实验数据
     * 功能：重置波动实验状态并重新请求数据
     */
    function refreshWaveTestData() {
        waveTestStep = 0
        waveTestDataRequested = false
        waveTestInProgress = true
        requestWaveTestData()
    }
    
    /**
     * 刷新突加实验数据
     * 功能：重置突加实验状态并重新请求电压数据
     */
    function refreshSuddenAddTestData() {
        suddenAddTestStep = 0
        suddenAddTestDataRequested = false
        suddenAddTestInProgress = true
        requestSuddenAddTestData()
    }
    
    /**
     * 刷新突卸实验数据
     * 功能：重置突卸实验状态并重新请求电压数据
     */
    function refreshSuddenLoadTestData() {
        suddenLoadTestStep = 0
        suddenLoadTestDataRequested = false
        suddenLoadTestInProgress = true
        requestSuddenLoadTestData()
    }
    
    /**
     * 刷新谐波实验数据
     * 功能：重置谐波实验状态并重新请求波形数据
     */
    function refreshHarmonicTestData() {
        harmonicTestStepFlag = 0
        harmonicTestStep = 0
        harmonicTestDataRequested = false
        harmonicTestInProgress = true
        requestHarmonicWaveformData()
    }
    
    /**
     * 刷新电压整定数据
     * 功能：重置电压整定状态并重新请求数据
     */
    function refreshVoltageCalibrationData() {
        calibrationTestStep = 0
        calibrationTestDataRequested = false
        calibrationTestInProgress = true
        currentCalibrationType = "voltage"
        requestCalibrationTestData()
    }
    
    /**
     * 刷新频率整定数据
     * 功能：重置频率整定状态并重新请求数据
     */
    function refreshFrequencyCalibrationData() {
        calibrationTestStep = 0
        calibrationTestDataRequested = false
        calibrationTestInProgress = true
        currentCalibrationType = "frequency"
        requestCalibrationTestData()
    }
    
    /**
     * 启动录波测试（已注释）
     * 功能：启动录波模式，记录电压和电流波形
     * 注意：此功能当前未启用
     */
    function startWaveformRecordTest() {
        currentTestType = "waveformRecord"
        waveformRecordTestInProgress = true
        waveformRecordTestStatus = "正在启动录波模式..."
        sendHexMessage("55 01 78 CE")
    }
    
    /**
     * 停止录波测试
     * 功能：停止录波模式
     */
    function stopWaveformRecordTest() {
        waveformRecordTestInProgress = false
    }
    
    /**
     * 启动一键测试（所有标签）
     * 功能：对所有功率标签依次执行用户配置的测试项目
     * 
     * 执行步骤：
     * 1. 初始化一键测试相关状态和数据
     * 2. 初始化测试数据历史存储
     * 3. 切换到第一个标签页
     * 4. 开始执行第一个测试
     */
    function startAutoTest() {
        autoTestInProgress = true
        autoTestStep = 1
        autoTestCurrentTab = 0
        autoTestStepInCurrentTab = 1
        autoTestStaticParamsRequested = false
        autoTestRetryCount = 0
        autoTestWaitingForRetry = false
        autoTestStatus = "正在开始一键测试..."
        
        testDataHistory = {
            "wave": null,
            "suddenAdd": null,
            "suddenLoad": null,
            "harmonic": null
        }
        
        deviceParamsRequested = false
        deviceParamsReceived = false
        
        // 切换到第一个标签
        switchTab(0)
        startNextAutoTest()
    }
    
    /**
     * 获取当前标签页应该执行的测试列表（按顺序）
     * 功能：返回用户在一键测试设置项中启用并排序的测试列表
     * @returns {Array} 已启用测试项目的数组，按用户配置的顺序排列
     */
    function getCurrentTabTestList() {
        return getEnabledTests()
    }
    
    /**
     * 启动单标签一键测试
     * 功能：只对当前选中的功率标签执行用户配置的测试项目
     * 
     * 执行步骤：
     * 1. 初始化单标签一键测试相关状态和数据
     * 2. 初始化测试数据历史存储
     * 3. 开始执行第一个测试
     */
    function startSingleTabAutoTest() {
        singleTabAutoTestInProgress = true
        autoTestStep = 1
        autoTestCurrentTab = currentTabIndex
        autoTestStepInCurrentTab = 1
        autoTestStaticParamsRequested = false
        autoTestRetryCount = 0
        autoTestWaitingForRetry = false
        autoTestStatus = "正在开始单标签一键测试..."
        
        testDataHistory = {
            "wave": null,
            "suddenAdd": null,
            "suddenLoad": null,
            "harmonic": null
        }
        
        deviceParamsRequested = false
        deviceParamsReceived = false
        
        startNextAutoTest()
    }
    
    /**
     * 开始下一个一键测试步骤
     * 功能：根据当前进度执行下一个测试或切换到下一个标签页
     * 
     * 执行逻辑：
     * 1. 检查是否还有未执行的测试
     * 2. 如果当前标签还有测试，执行下一个测试
     * 3. 如果当前标签测试完成，切换到下一个标签
     * 4. 如果所有标签都完成，执行导出和结束
     */
    function startNextAutoTest() {
        if (!autoTestInProgress && !singleTabAutoTestInProgress) return
        
        // 获取当前标签应该执行的测试列表（按用户配置的顺序）
        var testList = getCurrentTabTestList()
        var testsPerTab = testList.length
        
        // 计算当前标签和步骤
        var totalTabs = tabLabels.length
        var currentTab = autoTestCurrentTab
        var testStepInTab = autoTestStepInCurrentTab
        
        // 检查是否完成了测试
        if (singleTabAutoTestInProgress && testStepInTab > testsPerTab) {
            // 单标签测试完成
            autoTestStatus = "单标签所有实验完成，正在导出报表..."
            singleTabAutoTestInProgress = false
            requestDeviceParams()
            autoTestExportTimer.start()
            return
        }
        
        // 检查是否完成了所有标签的测试（全标签模式）
        if (autoTestInProgress && currentTab >= totalTabs) {
            autoTestStatus = "所有实验完成，正在导出报表..."
            autoTestInProgress = false
            requestDeviceParams()
            autoTestExportTimer.start()
            return
        }
        
        // 执行当前标签的测试
        if (singleTabAutoTestInProgress) {
            autoTestStatus = "标签 " + (currentTab + 1) + " 步骤 " + testStepInTab + "/" + testsPerTab + "："
        } else {
            autoTestStatus = "标签 " + (currentTab + 1) + "/" + totalTabs + " 步骤 " + testStepInTab + "/" + testsPerTab + "："
        }
        
        // 获取当前要执行的测试
        var currentTest = testList[testStepInTab - 1]
        if (!currentTest) {
            console.log("没有找到当前测试，跳过")
            autoTestStepInCurrentTab++
            startNextAutoTest()
            return
        }
        
        autoTestStatus += currentTest.name
        
        switch(currentTest.id) {
            case "static":
                autoTestStatus += "召测静态三相参数"
                // 暂停三相参数定时器，避免与静态参数召测冲突
                if (threePhaseParamsTimer.running) {
                    threePhaseParamsTimer.stop()
                }
                // 清空接收缓冲区
                var generatorTestManager = getGeneratorTestManager()
                if (generatorTestManager) {
                    generatorTestManager.clearReceiveBuffer()
                }
                sendHexMessage("55 01 34 8A")
                autoTestStaticParamsRequested = true
                // 标记这是静态参数步骤
                isStaticParamsStep = true
                // 重置重试计数
                autoTestRetryCount = 0
                // 重置静态参数接收标志
                staticThreePhaseParamsReceived = false
                showWaitingPopup("召测静态三相参数中...", 5)
                autoTestNextStepTimer.interval = 5000
                autoTestNextStepTimer.start()
                break
            case "wave":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startWaveTest()
                break
            case "harmonic":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startHarmonicTest()
                break
            case "voltageCalibration":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startVoltageCalibrationTest()
                break
            case "frequencyCalibration":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startFrequencyCalibrationTest()
                break
            case "suddenAdd":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startSuddenAddTest()
                break
            case "suddenLoad":
                isStaticParamsStep = false
                autoTestNextStepTimer.interval = 5000
                startSuddenLoadTest()
                break
        }
    }
    
    /**
     * 一键测试步骤完成回调
     * 功能：在单个测试完成后被调用，更新进度并决定下一步操作
     * 
     * 执行逻辑：
     * 1. 增加测试步骤计数器
     * 2. 判断是单标签模式还是全标签模式
     * 3. 根据模式决定是继续当前标签的下一个测试，还是切换到下一个标签，还是结束
     */
    function onAutoTestStepCompleted() {
        autoTestStep++
        autoTestStepInCurrentTab++
        
        var testList = getCurrentTabTestList()
        var testsPerTab = testList.length
        var totalTabs = tabLabels.length
        
        // 单标签一键测试模式
        if (singleTabAutoTestInProgress) {
            if (autoTestStepInCurrentTab > testsPerTab) {
                // 当前标签测试完成，直接调用 startNextAutoTest 处理结束
                autoTestNextStepTimer.start()
            } else {
                // 继续当前标签的下一个测试
                autoTestStatus = "准备进行下一个实验..."
                showWaitingPopup("实验间隔等待中...", 5)
                autoTestNextStepTimer.start()
            }
            return
        }
        
        // 全标签一键测试模式
        // 检查当前标签页的所有测试是否完成
        if (autoTestStepInCurrentTab > testsPerTab) {
            // 当前标签页完成，切换到下一个标签
            autoTestCurrentTab++
            autoTestStepInCurrentTab = 1
            
            // 检查是否所有标签都完成了
            if (autoTestCurrentTab >= totalTabs) {
                // 所有标签完成，直接调用 startNextAutoTest 来处理结束逻辑
                autoTestNextStepTimer.start()
                return
            }
            
            // 切换到下一个标签
            switchTab(autoTestCurrentTab)
            
            // 使用用户配置的等待时间等待后开始下一个标签的实验
            // 等待时间单位：分钟，转换为秒给showWaitingPopup，转换为毫秒给定时器
            autoTestStatus = "标签 " + (autoTestCurrentTab + 1) + "/" + totalTabs + "：切换标签后等待" + powerTabSwitchWaitTime + "分钟..."
            showWaitingPopup("切换标签中，请稍候...", powerTabSwitchWaitTime * 60)
            autoTestTabSwitchTimer.interval = powerTabSwitchWaitTime * 60000
            autoTestTabSwitchTimer.start()
        } else {
            // 继续当前标签的下一个测试
            autoTestStatus = "准备进行下一个实验..."
            showWaitingPopup("实验间隔等待中...", 5)
            autoTestNextStepTimer.start()
        }
    }
    
    /**
     * 停止一键测试
     * 功能：取消正在进行的一键测试，停止所有相关操作和定时器
     * 
     * 执行步骤：
     * 1. 标记一键测试和单标签测试状态为停止
     * 2. 停止所有正在进行的单个测试（波动实验、突加实验、突卸实验、谐波实验、校准等）
     * 3. 停止所有一键测试相关的定时器（下一步定时器、导出定时器、标签切换定时器）
     * 4. 隐藏等待弹窗（重要：避免取消测试后仍显示等待时间）
     * 5. 发送返回静态命令，使设备恢复到安全状态
     */
    function stopAutoTest() {
        autoTestInProgress = false
        singleTabAutoTestInProgress = false
        autoTestStatus = "一键测试已取消"
        
        // 停止所有正在进行的测试
        if (waveTestInProgress) {
            stopWaveTest()
        }
        if (suddenAddTestInProgress) {
            stopSuddenAddTest()
        }
        if (suddenLoadTestInProgress) {
            stopSuddenLoadTest()
        }
        if (harmonicTestInProgress) {
            stopHarmonicTest()
        }
        if (calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress) {
            stopCalibrationTest()
        }
        
        // 停止相关定时器
        autoTestNextStepTimer.stop()      // 停止下一步测试定时器
        autoTestExportTimer.stop()        // 停止导出定时器
        autoTestTabSwitchTimer.stop()     // 停止标签切换等待定时器
        
        // 隐藏等待弹窗 - 重要：避免取消测试后仍显示等待时间
        hideWaitingPopup()
        
        // 延迟一小段时间后，发送返回静态命令
        autoTestStatus = "正在返回静态..."
        Qt.callLater(function() {
            // 发送返回静态命令，使设备恢复安全状态
            sendHexMessage("55 01 72 C8")
            currentTestType = ""
            
            // 再次检查并停止所有实验定时器和操作（确保万无一失）
            if (waveTestInProgress) {
                stopWaveTest()
            }
            if (suddenAddTestInProgress) {
                stopSuddenAddTest()
            }
            if (suddenLoadTestInProgress) {
                stopSuddenLoadTest()
            }
            if (harmonicTestInProgress) {
                stopHarmonicTest()
            }
            if (calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress) {
                stopCalibrationTest()
            }
            
            autoTestStatus = "已返回静态"
        })
    }
    
    /**
     * 一键测试下一步定时器
     * 功能：在实验间隔或等待后执行下一步操作
     * 
     * 执行逻辑：
     * 1. 如果有重试类型，重新启动对应的测试
     * 2. 如果是静态参数步骤，标记完成并继续
     * 3. 其他情况，隐藏提示框并开始下一个测试
     */
    Timer {
        id: autoTestNextStepTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (autoTestRetryType !== "") {
                // 处理重试逻辑
                hideWaitingPopup()
                switch(autoTestRetryType) {
                    case "wave":
                        startWaveTest()
                        break
                    case "suddenAdd":
                        startSuddenAddTest()
                        break
                    case "suddenLoad":
                        startSuddenLoadTest()
                        break
                    case "harmonic":
                        startHarmonicTest()
                        break
                    case "voltageCalibration":
                        startVoltageCalibrationTest()
                        break
                    case "frequencyCalibration":
                        startFrequencyCalibrationTest()
                        break
                }
                autoTestRetryType = ""
            } else if (isStaticParamsStep) {
                // 静态参数步骤完成，隐藏等待提示框
                hideWaitingPopup()
                isStaticParamsStep = false
                onAutoTestStepCompleted()
            } else {
                // 其他步骤，隐藏提示框后调用 startNextAutoTest
                hideWaitingPopup()
                startNextAutoTest()
            }
        }
    }
    
    /**
     * 一键测试导出定时器
     * 功能：在所有测试完成后延迟2秒显示导出对话框
     * 用途：给用户留出时间看到"测试完成"的提示后再显示导出对话框
     */
    Timer {
        id: autoTestExportTimer
        interval: 2000
        repeat: false
        onTriggered: {
            showExportDialog = true
        }
    }

    /**
     * 一键测试标签切换定时器
     * 功能：在切换到下一个功率标签后等待用户配置的时间
     * 等待时间：用户可在一键测试设置项中配置（单位：分钟）
     * 用途：确保设备在切换功率后有足够的时间稳定下来
     */
    Timer {
        id: autoTestTabSwitchTimer
        interval: 12000
        repeat: false
        onTriggered: {
            // 隐藏提示框后开始下一个标签的测试
            hideWaitingPopup()
            startNextAutoTest()
        }
    }
    
    /**
     * 解析整定测试响应数据
     * 功能：解析从设备接收到的电压或频率整定测试的十六进制数据
     * @param {string} hexData - 接收到的十六进制数据字符串
     * @returns {boolean} 解析是否成功
     * 
     * 解析内容：
     * 1. 校验数据长度和格式
     * 2. 验证校验码
     * 3. 解析基准相（A相/B相/C相）
     * 4. 根据当前校准类型解析最大值和最小值（IEEE754浮点数格式）
     */
    function parseCalibrationTestResponse(hexData) {
        var bytes = hexData.trim().split(" ")
        if (bytes.length !== 21) {
            return false
        }
        
        if (bytes[0] !== "AA" || bytes[1] !== "01" || bytes[2] !== "74") {
            return false
        }
        
        // 计算校验码
        var checksum = 0
        for (var i = 0; i < 20; i++) {
            checksum += parseInt(bytes[i], 16)
        }
        checksum = checksum % 256
        var receivedChecksum = parseInt(bytes[20], 16)
        if (checksum !== receivedChecksum) {
            console.log("校验码错误: 计算值=" + checksum.toString(16) + ", 接收值=" + receivedChecksum.toString(16))
            return false
        }
        
        var refPhaseByte = parseInt(bytes[3], 16)
        var refPhaseStr = ""
        if (refPhaseByte === 0) {
            refPhaseStr = "A相"
        } else if (refPhaseByte === 1) {
            refPhaseStr = "B相"
        } else if (refPhaseByte === 2) {
            refPhaseStr = "C相"
        } else {
            refPhaseStr = "未知"
        }
        
        if (currentCalibrationType === "voltage") {
            voltageCalibrationRefPhase = refPhaseStr
            voltageCalibrationUmax = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7])
            voltageCalibrationUmin = parseIEEE754Float(bytes[8] + " " + bytes[9] + " " + bytes[10] + " " + bytes[11])
        } else if (currentCalibrationType === "frequency") {
            frequencyCalibrationRefPhase = refPhaseStr
            frequencyCalibrationFmax = parseIEEE754Float(bytes[12] + " " + bytes[13] + " " + bytes[14] + " " + bytes[15])
            frequencyCalibrationFmin = parseIEEE754Float(bytes[16] + " " + bytes[17] + " " + bytes[18] + " " + bytes[19])
        }
        
        return true
    }

    /**
     * 保存测试数据到历史记录
     * 功能：根据当前测试类型，将测试数据保存到testDataHistory对象中
     * 
     * 保存内容：
     * 1. 波动实验：计算并保存电压波动率和频率波动率
     *    公式：δ% = (Max - Min) / (Max + Min) * 100%
     * 2. 突加/突卸实验：保存电压、频率、电流的瞬态参数
     * 3. 谐波实验：保存波形数据和谐波分析数据
     * 
     * 最后调用saveCurrentTabData保存到当前标签页数据
     */
    function saveTestData() {
        if (currentTestType === "wave" && waveTestRefPhase !== "") {
            // 计算电压波动率 δUb%=(Max - Min) / (Max + Min)*100%
            var voltageMax = waveTestVoltageMax
            var voltageMin = waveTestVoltageMin
            var voltageVolatility = 0
            if (voltageMax + voltageMin > 0) {
                voltageVolatility = ((voltageMax - voltageMin) / (voltageMax + voltageMin)) * 100
            }
            
            // 计算频率波动率 δFb%=(Max - Min) / (Max + Min)*100%
            var frequencyMax = waveTestFrequencyMax
            var frequencyMin = waveTestFrequencyMin
            var frequencyVolatility = 0
            if (frequencyMax + frequencyMin > 0) {
                frequencyVolatility = ((frequencyMax - frequencyMin) / (frequencyMax + frequencyMin)) * 100
            }
            
            testDataHistory["wave"] = {
                "refPhase": waveTestRefPhase,
                "voltageMax": waveTestVoltageMax,
                "voltageMin": waveTestVoltageMin,
                "voltageVolatility": voltageVolatility,
                "frequencyMax": waveTestFrequencyMax,
                "frequencyMin": waveTestFrequencyMin,
                "frequencyVolatility": frequencyVolatility,
                "status": waveTestStatus
            }
        } else if (currentTestType === "suddenAdd" && suddenAddTestRefPhase !== "") {
            testDataHistory["suddenAdd"] = {
                "refPhase": suddenAddTestRefPhase,
                "voltageTolerance": suddenAddTestTolerance,
                "voltageStableTime": suddenAddTestStableTime,
                "voltageExtremeValue": suddenAddTestExtremeValue,
                "voltageMultiplier": suddenAddTestMultiplier,
                "frequencyTolerance": suddenAddFrequencyTolerance,
                "frequencyStableTime": suddenAddFrequencyStableTime,
                "frequencyExtremeValue": suddenAddFrequencyExtremeValue,
                "ratedNoLoadFrequency": suddenAddRatedNoLoadFrequency,
                "currentTolerance": suddenAddCurrentTolerance,
                "currentStableTime": suddenAddCurrentStableTime,
                "currentExtremeValue": suddenAddCurrentExtremeValue,
                "currentMultiplier": suddenAddCurrentMultiplier,
                "status": suddenAddTestStatus
            }
        } else if (currentTestType === "suddenLoad" && suddenLoadTestRefPhase !== "") {
            testDataHistory["suddenLoad"] = {
                "refPhase": suddenLoadTestRefPhase,
                "voltageTolerance": suddenLoadTestTolerance,
                "voltageStableTime": suddenLoadTestStableTime,
                "voltageExtremeValue": suddenLoadTestExtremeValue,
                "voltageMultiplier": suddenLoadTestMultiplier,
                "frequencyTolerance": suddenLoadFrequencyTolerance,
                "frequencyStableTime": suddenLoadFrequencyStableTime,
                "frequencyExtremeValue": suddenLoadFrequencyExtremeValue,
                "ratedNoLoadFrequency": suddenLoadRatedNoLoadFrequency,
                "currentTolerance": suddenLoadCurrentTolerance,
                "currentStableTime": suddenLoadCurrentStableTime,
                "currentExtremeValue": suddenLoadCurrentExtremeValue,
                "currentMultiplier": suddenLoadCurrentMultiplier,
                "status": suddenLoadTestStatus
            }
        } else if (currentTestType === "harmonic" && harmonicTestRefPhase !== "") {
            testDataHistory["harmonic"] = {
                "refPhase": harmonicTestRefPhase,
                "voltageWaveform": harmonicTestVoltageWaveform,
                "currentWaveform": harmonicTestCurrentWaveform,
                "voltageHarmonics": harmonicTestVoltageHarmonics,
                "currentHarmonics": harmonicTestCurrentHarmonics,
                "voltageDistortionRate": harmonicTestVoltageDistortionRate,
                "status": harmonicTestStatus
            }
        }
        saveCurrentTabData()
    }

    /**
     * 加载测试历史数据
     * 功能：从testDataHistory中加载指定类型的测试数据到当前页面显示
     * @param {string} testType - 测试类型 ("wave", "suddenAdd", "suddenLoad", "harmonic")
     * 
     * 加载内容：
     * - 波动实验：基准相、电压最大值/最小值、频率最大值/最小值
     * - 突加/突卸实验：基准相、电压/频率/电流的瞬态参数
     * - 谐波实验：基准相、波形数据、谐波分析数据
     */
    function loadTestData(testType) {
        var data = testDataHistory[testType]
        if (!data) return
        
        if (testType === "wave") {
            waveTestRefPhase = data["refPhase"]
            waveTestVoltageMax = data["voltageMax"]
            waveTestVoltageMin = data["voltageMin"]
            waveTestFrequencyMax = data["frequencyMax"]
            waveTestFrequencyMin = data["frequencyMin"]
            waveTestStatus = data["status"]
            currentTestType = "wave"
        } else if (testType === "suddenAdd") {
            suddenAddTestRefPhase = data["refPhase"]
            suddenAddTestTolerance = data["voltageTolerance"]
            suddenAddTestStableTime = data["voltageStableTime"]
            suddenAddTestExtremeValue = data["voltageExtremeValue"]
            suddenAddTestMultiplier = data["voltageMultiplier"]
            suddenAddFrequencyTolerance = data["frequencyTolerance"]
            suddenAddFrequencyStableTime = data["frequencyStableTime"]
            suddenAddFrequencyExtremeValue = data["frequencyExtremeValue"]
            suddenAddRatedNoLoadFrequency = data["ratedNoLoadFrequency"]
            suddenAddCurrentTolerance = data["currentTolerance"]
            suddenAddCurrentStableTime = data["currentStableTime"]
            suddenAddCurrentExtremeValue = data["currentExtremeValue"]
            suddenAddCurrentMultiplier = data["currentMultiplier"]
            suddenAddTestStatus = data["status"]
            currentTestType = "suddenAdd"
        } else if (testType === "suddenLoad") {
            suddenLoadTestRefPhase = data["refPhase"]
            suddenLoadTestTolerance = data["voltageTolerance"]
            suddenLoadTestStableTime = data["voltageStableTime"]
            suddenLoadTestExtremeValue = data["voltageExtremeValue"]
            suddenLoadTestMultiplier = data["voltageMultiplier"]
            suddenLoadFrequencyTolerance = data["frequencyTolerance"]
            suddenLoadFrequencyStableTime = data["frequencyStableTime"]
            suddenLoadFrequencyExtremeValue = data["frequencyExtremeValue"]
            suddenLoadRatedNoLoadFrequency = data["ratedNoLoadFrequency"]
            suddenLoadCurrentTolerance = data["currentTolerance"]
            suddenLoadCurrentStableTime = data["currentStableTime"]
            suddenLoadCurrentExtremeValue = data["currentExtremeValue"]
            suddenLoadCurrentMultiplier = data["currentMultiplier"]
            suddenLoadTestStatus = data["status"]
            currentTestType = "suddenLoad"
        } else if (testType === "harmonic") {
            harmonicTestRefPhase = data["refPhase"]
            harmonicTestVoltageWaveform = data["voltageWaveform"] || []
            harmonicTestCurrentWaveform = data["currentWaveform"] || []
            harmonicTestVoltageHarmonics = data["voltageHarmonics"] || []
            harmonicTestCurrentHarmonics = data["currentHarmonics"] || []
            harmonicTestVoltageDistortionRate = data["voltageDistortionRate"] || 0
            harmonicTestStatus = data["status"]
            currentTestType = "harmonic"
        }
    }

    // 波动实验启动定时器 - 60秒后请求数据
    Timer {
        id: waveTestStartTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (waveTestInProgress && !waveTestDataRequested) {
                requestWaveTestData()
            }
        }
    }

    /**
     * 波动实验数据请求超时定时器
     * 功能：如果30秒内没有收到波动实验数据，标记为读取失败并停止实验
     * 超时时间：30000毫秒（30秒）
     */
    Timer {
        id: waveTestDataRequestTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (waveTestInProgress) {
                waveTestStatus = "读取失败，请重试"
                stopWaveTest()
            }
        }
    }

    /**
     * 波动实验重试定时器
     * 功能：在数据请求失败后，等待5秒后重试请求数据
     * 等待时间：5000毫秒（5秒）
     * 最大重试次数：6次
     */
    Timer {
        id: waveTestRetryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (waveTestInProgress) {
                waveTestRetryCount++
                if (waveTestRetryCount <= 6) {
                    waveTestStatus = "重试第 " + waveTestRetryCount + " 次..."
                    sendHexMessage("55 01 61 B7")
                    waveTestDataRequestTimer.restart()
                } else {
                    waveTestStatus = "读取失败，请重试"
                    stopWaveTest()
                }
            }
        }
    }

    /**
     * 突加实验启动定时器
     * 功能：在发送突加实验命令后，等待20秒再请求数据
     * 等待时间：20000毫秒（20秒）
     * 用途：给设备足够时间完成突加实验
     */
    Timer {
        id: suddenAddTestStartTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (suddenAddTestInProgress && !suddenAddTestDataRequested) {
                requestSuddenAddTestData()
            }
        }
    }

    /**
     * 突加实验等待定时器
     * 功能：在卸载功率后，等待12秒再发送突加实验命令
     * 等待时间：12000毫秒（12秒）
     * 用途：确保设备在卸载后有足够时间稳定
     */
    Timer {
        id: suddenAddTestWaitTimer
        interval: 12000
        repeat: false
        onTriggered: {
            console.log("突加实验：12秒定时器触发，准备发送突加实验报文")
            suddenAddTestStatus = "正在启动突加实验..."
            sendHexMessage("55 01 62 B8")
            suddenAddTestStartTimer.start()
        }
    }

    /**
     * 突加实验数据请求超时定时器
     * 功能：如果30秒内没有收到突加实验数据，标记为读取失败并停止实验
     * 超时时间：30000毫秒（30秒）
     */
    Timer {
        id: suddenAddTestDataRequestTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (suddenAddTestInProgress) {
                suddenAddTestStatus = "读取失败，请重试"
                stopSuddenAddTest()
            }
        }
    }

    /**
     * 突加实验重试定时器
     * 功能：在数据请求失败后，等待5秒后重试请求数据
     * 等待时间：5000毫秒（5秒）
     * 最大重试次数：6次
     */
    Timer {
        id: suddenAddTestRetryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (suddenAddTestInProgress) {
                suddenAddTestRetryCount++
                if (suddenAddTestRetryCount <= 6) {
                    suddenAddTestStatus = "重试第 " + suddenAddTestRetryCount + " 次..."
                    sendHexMessage("55 01 64 BA")
                    suddenAddTestDataRequestTimer.restart()
                } else {
                    suddenAddTestStatus = "读取失败，请重试"
                    stopSuddenAddTest()
                }
            }
        }
    }

    /**
     * 突卸实验启动定时器
     * 功能：在发送突卸实验命令后，等待20秒再请求数据
     * 等待时间：20000毫秒（20秒）
     * 用途：给设备足够时间完成突卸实验
     */
    Timer {
        id: suddenLoadTestStartTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (suddenLoadTestInProgress && !suddenLoadTestDataRequested) {
                requestSuddenLoadTestData()
            }
        }
    }

    /**
     * 突卸实验等待定时器
     * 功能：在加载功率后，等待12秒再发送突卸实验命令
     * 等待时间：12000毫秒（12秒）
     * 用途：确保设备在加载后有足够时间稳定
     */
    Timer {
        id: suddenLoadTestWaitTimer
        interval: 12000
        repeat: false
        onTriggered: {
            console.log("突卸实验：12秒定时器触发，准备发送突卸实验报文")
            suddenLoadTestStatus = "正在启动突卸实验..."
            sendHexMessage("55 01 63 B9")
            suddenLoadTestStartTimer.start()
        }
    }

    /**
     * 突卸实验数据请求超时定时器
     * 功能：如果30秒内没有收到突卸实验数据，标记为读取失败并停止实验
     * 超时时间：30000毫秒（30秒）
     */
    Timer {
        id: suddenLoadTestDataRequestTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (suddenLoadTestInProgress) {
                suddenLoadTestStatus = "读取失败，请重试"
                stopSuddenLoadTest()
            }
        }
    }

    /**
     * 突卸实验重试定时器
     * 功能：在数据请求失败后，等待5秒后重试请求数据
     * 等待时间：5000毫秒（5秒）
     * 最大重试次数：6次
     */
    Timer {
        id: suddenLoadTestRetryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (suddenLoadTestInProgress) {
                suddenLoadTestRetryCount++
                if (suddenLoadTestRetryCount <= 6) {
                    suddenLoadTestStatus = "重试第 " + suddenLoadTestRetryCount + " 次..."
                    sendHexMessage("55 01 67 BC")
                    suddenLoadTestDataRequestTimer.restart()
                } else {
                    suddenLoadTestStatus = "读取失败，请重试"
                    stopSuddenLoadTest()
                }
            }
        }
    }

    /**
     * 谐波实验启动定时器
     * 功能：在发送谐波实验命令后，等待60秒再请求波形数据
     * 等待时间：60000毫秒（60秒）
     * 用途：给设备足够时间完成谐波实验
     */
    Timer {
        id: harmonicTestStartTimer
        interval: 60000
        repeat: false
        onTriggered: {
            if (harmonicTestInProgress && !harmonicTestDataRequested) {
                harmonicTestStep = 3
                requestHarmonicWaveformData()
            }
        }
    }

    /**
     * 谐波实验数据请求超时定时器
     * 功能：如果30秒内没有收到谐波实验数据，标记为读取失败并停止实验
     * 超时时间：30000毫秒（30秒）
     */
    Timer {
        id: harmonicTestDataRequestTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (harmonicTestInProgress) {
                harmonicTestStatus = "读取失败，请重试"
                stopHarmonicTest()
            }
        }
    }

    /**
     * 谐波实验重试定时器
     * 功能：在数据请求失败后，等待5秒后重试请求数据
     * 等待时间：5000毫秒（5秒）
     * 最大重试次数：6次
     * 重试内容：根据当前步骤请求波形数据、全量数据或退出谐波模式
     */
    Timer {
        id: harmonicTestRetryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (harmonicTestInProgress) {
                harmonicTestRetryCount++
                if (harmonicTestRetryCount <= 6) {
                    harmonicTestStatus = "重试第 " + harmonicTestRetryCount + " 次..."
                    if (harmonicTestStep === 3) {
                        sendHexMessage("55 01 71 C7")
                    } else if (harmonicTestStep === 4) {
                        sendHexMessage("55 01 73 C9")
                    } else if (harmonicTestStep === 5) {
                        sendHexMessage("55 01 72 C8")
                    }
                    harmonicTestDataRequestTimer.restart()
                } else {
                    harmonicTestStatus = "读取失败，请重试"
                    stopHarmonicTest()
                }
            }
        }
    }

    /**
     * 整定测试启动定时器
     * 功能：在发送整定测试命令后，等待105秒再请求数据
     * 等待时间：105000毫秒（105秒）
     * 用途：给设备足够时间完成电压或频率整定
     */
    Timer {
        id: calibrationTestStartTimer
        interval: 105000
        repeat: false
        onTriggered: {
            if (calibrationTestInProgress && !calibrationTestDataRequested) {
                requestCalibrationTestData()
            }
        }
    }

    /**
     * 整定测试数据请求超时定时器
     * 功能：如果30秒内没有收到整定测试数据，标记为读取失败并停止实验
     * 超时时间：30000毫秒（30秒）
     */
    Timer {
        id: calibrationTestDataRequestTimer
        interval: 30000
        repeat: false
        onTriggered: {
            if (calibrationTestInProgress) {
                if (currentCalibrationType === "voltage") {
                    voltageCalibrationStatus = "读取失败，请重试"
                } else if (currentCalibrationType === "frequency") {
                    frequencyCalibrationStatus = "读取失败，请重试"
                }
                stopCalibrationTest()
            }
        }
    }

    /**
     * 整定测试重试定时器
     * 功能：在数据请求失败后，等待5秒后重试请求数据
     * 等待时间：5000毫秒（5秒）
     * 最大重试次数：6次
     */
    Timer {
        id: calibrationTestRetryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (calibrationTestInProgress) {
                calibrationTestRetryCount++
                if (calibrationTestRetryCount <= 6) {
                    if (currentCalibrationType === "voltage") {
                        voltageCalibrationStatus = "重试第 " + calibrationTestRetryCount + " 次..."
                    } else if (currentCalibrationType === "frequency") {
                        frequencyCalibrationStatus = "重试第 " + calibrationTestRetryCount + " 次..."
                    }
                    sendHexMessage("55 01 74 CA")
                    calibrationTestDataRequestTimer.restart()
                } else {
                    if (currentCalibrationType === "voltage") {
                        voltageCalibrationStatus = "读取失败，请重试"
                    } else if (currentCalibrationType === "frequency") {
                        frequencyCalibrationStatus = "读取失败，请重试"
                    }
                    stopCalibrationTest()
                }
            }
        }
    }

    /**
     * 突加实验功率发送定时器
     * 功能：在突加实验启动后，等待1.2秒再发送功率报文
     * 等待时间：1200毫秒（1.2秒）
     * 用途：确保设备准备好接收功率命令
     */
    Timer {
        id: suddenAddPowerSendTimer
        interval: 1200
        repeat: false
        onTriggered: {
            console.log("突加实验：1.2秒定时器触发，准备发送功率报文")
            sendPowerByCurrentTab()
        }
    }

    /**
     * 突卸实验卸载定时器
     * 功能：在突卸实验启动后，等待1.2秒再发送卸载报文
     * 等待时间：1200毫秒（1.2秒）
     * 用途：确保设备准备好接收卸载命令
     */
    Timer {
        id: suddenLoadUnloadTimer
        interval: 1200
        repeat: false
        onTriggered: {
            console.log("突卸实验：1.2秒定时器触发，准备发送卸载报文")
            if (modbusManager) {
                modbusManager.writeCurrent(0, 1)
                console.log("突卸实验：已发送卸载报文（功率0）")
            }
        }
    }

    /**
     * 等待对话框倒计时定时器
     * 功能：每秒减少等待对话框的剩余时间
     * 间隔时间：1000毫秒（1秒）
     * 重复：true，每秒触发一次
     * 用途：更新等待对话框中显示的剩余时间
     */
    Timer {
        id: waitingDialogTimer
        interval: 1000
        repeat: true
        onTriggered: {
            waitingDialogRemaining--
            if (waitingDialogRemaining <= 0) {
                hideWaitingPopup()
            }
        }
    }

    /**
     * 等待对话框组件
     * 功能：显示带倒计时的等待弹窗
     * 包含内容：
     * - 半透明黑色遮罩层
     * - 居中显示的对话框
     * - 标题文本
     * - BusyIndicator旋转图标
     * - 倒计时显示
     */
    Component {
        id: waitingDialogComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: showWaitingDialog

            Rectangle {
                id: waitingDialog
                width: 320
                height: 200
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Text {
                        text: waitingDialogTitle
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    BusyIndicator {
                        id: busyIndicator
                        Layout.alignment: Qt.AlignHCenter
                        running: true
                    }

                    Text {
                        text: "等待中... " + waitingDialogRemaining + " 秒"
                        color: theme.textColor
                        font.pixelSize: 16
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    /**
     * 一键测试设置对话框组件
     * 功能：显示一键测试配置界面
     * 包含内容：
     * - 半透明黑色遮罩层
     * - 居中显示的配置对话框
     * - 功率标签切换等待时间配置
     * - 测试项目选择和排序
     */
    Component {
        id: testConfigDialogComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: showTestConfigDialog

            Rectangle {
                id: testConfigDialog
                width: 480
                height: 600
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "一键测试设置项"
                        color: theme.textColor
                        font.pixelSize: 20
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "选择要执行的实验并调整顺序"
                        color: theme.textColor
                        font.pixelSize: 14
                        Layout.alignment: Qt.AlignHCenter
                    }

                    /**
                     * 功率标签切换等待时间配置行
                     * 功能：用户可在此设置一键测试在不同功率标签之间切换时的等待时间
                     * 说明：等待时间单位为分钟，范围0-60分钟
                     * 验证：使用IntValidator确保输入值在有效范围内
                     */
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "功率标签切换等待时间（分钟）："
                            color: theme.textColor
                            font.pixelSize: 14
                        }

                        TextField {
                            id: waitTimeInput
                            text: powerTabSwitchWaitTime.toString()
                            Layout.preferredWidth: 80
                            inputMethodHints: Qt.ImhDigitsOnly
                            // 验证输入范围：0-60分钟
                            validator: IntValidator { bottom: 0; top: 60 }
                            onTextChanged: {
                                var value = parseInt(text)
                                if (!isNaN(value) && value >= 0 && value <= 60) {
                                    powerTabSwitchWaitTime = value
                                }
                            }
                        }
                    }

                    /**
                     * 测试项目配置列表滚动视图
                     * 功能：显示所有可用的测试项目，用户可：
                     * 1. 勾选/取消勾选来启用或禁用测试
                     * 2. 使用↑↓按钮调整测试的执行顺序
                     * 注意：已移除全选、全不选、重置按钮，因为总共只有7个选择框
                     */
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            id: testListColumn
                            spacing: 10
                            width: testConfigDialog.width - 60

                            Repeater {
                                id: testRepeater
                                model: {
                                    testConfigRefreshCounter
                                    return getSortedTests()
                                }

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 55
                                    color: theme.isDark ? "#2d2d2d" : "#f5f5f5"
                                    radius: 8

                                    // 测试项属性
                                    property int testIndex: index
                                    property string testId: modelData.id
                                    property string testName: modelData.name
                                    property bool testEnabled: modelData.enabled
                                    property int testOrder: modelData.order

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 12

                                        /**
                                         * 自定义复选框
                                         * 功能：启用或禁用该测试项目
                                         */
                                        Rectangle {
                                            id: customCheckbox
                                            width: 24
                                            height: 24
                                            radius: 4
                                            border.color: theme.focusColor
                                            border.width: 2
                                            color: testEnabled ? theme.focusColor : "transparent"

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    toggleTestEnabledById(testId)
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: testEnabled ? "✓" : ""
                                                color: "white"
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: testName
                                            color: theme.textColor
                                            font.pixelSize: 14
                                            Layout.fillWidth: true
                                        }

                                        /**
                                         * 上移按钮
                                         * 功能：将测试项目向上移动一位
                                         * 启用条件：非第一个测试项
                                         */
                                        EButton {
                                            text: "↑"
                                            size: "xs"
                                            containerColor: theme.secondaryColor
                                            textColor: theme.textColor
                                            enabled: testIndex > 0
                                            shadowEnabled: false
                                            onClicked: {
                                                moveTestUpById(testId)
                                            }
                                        }

                                        /**
                                         * 下移按钮
                                         * 功能：将测试项目向下移动一位
                                         * 启用条件：非最后一个测试项
                                         */
                                        EButton {
                                            text: "↓"
                                            size: "xs"
                                            containerColor: theme.secondaryColor
                                            textColor: theme.textColor
                                            enabled: testIndex < availableTests.length - 1
                                            shadowEnabled: false
                                            onClicked: {
                                                moveTestDownById(testId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }



                    EButton {
                        text: "确定"
                        size: "s"
                        containerColor: theme.isDark ? "#4CAF50" : "#4CAF50"
                        textColor: "white"
                        Layout.fillWidth: true
                        shadowEnabled: true
                        onClicked: {
                            showTestConfigDialog = false
                        }
                    }
                }
            }
        }
    }

    DataRecorder {
        id: dataRecorder
        
        onExportFinished: function(success, filePath) {
            exportInProgress = false
            if (success) {
                exportSuccessDialog.message = "测试报表已成功导出到：\n" + filePath
                exportSuccessDialog.open()
            } else {
                exportSuccessDialog.message = "导出失败，请检查文件路径是否被占用"
                exportSuccessDialog.open()
            }
        }
    }

    property string pendingExportFilePath: ""
    property bool pendingPreview: false
    property bool exportInProgress: false

    Timer {
        id: deviceParamsTimer
        interval: 5000
        repeat: false
        onTriggered: {
            console.log("设备参数读取超时，使用默认参数继续")
            deviceParamsCheckTimer.stop()
            deviceParamsReceived = true
            if (pendingPreview) {
                pendingPreview = false
                showReportPreview = true
            } else {
                proceedWithExport()
            }
        }
    }

    Timer {
        id: deviceParamsCheckTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (deviceParamsReceived) {
                deviceParamsCheckTimer.stop()
                deviceParamsTimer.stop()
                if (pendingPreview) {
                    pendingPreview = false
                    showReportPreview = true
                } else {
                    proceedWithExport()
                }
            }
        }
    }

    /**
     * 三相参数请求定时器
     * 功能：每秒请求一次三相参数数据
     * 间隔时间：1000毫秒（1秒）
     * 重复：true，每秒触发一次
     * 用途：在显示三相参数时自动刷新数据
     */
    Timer {
        id: threePhaseParamsTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (showThreePhaseParams) {
                requestThreePhaseParams()
            } else {
                threePhaseParamsTimer.stop()
            }
        }
    }

    /**
     * 继续导出报表
     * 功能：执行实际的报表导出操作
     * 执行步骤：
     * 1. 检查是否已有导出在进行中
     * 2. 检查文件路径是否有效
     * 3. 获取报表内容
     * 4. 根据选择的格式（PDF或CSV）调用相应的导出方法
     */
    function proceedWithExport() {
        if (exportInProgress) {
            console.log("导出已在进行中，跳过重复调用")
            return
        }
        
        if (pendingExportFilePath === "") {
            console.log("文件路径为空，跳过导出")
            return
        }
        
        console.log("开始导出报表，文件路径:", pendingExportFilePath)
        exportInProgress = true
        
        var reportContent = getReportContent()
        var filePathToUse = pendingExportFilePath
        pendingExportFilePath = ""
        
        if (selectedExportFormat === "pdf") {
            dataRecorder.exportTestReportToPdf(filePathToUse, reportContent)
        } else {
            dataRecorder.exportTestReport(filePathToUse, reportContent)
        }
    }

    /**
     * 文件保存对话框
     * 功能：让用户选择报表保存的文件路径和文件名
     * 支持格式：PDF和CSV
     * 对话框接受后：
     * - 处理文件路径（移除file:///前缀）
     * - 请求设备参数
     * - 启动设备参数请求定时器
     */
    LabsPlatform.FileDialog {
        id: fileSaveDialog
        title: "保存报表"
        fileMode: LabsPlatform.FileDialog.SaveFile
        defaultSuffix: selectedExportFormat === "pdf" ? "pdf" : "csv"
        nameFilters: selectedExportFormat === "pdf" ? ["PDF文件 (*.pdf)", "所有文件 (*)"] : ["CSV文件 (*.csv)", "所有文件 (*)"]
        onAccepted: {
            var filePath = fileSaveDialog.file.toString()
            if (filePath.startsWith("file:///")) {
                filePath = filePath.substring(8)
            }
            pendingExportFilePath = filePath
            exportInProgress = false
            deviceParamsRequested = false
            deviceParamsReceived = false
            requestDeviceParams()
            deviceParamsTimer.start()
            deviceParamsCheckTimer.start()
        }
    }

    /**
     * 导出成功提示对话框
     * 功能：在报表导出成功后显示提示信息
     */
    EAlertDialog {
        id: exportSuccessDialog
        title: "提示"
        message: ""
        confirmText: "确定"
        cancelText: ""
    }

    /**
     * 参数发送结果对话框组件
     * 功能：显示参数发送操作的结果提示
     * 包含内容：
     * - 半透明黑色遮罩层
     * - 居中显示的提示对话框
     * - 提示标题
     * - 结果消息文本
     * - 确定按钮
     */
    Component {
        id: parameterSendResultComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: true

            Rectangle {
                id: resultDialog
                width: 320
                height: 180
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "提示"
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: parameterSendResultMessage
                        color: theme.textColor
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    EButton {
                        text: "确定"
                        size: "s"
                        containerColor: theme.isDark ? "#2196F3" : "#2196F3"
                        textColor: "white"
                        shadowEnabled: true
                        Layout.alignment: Qt.AlignRight
                        onClicked: {
                            showParameterSendResult = false
                        }
                    }
                }
            }
        }
    }

    /**
     * 获取报表内容
     * 功能：生成测试报表的完整内容
     * 包含内容：
     * - 日期和时间
     * - 设备参数（额定电压、额定频率等）
     * - 测量参数（实测电压、实测频率等）
     * - 各类测试结果数据
     * - 计算的指标（电压波动率、频率波动率、电压整定范围等）
     * @returns {Object} 报表内容对象，包含所有测试数据和计算结果
     */
    function getReportContent() {
        var date = Qt.formatDateTime(new Date(), "yyyy-MM-dd")
        var time = Qt.formatDateTime(new Date(), "hh:mm:ss")
        
        var ratedVoltageToUse = (deviceParamsReceived && deviceRatedVoltage > 0) ? deviceRatedVoltage : paramSettings.ratedVoltage
        var ratedFrequencyToUse = (deviceParamsReceived && deviceRatedFrequency > 0) ? deviceRatedFrequency : paramSettings.ratedFrequency
        var noLoadFrequencyToUse = (deviceParamsReceived && deviceFrequencySteady > 0) ? deviceFrequencySteady : paramSettings.noLoadFrequency
        var measuredVoltageToUse = (deviceParamsReceived && deviceVoltageSteady > 0) ? deviceVoltageSteady : 0
        var measuredFrequencyToUse = (deviceParamsReceived && deviceFrequencySteady > 0) ? deviceFrequencySteady : 0
        
        var steadyVoltageDeviationStr = ""
        var steadyFrequencyDeviationStr = ""
        var voltageVolatilityStr = ""
        var frequencyVolatilityStr = ""
        var steadyFrequencyBandStr = "" // 稳态频率带 βf
        var allWaveVoltageMax = 0
        var allWaveVoltageMin = Number.MAX_VALUE
        var voltageSettingRangeStr = ""
        
        // 定义哪些章节原来有前缀
        var sectionsWithPrefix = ["techSpec", "testItems", "staticParams", "transientTest"]
        
        // 收集所有启用且有前缀的章节
        var enabledSectionsWithPrefix = []
        for (var i = 0; i < sectionsWithPrefix.length; i++) {
            if (isReportSectionEnabled(sectionsWithPrefix[i])) {
                enabledSectionsWithPrefix.push(sectionsWithPrefix[i])
            }
        }
        
        // 生成章节编号映射
        var sectionNumberMap = {}
        var chineseNumbers = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        for (var j = 0; j < enabledSectionsWithPrefix.length; j++) {
            sectionNumberMap[enabledSectionsWithPrefix[j]] = chineseNumbers[j]
        }
        
        // 获取章节编号的辅助函数
        function getSectionNumber(sectionId) {
            if (sectionNumberMap[sectionId] !== undefined) {
                return "（" + sectionNumberMap[sectionId] + "）"
            }
            return ""
        }
        
        // 计算所有稳态工况下的电压最大值和最小值（所有功率下的波动实验中的电压最大值和最小值）
        var allVoltageMax = 0
        var allVoltageMin = Number.MAX_VALUE
        for (var j = 0; j < tabDataStorage.length; j++) {
            var tabData = tabDataStorage[j]
            if (tabData.waveTestRefPhase !== "") {
                if (tabData.waveTestVoltageMax > allVoltageMax) {
                    allVoltageMax = tabData.waveTestVoltageMax
                }
                if (tabData.waveTestVoltageMin < allVoltageMin) {
                    allVoltageMin = tabData.waveTestVoltageMin
                }
                // 计算电压整定范围（电压数值）
                if (tabData.waveTestVoltageMax > allWaveVoltageMax) {
                    allWaveVoltageMax = tabData.waveTestVoltageMax
                }
                if (tabData.waveTestVoltageMin < allWaveVoltageMin) {
                    allWaveVoltageMin = tabData.waveTestVoltageMin
                }
            }
        }
        
        // 生成电压整定范围字符串（电压数值）
        if (allWaveVoltageMax > 0 && allWaveVoltageMin < Number.MAX_VALUE) {
            voltageSettingRangeStr = allWaveVoltageMin.toFixed(0) + "~" + allWaveVoltageMax.toFixed(0)
        }
        
        // 计算稳态电压偏差 δU = (Umax - Umin) / (2 × Un) × 100%
        if (allVoltageMax > 0 && allVoltageMin < Number.MAX_VALUE && ratedVoltageToUse > 0) {
            var steadyVoltageDeviation = ((allVoltageMax - allVoltageMin) / (2 * ratedVoltageToUse)) * 100
            steadyVoltageDeviationStr = steadyVoltageDeviation.toFixed(2)
        }
        
        // 找到第二个0%负载的数据
        var zeroLoadCount = 0
        var zeroLoadFrequency = 0
        for (var i = 0; i < tabDataStorage.length; i++) {
            var loadLabel = tabLabels[i]
            if (loadLabel === "0%") {
                zeroLoadCount++
                if (zeroLoadCount === 2) {
                    var data = tabDataStorage[i]
                    if (data.staticThreePhaseParamsReceived) {
                        zeroLoadFrequency = data.staticFrequency
                    }
                    break
                }
            }
        }
        
        // 计算频率降
        if (zeroLoadFrequency > 0 && ratedFrequencyToUse > 0) {
            var steadyFrequencyDeviation = ((zeroLoadFrequency - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
            steadyFrequencyDeviationStr = steadyFrequencyDeviation.toFixed(2)
        }
        
        // 计算波动实验的波动率和稳态频率带
        // 稳态频率带 βf=(f.Max - f.Min) *100%/ 额定频率Fr
        if (testDataHistory["wave"] !== null) {
            var waveData = testDataHistory["wave"]
            if (waveData["voltageVolatility"] !== undefined) {
                voltageVolatilityStr = waveData["voltageVolatility"].toFixed(2)
            }
            if (waveData["frequencyVolatility"] !== undefined) {
                frequencyVolatilityStr = waveData["frequencyVolatility"].toFixed(2)
            }
            // 计算稳态频率带：使用波动实验中的频率最大值和最小值
            if (waveData["frequencyMax"] !== undefined && waveData["frequencyMin"] !== undefined && ratedFrequencyToUse > 0) {
                var fMax = waveData["frequencyMax"]
                var fMin = waveData["frequencyMin"]
                var steadyFrequencyBand = ((fMax - fMin) * 100) / ratedFrequencyToUse
                steadyFrequencyBandStr = steadyFrequencyBand.toFixed(2)
            }
        }
        
        var suddenAddVoltageDeviation = ""
        var suddenAddVoltageStableTime = ""
        var suddenAddFrequencyDeviation = ""
        var suddenAddFrequencyStableTime = ""
        if (testDataHistory["suddenAdd"] !== null) {
            var suddenAddVoltageExtremeRaw = testDataHistory["suddenAdd"]["voltageExtremeValue"] !== undefined ? testDataHistory["suddenAdd"]["voltageExtremeValue"] : 0
            var suddenAddFrequencyExtremeRaw = testDataHistory["suddenAdd"]["frequencyExtremeValue"] !== undefined ? testDataHistory["suddenAdd"]["frequencyExtremeValue"] : 0
            var suddenAddVoltageExtreme = suddenAddVoltageExtremeRaw / 10
            var suddenAddFrequencyExtreme = suddenAddFrequencyExtremeRaw / 100
            if (ratedVoltageToUse > 0 && suddenAddVoltageExtreme > 0) {
                var suddenAddVoltageDeviationValue = ((suddenAddVoltageExtreme - ratedVoltageToUse) / ratedVoltageToUse) * 100
                suddenAddVoltageDeviation = suddenAddVoltageDeviationValue.toFixed(2)
            }
            if (ratedFrequencyToUse > 0 && suddenAddFrequencyExtreme > 0) {
                var suddenAddFrequencyDeviationValue = ((suddenAddFrequencyExtreme - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
                suddenAddFrequencyDeviation = suddenAddFrequencyDeviationValue.toFixed(2)
            }
            suddenAddVoltageStableTime = testDataHistory["suddenAdd"]["voltageStableTime"] !== undefined ? (testDataHistory["suddenAdd"]["voltageStableTime"] / 1000).toFixed(3) : ""
            suddenAddFrequencyStableTime = testDataHistory["suddenAdd"]["frequencyStableTime"] !== undefined ? (testDataHistory["suddenAdd"]["frequencyStableTime"] / 1000).toFixed(3) : ""
        }
        
        var suddenLoadVoltageDeviation = ""
        var suddenLoadVoltageStableTime = ""
        var suddenLoadFrequencyDeviation = ""
        var suddenLoadFrequencyStableTime = ""
        if (testDataHistory["suddenLoad"] !== null) {
            var suddenLoadVoltageExtremeRaw = testDataHistory["suddenLoad"]["voltageExtremeValue"] !== undefined ? testDataHistory["suddenLoad"]["voltageExtremeValue"] : 0
            var suddenLoadFrequencyExtremeRaw = testDataHistory["suddenLoad"]["frequencyExtremeValue"] !== undefined ? testDataHistory["suddenLoad"]["frequencyExtremeValue"] : 0
            var suddenLoadVoltageExtreme = suddenLoadVoltageExtremeRaw / 10
            var suddenLoadFrequencyExtreme = suddenLoadFrequencyExtremeRaw / 100
            if (ratedVoltageToUse > 0 && suddenLoadVoltageExtreme > 0) {
                var suddenLoadVoltageDeviationValue = ((suddenLoadVoltageExtreme - ratedVoltageToUse) / ratedVoltageToUse) * 100
                suddenLoadVoltageDeviation = suddenLoadVoltageDeviationValue.toFixed(2)
            }
            if (ratedFrequencyToUse > 0 && suddenLoadFrequencyExtreme > 0) {
                var suddenLoadFrequencyDeviationValue = ((suddenLoadFrequencyExtreme - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
                suddenLoadFrequencyDeviation = suddenLoadFrequencyDeviationValue.toFixed(2)
            }
            suddenLoadVoltageStableTime = testDataHistory["suddenLoad"]["voltageStableTime"] !== undefined ? (testDataHistory["suddenLoad"]["voltageStableTime"] / 1000).toFixed(3) : ""
            suddenLoadFrequencyStableTime = testDataHistory["suddenLoad"]["frequencyStableTime"] !== undefined ? (testDataHistory["suddenLoad"]["frequencyStableTime"] / 1000).toFixed(3) : ""
        }
        
        var voltageDistortionRateStr = ""
        if (testDataHistory["harmonic"] !== null) {
            var harmonicData = testDataHistory["harmonic"]
            if (harmonicData["voltageDistortionRate"] !== undefined && harmonicData["voltageDistortionRate"] > 0) {
                voltageDistortionRateStr = harmonicData["voltageDistortionRate"].toFixed(4)
            }
        }
        
        var reportContent = ""
        
        reportContent += ",机组稳态性能测试报告,\n"
        reportContent += "\n"
        reportContent += "标准：GB/T 2820.1-2009,试验日期：," + date + ",试验时间：," + time + "\n"
        reportContent += "\n"
        
        // 技术规格
        if (isReportSectionEnabled("techSpec")) {
            var techSpecNumber = getSectionNumber("techSpec")
            reportContent += " " + techSpecNumber + "技术规格,,,,,,,,,,,,,,,,,,,,,,,,,,\n"
            reportContent += "\n"
            reportContent += "1、机组型号,0,机组编号,0,视在功率,0,额定功率," + paramSettings.ratedPower + ",功率因数," + paramSettings.powerFactor + ",生产日期,\n"
            reportContent += "2、额定频率," + ratedFrequencyToUse + ",额定电压," + ratedVoltageToUse + ",额定电流,0,控制屏型号,,控制屏编号,,生产日期,\n"
            reportContent += "3、引擎型号,,引擎编号,,原产地,,出厂日期,,调速器," + paramSettings.governor +",,\n"
            reportContent += "4、电机型号,,电机编号,,原产地,,出厂日期,,励磁方式," + paramSettings.excitationMode + ",AVR型号,\n"
            reportContent += "\n"
        }
        
        // 试验项目
        if (isReportSectionEnabled("testItems")) {
            var testItemsNumber = getSectionNumber("testItems")
            reportContent += " " + testItemsNumber + "试验项目,,,,,,,,,,,,,,,,,,,,,,,,,,\n"
            reportContent += "\n"
            reportContent += "1、相对湿度(%)：," + paramSettings.relativeHumidity + ",环境温度(℃)：," + paramSettings.ambientTemperature + ",大气压力(kPa)：," + paramSettings.atmosphericPressure + ",检查机组外观：, \n"
            reportContent += "2、检查指示仪表,,检查超速停机,,检查高水温保护,,检查高缸温保护,\n"
            reportContent += "检查低油压保护,,检查紧急停机,,检查电池充电,,,\n"
            reportContent += "3、测量电枢绕组对地绝缘电阻(Ω),,测量励磁绕组对地绝缘电阻(Ω),,测量副励磁绕组对地绝缘电阻(Ω),\n"
            reportContent += "绝缘介质强度试验,,检查相序,,检查常温启动性能（启动三次）,\n"
            reportContent += "\n"
        }
        
        // 测量电压和额定频率的稳态参数
        if (isReportSectionEnabled("staticParams")) {
            var staticParamsNumber = getSectionNumber("staticParams")
            reportContent += " " + staticParamsNumber + "测量电压和额定频率的稳态参数,,,,,,,,,,,,,,,,,,,,,,,,,,\n"
            reportContent += "\n"
            
            // 构建表头
            var headerColumns = []
            if (isReportColumnEnabled("load")) headerColumns.push("负载")
            if (isReportColumnEnabled("power")) headerColumns.push("功率(kW)")
            if (isReportColumnEnabled("ua")) headerColumns.push("UA(V)")
            if (isReportColumnEnabled("ub")) headerColumns.push("UB(V)")
            if (isReportColumnEnabled("uc")) headerColumns.push("UC(V)")
            if (isReportColumnEnabled("ia")) headerColumns.push("IA(A)")
            if (isReportColumnEnabled("ib")) headerColumns.push("IB(A)")
            if (isReportColumnEnabled("ic")) headerColumns.push("IC(A)")
            if (isReportColumnEnabled("pf")) headerColumns.push("稳态功率因数")
            if (isReportColumnEnabled("freq")) headerColumns.push("频率F1 (Hz)")
            if (isReportColumnEnabled("steadyFreqBand")) headerColumns.push("稳态频率带βF%")
            if (isReportColumnEnabled("freqRangeUp")) headerColumns.push("频率整定范围上升(%)")
            if (isReportColumnEnabled("freqRangeDown")) headerColumns.push("频率整定范围下降(%)")
            reportContent += headerColumns.join(",") + "\n"
            
            // 从tabDataStorage中读取静态参数填入报表
            for (var i = 0; i < tabDataStorage.length; i++) {
                var loadLabel = tabLabels[i]
                var data = tabDataStorage[i]
                var percentage = parseFloat(loadLabel) / 100
                var power = paramSettings.ratedPower * percentage
                var powerValue = power.toFixed(2)
                var steadyFreqBandValue = ""
                if (data.waveTestRefPhase !== "" && ratedFrequencyToUse > 0) {
                    if (data.waveTestFrequencyMax > 0 && data.waveTestFrequencyMin > 0) {
                        var steadyFreqBand = ((data.waveTestFrequencyMax - data.waveTestFrequencyMin) * 100) / ratedFrequencyToUse
                        steadyFreqBandValue = steadyFreqBand.toFixed(2)
                    }
                }
                var uA = data.staticThreePhaseParamsReceived ? data.staticVoltageA.toFixed(2) : ""
                var uB = data.staticThreePhaseParamsReceived ? data.staticVoltageB.toFixed(2) : ""
                var uC = data.staticThreePhaseParamsReceived ? data.staticVoltageC.toFixed(2) : ""
                var iA = data.staticThreePhaseParamsReceived ? data.staticCurrentA.toFixed(2) : ""
                var iB = data.staticThreePhaseParamsReceived ? data.staticCurrentB.toFixed(2) : ""
                var iC = data.staticThreePhaseParamsReceived ? data.staticCurrentC.toFixed(2) : ""
                var pf = data.staticThreePhaseParamsReceived ? data.staticPowerFactor.toFixed(4) : ""
                var freq = data.staticThreePhaseParamsReceived ? data.staticFrequency.toFixed(3) : ""
                var freqRangeUp = ""
                var freqRangeDown = ""
                if (data.frequencyCalibrationRefPhase !== "" && ratedFrequencyToUse > 0) {
                    if (data.frequencyCalibrationFmax > 0) {
                        var upValue = ((data.frequencyCalibrationFmax - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
                        freqRangeUp = upValue.toFixed(2)
                    }
                    if (data.frequencyCalibrationFmin > 0) {
                        var downValue = ((ratedFrequencyToUse - data.frequencyCalibrationFmin) / ratedFrequencyToUse) * 100
                        freqRangeDown = downValue.toFixed(2)
                    }
                }
                
                // 构建数据行
                var dataColumns = []
                if (isReportColumnEnabled("load")) dataColumns.push(loadLabel)
                if (isReportColumnEnabled("power")) dataColumns.push(powerValue)
                if (isReportColumnEnabled("ua")) dataColumns.push(uA)
                if (isReportColumnEnabled("ub")) dataColumns.push(uB)
                if (isReportColumnEnabled("uc")) dataColumns.push(uC)
                if (isReportColumnEnabled("ia")) dataColumns.push(iA)
                if (isReportColumnEnabled("ib")) dataColumns.push(iB)
                if (isReportColumnEnabled("ic")) dataColumns.push(iC)
                if (isReportColumnEnabled("pf")) dataColumns.push(pf)
                if (isReportColumnEnabled("freq")) dataColumns.push(freq)
                if (isReportColumnEnabled("steadyFreqBand")) dataColumns.push(steadyFreqBandValue)
                if (isReportColumnEnabled("freqRangeUp")) dataColumns.push(freqRangeUp)
                if (isReportColumnEnabled("freqRangeDown")) dataColumns.push(freqRangeDown)
                reportContent += dataColumns.join(",") + "\n"
            }
            reportContent += "\n"
        }
        
        // 测试结果
        if (isReportSectionEnabled("testResults")) {
            var testResultColumns = []
            testResultColumns.push("测试结果")
            if (isReportColumnEnabled("voltageDistortionRate")) {
                testResultColumns.push("电压波形畸变率Ku%:")
                testResultColumns.push(voltageDistortionRateStr)
            }
            if (isReportColumnEnabled("steadyVoltageDeviation")) {
                testResultColumns.push("稳态电压偏差δUst%:")
                testResultColumns.push(steadyVoltageDeviationStr)
            }
            if (isReportColumnEnabled("steadyFrequencyBand")) {
                testResultColumns.push("稳态频率带βF%:")
                testResultColumns.push(steadyFrequencyBandStr)
            }
            reportContent += testResultColumns.join(",") + "\n"
            
            var testResultColumns2 = []
            testResultColumns2.push("")
            if (isReportColumnEnabled("steadyFrequencyDeviation")) {
                testResultColumns2.push("频率降δFst%:")
                testResultColumns2.push(steadyFrequencyDeviationStr)
            }
            if (isReportColumnEnabled("voltageSettingRange")) {
                testResultColumns2.push("电压整定范围:")
                testResultColumns2.push(voltageSettingRangeStr)
            }
            testResultColumns2.push("")
            testResultColumns2.push("")
            reportContent += testResultColumns2.join(",") + "\n"
            reportContent += "\n"
        }
        
        // 瞬态测试
        if (isReportSectionEnabled("transientTest")) {
            var transientTestNumber = getSectionNumber("transientTest")
            reportContent += " " + transientTestNumber + "瞬态测试,,,,,,,,,,,,,,,,,,,,,,,,,,\n"
            reportContent += "\n"
            
            var suddenAddColumns = []
            if (isReportColumnEnabled("suddenAddVoltageDeviation")) {
                suddenAddColumns.push("突加电压瞬态电压偏差δu%:")
                suddenAddColumns.push(suddenAddVoltageDeviation)
            }
            if (isReportColumnEnabled("suddenAddVoltageStableTime")) {
                suddenAddColumns.push("突加电压稳定时间(s):")
                suddenAddColumns.push(suddenAddVoltageStableTime)
            }
            if (isReportColumnEnabled("suddenAddFrequencyDeviation")) {
                suddenAddColumns.push("突加频率瞬态频率偏差δf%:")
                suddenAddColumns.push(suddenAddFrequencyDeviation)
            }
            if (isReportColumnEnabled("suddenAddFrequencyStableTime")) {
                suddenAddColumns.push("突加频率稳定时间(s):")
                suddenAddColumns.push(suddenAddFrequencyStableTime)
            }
            reportContent += suddenAddColumns.join(",") + "\n"
            
            var suddenLoadColumns = []
            if (isReportColumnEnabled("suddenLoadVoltageDeviation")) {
                suddenLoadColumns.push("突卸电压瞬态电压偏差δu%:")
                suddenLoadColumns.push(suddenLoadVoltageDeviation)
            }
            if (isReportColumnEnabled("suddenLoadVoltageStableTime")) {
                suddenLoadColumns.push("突卸电压稳定时间(s):")
                suddenLoadColumns.push(suddenLoadVoltageStableTime)
            }
            if (isReportColumnEnabled("suddenLoadFrequencyDeviation")) {
                suddenLoadColumns.push("突卸频率瞬态频率偏差δf%:")
                suddenLoadColumns.push(suddenLoadFrequencyDeviation)
            }
            if (isReportColumnEnabled("suddenLoadFrequencyStableTime")) {
                suddenLoadColumns.push("突卸频率稳定时间(s):")
                suddenLoadColumns.push(suddenLoadFrequencyStableTime)
            }
            reportContent += suddenLoadColumns.join(",") + "\n"
            reportContent += "\n"
        }
        
        // 实验结论
        if (isReportSectionEnabled("conclusion")) {
            reportContent += "实验结论,,,,,,,,,,,,,,,,,,,,,,,,,,\n"
            reportContent += "\n"
            reportContent += "测试人员：," + paramSettings.surveyor + ",,,,检验人员：," + paramSettings.verifier + ",,,,审核人：,,,,会签：,,,,\n"
        }
        
        return reportContent
    }

    function getGeneratorTestManager() {
        if (homePage) {
            return homePage.generatorTestManagerInstance
        }
        return null
    }

    function sendHexMessage(hexMessage) {
        var generatorTestManager = getGeneratorTestManager()
        if (generatorTestManager) {
            console.log("发电机测试 - 发送16进制报文:", hexMessage)
            lastSentCommand = hexMessage
            generatorTestManager.sendHexMessage(hexMessage)
        } else {
            console.log("发电机测试管理器为null，无法发送报文")
        }
    }

    function appendReceivedData(hexData) {
        var timestamp = Qt.formatDateTime(new Date(), "hh:mm:ss.zzz")
        receivedData += "[" + timestamp + "] 接收: " + hexData + "\n"
        if (receivedData.length > 5000) {
            receivedData = receivedData.substring(receivedData.length - 4000)
        }
        // 安全地访问 dataDisplayArea
        var displayArea = null
        if (contentLoader.item && contentLoader.item.dataDisplayArea) {
            displayArea = contentLoader.item.dataDisplayArea
        }
        if (displayArea) {
            displayArea.cursorPosition = displayArea.length
        }

        // 处理分批接收的数据
        var trimmedData = hexData.trim()
        dataBuffer += " " + trimmedData
        dataBuffer = dataBuffer.trim()

        // 检查是否是短响应（命令确认或错误）
        var shortResponses = ["AA 01 60 0B", "AA 01 FF AA", "AA 01 70 1B", "AA 01 72 1D"]
        for (var i = 0; i < shortResponses.length; i++) {
            if (dataBuffer === shortResponses[i]) {
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        }

        // 检查是否是参数设置响应
        if (dataBuffer.startsWith("AA 01")) {
            // 只处理明确的短响应，避免干扰长响应的分段接收
            var shortResponsePattern = /^AA 01 [0-9A-F]{2} [0-9A-F]{2}$/
            if (dataBuffer.length <= 12 && shortResponsePattern.test(dataBuffer)) {
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        }

        // 检查是否是突加/突卸数据响应（长响应）
        var bytes = dataBuffer.split(" ")
        if (dataBuffer.startsWith("AA 01 64")) { // 电压突加数据
            if (bytes.length >= 417) {
                processResponse(bytes.slice(0, 417).join(" "))
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 65")) { // 频率突加数据
            if (bytes.length >= 417) {
                processResponse(bytes.slice(0, 417).join(" "))
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 66")) { // 电流突加数据
            if (bytes.length >= 417) {
                var firstFrame = bytes.slice(0, 417).join(" ")
                console.log("突加电流数据，取前417字节:", firstFrame.length, "原始长度:", bytes.length)
                processResponse(firstFrame)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 67")) { // 电压突卸数据
            if (bytes.length >= 417) {
                processResponse(bytes.slice(0, 417).join(" "))
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 68")) { // 频率突卸数据
            if (bytes.length >= 417) {
                processResponse(bytes.slice(0, 417).join(" "))
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 69")) { // 电流突卸数据
            if (bytes.length >= 417) {
                var firstFrame = bytes.slice(0, 417).join(" ")
                console.log("突卸电流数据，取前417字节:", firstFrame.length, "原始长度:", bytes.length)
                processResponse(firstFrame)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 61")) { // 波动数据
            if (dataBuffer.split(" ").length >= 21) {
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 71")) { // 基准相波形数据
            if (dataBuffer.split(" ").length >= 517) {
                console.log("处理波形数据...")
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 73")) { // 谐波数据
            if (dataBuffer.split(" ").length >= 413) {
                console.log("处理谐波数据...")
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 74")) { // 召测整定试验数据
            if (dataBuffer.split(" ").length >= 21) {
                console.log("处理召测整定试验数据...")
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 4A")) { // 设备参数响应
            if (dataBuffer.split(" ").length >= 36) {
                console.log("处理设备参数响应...")
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 39")) { // 三相电气参数响应
            if (dataBuffer.split(" ").length >= 32) {
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        } else if (dataBuffer.startsWith("AA 01 34")) { // 静态三相参数响应
            if (dataBuffer.split(" ").length >= 44) {
                processResponse(dataBuffer)
                dataBuffer = ""
                return
            }
        }
    }

    function processResponse(data) {
        if (parseStaticThreePhaseParamsResponse(data)) {
            return
        }
        
        if (checkParameterResponse(data)) {
            return
        }

        if (waveTestInProgress) {
            if (data === "55 01 60 B6") {
                waveTestStatus = "波动实验已启动，等待60秒..."
                waveTestDataRequested = false
            } else if (data === "AA 01 60 0B") {
                waveTestStatus = "波动实验已启动，等待60秒..."
                waveTestDataRequested = false
            } else if (data === "AA 01 FF AA") {
                // 检查是否是一键测试模式
                if (autoTestInProgress) {
                    autoTestRetryCount++
                    if (autoTestRetryCount < 3) {
                        waveTestStatus = "波动实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                        hideWaitingPopup()
                        showWaitingPopup("波动实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                        autoTestRetryType = "wave"
                        autoTestNextStepTimer.interval = 5000
                        autoTestNextStepTimer.start()
                        return
                    } else {
                        waveTestStatus = "波动实验启动失败，已达最大重试次数"
                        autoTestRetryCount = 0
                    }
                }
                waveTestStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                stopWaveTest()
            } else if (parseWaveTestResponse(data)) {
                waveTestStatus = "数据读取成功"
                waveTestDataRequested = true
                if (autoTestInProgress) {
                    autoTestRetryCount = 0
                }
                stopWaveTest()
            }
        }

        if (suddenAddTestInProgress) {
            if (data === "55 01 62 B8") {
                suddenAddTestStatus = "突加实验已启动，等待32秒..."
                suddenAddTestDataRequested = false
                suddenAddTestPhase = 2
                suddenAddPowerSendTimer.start()
            } else if (data.startsWith("AA 01 62")) {
                suddenAddTestStatus = "突加实验已启动，等待32秒..."
                suddenAddTestDataRequested = false
                suddenAddTestPhase = 2
                suddenAddPowerSendTimer.start()
            } else if (data === "AA 01 FF AA") {
                // 检查是否是一键测试模式
                if (autoTestInProgress) {
                    autoTestRetryCount++
                    if (autoTestRetryCount < 3) {
                        suddenAddTestStatus = "突加实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                        hideWaitingPopup()
                        showWaitingPopup("突加实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                        autoTestRetryType = "suddenAdd"
                        autoTestNextStepTimer.interval = 5000
                        autoTestNextStepTimer.start()
                        return
                    } else {
                        suddenAddTestStatus = "突加实验启动失败，已达最大重试次数"
                        autoTestRetryCount = 0
                    }
                }
                suddenAddTestStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                stopSuddenAddTest()
            } else if (parseSuddenAddTestResponse(data)) {
                suddenAddTestStatus = "电压数据读取成功"
                // 继续读取频率数据
                requestSuddenAddFrequencyData()
            } else if (parseSuddenAddFrequencyResponse(data)) {
                suddenAddTestStatus = "频率数据读取成功"
                // 继续读取电流数据
                requestSuddenAddCurrentData()
            } else if (parseSuddenAddCurrentResponse(data)) {
                console.log("processResponse: 突加电流数据解析成功！")
                suddenAddTestStatus = "所有数据读取成功"
                suddenAddTestDataRequested = true
                if (autoTestInProgress) {
                    autoTestRetryCount = 0
                }
                stopSuddenAddTest()
            }
        }

        if (suddenLoadTestInProgress) {
            if (data === "55 01 63 B9") {
                suddenLoadTestStatus = "突卸实验已启动，等待32秒..."
                suddenLoadTestDataRequested = false
                suddenLoadTestPhase = 2
                suddenLoadUnloadTimer.start()
            } else if (data.startsWith("AA 01 63")) {
                suddenLoadTestStatus = "突卸实验已启动，等待32秒..."
                suddenLoadTestDataRequested = false
                suddenLoadTestPhase = 2
                suddenLoadUnloadTimer.start()
            } else if (data === "AA 01 FF AA") {
                // 检查是否是一键测试模式
                if (autoTestInProgress) {
                    autoTestRetryCount++
                    if (autoTestRetryCount < 3) {
                        suddenLoadTestStatus = "突卸实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                        hideWaitingPopup()
                        showWaitingPopup("突卸实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                        autoTestRetryType = "suddenLoad"
                        autoTestNextStepTimer.interval = 5000
                        autoTestNextStepTimer.start()
                        return
                    } else {
                        suddenLoadTestStatus = "突卸实验启动失败，已达最大重试次数"
                        autoTestRetryCount = 0
                    }
                }
                suddenLoadTestStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                stopSuddenLoadTest()
            } else if (parseSuddenLoadTestResponse(data)) {
                suddenLoadTestStatus = "电压数据读取成功"
                // 继续读取频率数据
                requestSuddenLoadFrequencyData()
            } else if (parseSuddenLoadFrequencyResponse(data)) {
                suddenLoadTestStatus = "频率数据读取成功"
                // 继续读取电流数据
                requestSuddenLoadCurrentData()
            } else if (parseSuddenLoadCurrentResponse(data)) {
                console.log("processResponse: 突卸电流数据解析成功！")
                suddenLoadTestStatus = "所有数据读取成功"
                suddenLoadTestDataRequested = true
                if (autoTestInProgress) {
                    autoTestRetryCount = 0
                }
                stopSuddenLoadTest()
            }
        }

        if (harmonicTestInProgress) {
            if (data === "55 01 70 C6") {
                harmonicTestStatus = "谐波实验已启动，等待60秒..."
                harmonicTestStep = 2
            } else if (data.startsWith("AA 01 70")) {
                harmonicTestStatus = "谐波实验已启动，等待60秒..."
                harmonicTestStep = 2
            } else if (data === "AA 01 FF AA") {
                // 检查是否是一键测试模式
                if (autoTestInProgress) {
                    autoTestRetryCount++
                    if (autoTestRetryCount < 3) {
                        harmonicTestStatus = "谐波实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                        hideWaitingPopup()
                        showWaitingPopup("谐波实验启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                        autoTestRetryType = "harmonic"
                        autoTestNextStepTimer.interval = 5000
                        autoTestNextStepTimer.start()
                        return
                    } else {
                        harmonicTestStatus = "谐波实验启动失败，已达最大重试次数"
                        autoTestRetryCount = 0
                    }
                }
                harmonicTestStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                stopHarmonicTest()
            } else if (data.startsWith("AA 01 72")) {
                harmonicTestStatus = "所有数据读取成功"
                harmonicTestDataRequested = true
                if (autoTestInProgress) {
                    autoTestRetryCount = 0
                }
                stopHarmonicTest()
            } else if (parseHarmonicTestResponse(data)) {
                harmonicTestStatus = "谐波数据读取成功，正在退出谐波模式..."
                harmonicTestStep = 5
                requestHarmonicExit()
            } else if (parseHarmonicWaveformResponse(data)) {
                harmonicTestStatus = "波形数据读取成功，正在请求谐波数据..."
                harmonicTestStep = 4
                requestHarmonicTestData()
            }
        }

        // 处理校准测试响应
        if (calibrationTestInProgress) {
            if (data === "55 01 76 CC") {
                voltageCalibrationStatus = "电压整定已启动，等待105秒..."
            } else if (data === "55 01 77 CD") {
                frequencyCalibrationStatus = "频率整定已启动，等待105秒..."
            } else if (data.startsWith("AA 01 76")) {
                voltageCalibrationStatus = "电压整定已启动，等待105秒..."
            } else if (data.startsWith("AA 01 77")) {
                frequencyCalibrationStatus = "频率整定已启动，等待105秒..."
            } else if (data === "AA 01 FF AA") {
                // 检查是否是一键测试模式
                if (autoTestInProgress) {
                    autoTestRetryCount++
                    if (autoTestRetryCount < 3) {
                        if (currentCalibrationType === "voltage") {
                            voltageCalibrationStatus = "电压整定启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                            hideWaitingPopup()
                            showWaitingPopup("电压整定启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                            autoTestRetryType = "voltageCalibration"
                        } else if (currentCalibrationType === "frequency") {
                            frequencyCalibrationStatus = "频率整定启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中..."
                            hideWaitingPopup()
                            showWaitingPopup("频率整定启动失败，第 " + (autoTestRetryCount + 1) + " 次重试中...", 5)
                            autoTestRetryType = "frequencyCalibration"
                        }
                        autoTestNextStepTimer.interval = 5000
                        autoTestNextStepTimer.start()
                        return
                    } else {
                        if (currentCalibrationType === "voltage") {
                            voltageCalibrationStatus = "电压整定启动失败，已达最大重试次数"
                        } else if (currentCalibrationType === "frequency") {
                            frequencyCalibrationStatus = "频率整定启动失败，已达最大重试次数"
                        }
                        autoTestRetryCount = 0
                    }
                }
                if (currentCalibrationType === "voltage") {
                    voltageCalibrationStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                } else if (currentCalibrationType === "frequency") {
                    frequencyCalibrationStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                }
                stopCalibrationTest()
            } else if (parseCalibrationTestResponse(data)) {
                if (currentCalibrationType === "voltage") {
                    voltageCalibrationStatus = "数据读取成功"
                } else if (currentCalibrationType === "frequency") {
                    frequencyCalibrationStatus = "数据读取成功"
                }
                calibrationTestDataRequested = true
                if (autoTestInProgress) {
                    autoTestRetryCount = 0
                }
                stopCalibrationTest()
            }
        }
        
        // 处理电压整定命令响应
        if (data.startsWith("AA 01 76")) {
            console.log("电压整定命令响应:", data)
        }

        // 处理频率整定命令响应
        if (data.startsWith("AA 01 77")) {
            console.log("频率整定命令响应:", data)
        }
        
        // 处理录波命令响应
        if (waveformRecordTestInProgress) {
            if (data.startsWith("AA 01 78")) {
                waveformRecordTestStatus = "成功启动录波模式"
                waveformRecordTestInProgress = false
            } else if (data === "AA 01 FF AA") {
                waveformRecordTestStatus = "仪表拒绝执行，请检查：1.是否处于其他试验模式 2.是否被锁定 3.是否有有效测量输入 4.参数是否已初始化"
                waveformRecordTestInProgress = false
            }
        }
        
        // 处理设备参数响应
        if (deviceParamsRequested && !deviceParamsReceived) {
            if (parseDeviceParamsResponse(data)) {
                deviceParamsReceived = true
                console.log("设备参数已接收，准备继续导出")
            }
        }
        
        // 处理三相电气参数响应
        if (showThreePhaseParams) {
            if (parseThreePhaseParamsResponse(data)) {
                console.log("三相电气参数已接收 - A相电压:", threePhaseVoltageA.toFixed(2), 
                            "频率:", threePhaseFrequency.toFixed(2))
            }
        }
    }

    Component.onCompleted: {
        var generatorTestManager = getGeneratorTestManager()
        if (generatorTestManager) {
            generatorTestManager.dataReceived.connect(function(data) {
                appendReceivedData(data)
            })
        }
        if (homePage) {
            modbusManager = homePage.modbusManagerInstance
        }
    }

    function showWaitingPopup(title, seconds) {
        waitingDialogTitle = title
        waitingDialogSeconds = seconds
        waitingDialogRemaining = seconds
        showWaitingDialog = true
        waitingDialogTimer.start()
    }

    function hideWaitingPopup() {
        showWaitingDialog = false
        waitingDialogTimer.stop()
    }

    function sendPowerByCurrentTab() {
        if (!modbusManager) {
            console.log("modbusManager不可用，无法发送功率")
            return
        }
        if (currentTabIndex < 0 || currentTabIndex >= tabLabels.length) {
            console.log("当前标签索引无效")
            return
        }
        var percentageStr = tabLabels[currentTabIndex]
        var percentage = parseFloat(percentageStr) / 100
        var power = paramSettings.ratedPower * percentage
        console.log("突加实验：发送功率 - 当前标签:", percentageStr, "百分比:", percentage, "额定功率:", paramSettings.ratedPower, "实际功率:", power, "KW")
        modbusManager.writeCurrent(power, 1)
    }

    function exportReport(format) {
        console.log("导出报表，格式:", format)
        showExportDialog = false
        selectedExportFormat = format
        fileSaveDialog.open()
    }

    function clearReportData() {
        console.log("清空报表数据")
        
        // 清空预览报表
        showReportPreview = false
        currentReportData = null
        
        // 清空测试历史数据
        testDataHistory = {
            "wave": null,
            "suddenAdd": null,
            "suddenLoad": null,
            "harmonic": null
        }
        
        // 清空标签页数据
        for (var i = 0; i < tabDataStorage.length; i++) {
            tabDataStorage[i] = {
                waveTestRefPhase: "",
                waveTestVoltageMax: 0,
                waveTestVoltageMin: 0,
                waveTestFrequencyMax: 0,
                waveTestFrequencyMin: 0,
                waveTestStatus: "",
                suddenAddTestRefPhase: "",
                suddenAddTestTolerance: 0,
                suddenAddTestStableTime: 0,
                suddenAddTestExtremeValue: 0,
                suddenAddTestMultiplier: 0,
                suddenAddFrequencyTolerance: 0,
                suddenAddFrequencyStableTime: 0,
                suddenAddFrequencyExtremeValue: 0,
                suddenAddRatedNoLoadFrequency: 0,
                suddenAddCurrentTolerance: 0,
                suddenAddCurrentStableTime: 0,
                suddenAddCurrentExtremeValue: 0,
                suddenAddCurrentMultiplier: 0,
                suddenAddTestStatus: "",
                suddenLoadTestRefPhase: "",
                suddenLoadTestTolerance: 0,
                suddenLoadTestStableTime: 0,
                suddenLoadTestExtremeValue: 0,
                suddenLoadTestMultiplier: 0,
                suddenLoadFrequencyTolerance: 0,
                suddenLoadFrequencyStableTime: 0,
                suddenLoadFrequencyExtremeValue: 0,
                suddenLoadRatedNoLoadFrequency: 0,
                suddenLoadCurrentTolerance: 0,
                suddenLoadCurrentStableTime: 0,
                suddenLoadCurrentExtremeValue: 0,
                suddenLoadCurrentMultiplier: 0,
                suddenLoadTestStatus: "",
                harmonicTestRefPhase: "",
                harmonicTestVoltageWaveform: [],
                harmonicTestCurrentWaveform: [],
                harmonicTestStatus: "",
                voltageCalibrationRefPhase: "",
                voltageCalibrationUmax: 0,
                voltageCalibrationUmin: 0,
                frequencyCalibrationRefPhase: "",
                frequencyCalibrationFmax: 0,
                frequencyCalibrationFmin: 0,
                voltageCalibrationStatus: "",
                frequencyCalibrationStatus: "",
                staticThreePhaseParamsReceived: false,
                staticVoltageA: 0,
                staticVoltageB: 0,
                staticVoltageC: 0,
                staticCurrentA: 0,
                staticCurrentB: 0,
                staticCurrentC: 0,
                staticTotalPower: 0,
                staticPowerFactor: 0,
                staticFrequency: 0
            }
        }
        
        // 重置当前标签的数据
        waveTestRefPhase = ""
        waveTestVoltageMax = 0
        waveTestVoltageMin = 0
        waveTestFrequencyMax = 0
        waveTestFrequencyMin = 0
        waveTestStatus = ""
        
        suddenAddTestRefPhase = ""
        suddenAddTestTolerance = 0
        suddenAddTestStableTime = 0
        suddenAddTestExtremeValue = 0
        suddenAddTestMultiplier = 0
        suddenAddFrequencyTolerance = 0
        suddenAddFrequencyStableTime = 0
        suddenAddFrequencyExtremeValue = 0
        suddenAddRatedNoLoadFrequency = 0
        suddenAddCurrentTolerance = 0
        suddenAddCurrentStableTime = 0
        suddenAddCurrentExtremeValue = 0
        suddenAddCurrentMultiplier = 0
        suddenAddTestStatus = ""
        
        suddenLoadTestRefPhase = ""
        suddenLoadTestTolerance = 0
        suddenLoadTestStableTime = 0
        suddenLoadTestExtremeValue = 0
        suddenLoadTestMultiplier = 0
        suddenLoadFrequencyTolerance = 0
        suddenLoadFrequencyStableTime = 0
        suddenLoadFrequencyExtremeValue = 0
        suddenLoadRatedNoLoadFrequency = 0
        suddenLoadCurrentTolerance = 0
        suddenLoadCurrentStableTime = 0
        suddenLoadCurrentExtremeValue = 0
        suddenLoadCurrentMultiplier = 0
        suddenLoadTestStatus = ""
        
        harmonicTestRefPhase = ""
        harmonicTestVoltageWaveform = []
        harmonicTestCurrentWaveform = []
        harmonicTestVoltageHarmonics = []
        harmonicTestCurrentHarmonics = []
        harmonicTestVoltageDistortionRate = 0
        harmonicTestStatus = ""
        
        voltageCalibrationRefPhase = ""
        voltageCalibrationUmax = 0
        voltageCalibrationUmin = 0
        frequencyCalibrationRefPhase = ""
        frequencyCalibrationFmax = 0
        frequencyCalibrationFmin = 0
        
        staticVoltageA = 0
        staticVoltageB = 0
        staticVoltageC = 0
        staticCurrentA = 0
        staticCurrentB = 0
        staticCurrentC = 0
        staticTotalPower = 0
        staticPowerFactor = 0
        staticFrequency = 0
        staticThreePhaseParamsReceived = false
        
        // 保存重置后的数据
        saveCurrentTabData()
        saveTestData()
        
        console.log("报表数据已清空")
    }

    // 操作状态提示文本 - 当操作条件不满足时显示
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

    // 顶部容器 - 包含页面标题和功能按钮
    Rectangle {
        id: topContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 70
        color: "transparent"
        visible: operationConditionsMet

        RowLayout {
            anchors.fill: parent
            spacing: 16

            // 页面标题
            Text {
                text: "发电机测试"
                color: theme.textColor
                font.pixelSize: 20
                font.bold: true
            }

            // 设置参数按钮
            EButton {
                id: parameterButton
                text: "设置参数"
                size: "xs"
                containerColor: theme.isDark ? "#FFC107" : "#FFC107"
                textColor: "black"
                shadowEnabled: true
                onClicked: {
                    resetTempParameters()
                    showParameterInput = !showParameterInput
                }
            }

            // 报表参数设置按钮
            EButton {
                id: reportConfigButton
                text: "报表设置"
                size: "xs"
                containerColor: theme.isDark ? "#FFC107" : "#FFC107"
                textColor: "black"
                shadowEnabled: true
                onClicked: {
                    showReportConfigDialog = true
                }
            }

            // 导出报表按钮
            EButton {
                id: exportButton
                text: "导出报表"
                size: "xs"
                containerColor: theme.secondaryColor
                textColor: theme.textColor
                shadowEnabled: true
                onClicked: {
                    showExportDialog = true
                }
            }

            // 清空数据和报表按钮
            EButton {
                id: clearReportButton
                text: "清空数据和报表"
                size: "xs"
                containerColor: theme.secondaryColor
                textColor: theme.textColor
                shadowEnabled: true
                onClicked: {
                    clearReportData()
                }
            }

            /* EButton {
                id: threePhaseParamsButton
                text: showThreePhaseParams ? "关闭三相参数" : "三相电气参数"
                size: "xs"
                containerColor: showThreePhaseParams ? (theme.isDark ? "#FF9800" : "#FF9800") : theme.secondaryColor
                textColor: "white"
                shadowEnabled: true
                enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !calibrationTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                onClicked: {
                    var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                    if (!anyTestInProgress) {
                        showThreePhaseParams = !showThreePhaseParams
                        if (showThreePhaseParams) {
                            threePhaseParamsTimer.start()
                        } else {
                            threePhaseParamsTimer.stop()
                        }
                    }
                }
            } */

            EButton {
                id: testConfigButton
                text: "一键测试设置项"
                size: "xs"
                containerColor: theme.isDark ? "#5E55A2" : "#5E55A2"
                textColor: "#91C53A"
                shadowEnabled: true
                enabled: !autoTestInProgress && !singleTabAutoTestInProgress
                onClicked: {
                    showTestConfigDialog = true
                }
            }

            EButton {
                id: autoTestButton
                text: "一键测试并导出报表"
                size: "xs"
                containerColor: theme.isDark ? "#5E55A2" : "#5E55A2"
                textColor: "#91C53A"
                shadowEnabled: true
                enabled: !autoTestInProgress && !singleTabAutoTestInProgress && !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                onClicked: {
                    startAutoTest()
                }
            }

            EButton {
                id: cancelAutoTestButton
                text: "取消一键测试"
                size: "xs"
                containerColor: theme.isDark ? "#EF5350" : "#F44336"
                textColor: "white"
                shadowEnabled: true
                enabled: autoTestInProgress || singleTabAutoTestInProgress
                onClicked: {
                    stopAutoTest()
                }
            }
        }
    }

    Rectangle {
        id: leftPanel
        width: 200
        anchors.top: topContainer.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        color: "transparent"
        visible: operationConditionsMet

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 8
                    anchors.topMargin: 8
                    spacing: 8
                    width: leftPanel.width - 48



                    EButton {
                        text: "当前功率一键测试"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        shadowEnabled: true
                        enabled: !autoTestInProgress && !singleTabAutoTestInProgress && !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            startSingleTabAutoTest()
                        }
                    }

                    EButton {
                        text: "召测静态三相参数"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                // 暂停三相参数定时器，避免与静态参数召测冲突
                                if (threePhaseParamsTimer.running) {
                                    threePhaseParamsTimer.stop()
                                }
                                // 清空接收缓冲区
                                var generatorTestManager = getGeneratorTestManager()
                                if (generatorTestManager) {
                                    generatorTestManager.clearReceiveBuffer()
                                }
                                sendHexMessage("55 01 34 8A")
                            }
                        }
                    }

                    EButton {
                        text: "波动实验"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                if (testDataHistory["wave"] !== null) {
                                    loadTestData("wave")
                                } else {
                                    startWaveTest()
                                }
                            }
                        }
                    }

                    EButton {
                        text: "突加实验"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                if (testDataHistory["suddenAdd"] !== null) {
                                    loadTestData("suddenAdd")
                                } else {
                                    startSuddenAddTest()
                                }
                            }
                        }
                    }

                    EButton {
                        text: "突卸实验"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                if (testDataHistory["suddenLoad"] !== null) {
                                    loadTestData("suddenLoad")
                                } else {
                                    startSuddenLoadTest()
                                }
                            }
                        }
                    }

                    EButton {
                        text: "谐波实验"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                if (testDataHistory["harmonic"] !== null) {
                                    loadTestData("harmonic")
                                } else {
                                    startHarmonicTest()
                                }
                            }
                        }
                    }

                    EButton {
                        text: "启动电压整定"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !calibrationTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                startVoltageCalibrationTest()
                            }
                        }
                    }

                    EButton {
                        text: "启动频率整定"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !calibrationTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress
                        onClicked: {
                            var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                            if (!anyTestInProgress) {
                                startFrequencyCalibrationTest()
                            }
                        }
                    }

                    // EButton {
                    //     text: "启动录波"
                    //     size: "s"
                    //     Layout.fillWidth: true
                    //     Layout.preferredHeight: 48
                    //     enabled: !waveTestInProgress && !suddenAddTestInProgress && !suddenLoadTestInProgress && !harmonicTestInProgress && !calibrationTestInProgress && !voltageCalibrationInProgress && !frequencyCalibrationInProgress && !waveformRecordTestInProgress
                    //     onClicked: {
                    //         var anyTestInProgress = waveTestInProgress || suddenAddTestInProgress || suddenLoadTestInProgress || harmonicTestInProgress || calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress
                    //         if (!anyTestInProgress) {
                    //             startWaveformRecordTest()
                    //         }
                    //     }
                    // }

                    EButton {
                        text: "取消当前实验"
                        size: "s"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        containerColor: theme.isDark ? "#EF5350" : "#F44336"
                        textColor: "white"
                        onClicked: {
                            sendHexMessage("55 01 72 C8")
                            currentTestType = ""
                            
                            // 停止所有实验定时器和操作
                            if (waveTestInProgress) {
                                stopWaveTest()
                            }
                            if (suddenAddTestInProgress) {
                                stopSuddenAddTest()
                            }
                            if (suddenLoadTestInProgress) {
                                stopSuddenLoadTest()
                            }
                            if (harmonicTestInProgress) {
                                stopHarmonicTest()
                            }
                            if (calibrationTestInProgress || voltageCalibrationInProgress || frequencyCalibrationInProgress) {
                                stopCalibrationTest()
                            }
                            // if (waveformRecordTestInProgress) {
                            //     stopWaveformRecordTest()
                            // }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: rightPanel
        anchors.left: leftPanel.right
        anchors.right: parent.right
        anchors.top: topContainer.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        color: "transparent"
        visible: operationConditionsMet

        ColumnLayout {
            anchors.fill: parent
            spacing: 16

            ECard {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                padding: 8

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        text: "负载标签（额定功率的百分比）"
                        color: theme.textColor
                        font.pixelSize: 12
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: tabLabels
                            EButton {
                                text: modelData
                                size: "xs"
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 32
                                containerColor: index === currentTabIndex ? (theme.isDark ? "#2196F3" : "#2196F3") : (theme.isDark ? "#424242" : "#E0E0E0")
                                textColor: index === currentTabIndex ? "white" : theme.textColor
                                onClicked: {
                                    switchTab(index)
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: contentLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: showParameterInput ? testInstructionsComponent : dataDisplayComponent
            }

            Component {
                id: dataDisplayComponent
                ColumnLayout {
                    spacing: 16
                    anchors.fill: parent

                    Loader {
                        id: testDataLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: {
                            if (showThreePhaseParams) {
                                return threePhaseParamsComponent
                            } else {
                                return allTestDataComponent
                            }
                        }
                    }

                    // 接收数据框（已隐藏）
                    /*
                    ECard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        padding: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            Text {
                                text: "接收数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                TextArea {
                                    id: dataDisplayArea
                                    text: receivedData
                                    color: theme.textColor
                                    font.pixelSize: 11
                                    font.family: "Courier New"
                                    wrapMode: TextEdit.Wrap
                                    readOnly: true
                                }
                            }

                            EButton {
                                text: "清空"
                                size: "xs"
                                Layout.alignment: Qt.AlignRight
                                onClicked: {
                                    receivedData = ""
                                }
                            }
                        }
                    }
                    */
                }
            }

            Component {
                id: emptyTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Item {
                            Layout.fillHeight: true
                        }

                        Text {
                            text: "请选择实验类型开始测试"
                            color: theme.textColor
                            font.pixelSize: 14
                            opacity: 0.7
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }

            Component {
                id: allTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 16

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.maximumWidth: parent.width - 32
                            spacing: 40

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "静态三相参数"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: staticThreePhaseParamsReceived ? "数据已读取" : "等待召测..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电压数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                GridLayout {
                                    columns: 6
                                    columnSpacing: 32
                                    rowSpacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "A相(V):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticVoltageA.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "B相(V):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticVoltageB.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "C相(V):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticVoltageC.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }
                                }

                                Text {
                                    text: "电流数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                GridLayout {
                                    columns: 6
                                    columnSpacing: 32
                                    rowSpacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "A相(A):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticCurrentA.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "B相(A):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticCurrentB.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "C相(A):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticCurrentC.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }
                                }

                                Text {
                                    text: "其他参数"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                GridLayout {
                                    columns: 4
                                    columnSpacing: 32
                                    rowSpacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "总有功功率(W):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticTotalPower.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "总功率因数:"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticPowerFactor.toFixed(4) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "频率(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: staticThreePhaseParamsReceived ? staticFrequency.toFixed(3) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "波动实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "波动实验状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !waveTestInProgress && waveTestRefPhase !== ""
                                        onClicked: {
                                            refreshWaveTestData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !waveTestInProgress && waveTestRefPhase !== ""
                                        onClicked: {
                                            startWaveTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: waveTestStatus !== "" ? waveTestStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "波动实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                GridLayout {
                                    columns: 6
                                    columnSpacing: 32
                                    rowSpacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? waveTestRefPhase : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Item {
                                        width: 0
                                        height: 0
                                    }

                                    Text {
                                        text: "电压最大值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? waveTestVoltageMax.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "电压最小值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? waveTestVoltageMin.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "频率最大值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? waveTestFrequencyMax.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "频率最小值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? waveTestFrequencyMin.toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }
                                }

                                // 波动率计算和显示
                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "波动率计算"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                GridLayout {
                                    columns: 6
                                    columnSpacing: 32
                                    rowSpacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压波动率δUb%:"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? ((waveTestVoltageMax - waveTestVoltageMin) / (waveTestVoltageMax + waveTestVoltageMin) * 100).toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }

                                    Text {
                                        text: "频率波动率δFb%:"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: waveTestRefPhase !== "" ? ((waveTestFrequencyMax - waveTestFrequencyMin) / (waveTestFrequencyMax + waveTestFrequencyMin) * 100).toFixed(2) : "-"
                                        color: theme.textColor
                                        font.pixelSize: 13
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "突加实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "突加实验状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !suddenAddTestInProgress && suddenAddTestRefPhase !== ""
                                        onClicked: {
                                            refreshSuddenAddTestData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !suddenAddTestInProgress && suddenAddTestRefPhase !== ""
                                        onClicked: {
                                            startSuddenAddTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: suddenAddTestStatus !== "" ? suddenAddTestStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "突加实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                ColumnLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "基准相:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddTestRefPhase : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "电压数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddTestTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? (suddenAddTestStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? (suddenAddTestExtremeValue / 10).toFixed(1) + " V" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "倍率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddTestMultiplier.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "频率数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddFrequencyTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? (suddenAddFrequencyStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? (suddenAddFrequencyExtremeValue / 100).toFixed(2) + " Hz" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "额定空载频率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddRatedNoLoadFrequency.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "电流数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddCurrentTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? (suddenAddCurrentStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? ((suddenAddCurrentExtremeValue * suddenAddCurrentMultiplier) / 1000).toFixed(3) + " A" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "倍率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenAddTestRefPhase !== "" ? suddenAddCurrentMultiplier.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "突卸实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "突卸实验状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !suddenLoadTestInProgress && suddenLoadTestRefPhase !== ""
                                        onClicked: {
                                            refreshSuddenLoadTestData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !suddenLoadTestInProgress && suddenLoadTestRefPhase !== ""
                                        onClicked: {
                                            startSuddenLoadTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: suddenLoadTestStatus !== "" ? suddenLoadTestStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "突卸实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                ColumnLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "基准相:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadTestRefPhase : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "电压数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadTestTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? (suddenLoadTestStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? (suddenLoadTestExtremeValue / 10).toFixed(1) + " V" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "倍率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadTestMultiplier.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "频率数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadFrequencyTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? (suddenLoadFrequencyStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? (suddenLoadFrequencyExtremeValue / 100).toFixed(2) + " Hz" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "额定空载频率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadRatedNoLoadFrequency.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Text {
                                        text: "电流数据"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "容差带:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadCurrentTolerance.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "稳定时间:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? (suddenLoadCurrentStableTime / 1000).toFixed(3) + " S" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "极值数据:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? ((suddenLoadCurrentExtremeValue * suddenLoadCurrentMultiplier) / 1000).toFixed(3) + " A" : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "倍率:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: suddenLoadTestRefPhase !== "" ? suddenLoadCurrentMultiplier.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "谐波实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "谐波实验状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !harmonicTestInProgress && harmonicTestRefPhase !== ""
                                        onClicked: {
                                            refreshHarmonicTestData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !harmonicTestInProgress && harmonicTestRefPhase !== ""
                                        onClicked: {
                                            startHarmonicTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: harmonicTestStatus !== "" ? harmonicTestStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "谐波实验数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                ColumnLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "基准相:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: harmonicTestRefPhase !== "" ? harmonicTestRefPhase : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "电压波形畸变率 Ku%:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: harmonicTestVoltageDistortionRate > 0 ? harmonicTestVoltageDistortionRate.toFixed(4) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 16
                                    }

                                    EAreaChart {
                                        id: allVoltageChart
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 300
                                        backgroundColor: theme.secondaryColor
                                        lineColor: "#2196F3"
                                        areaColor: "#E3F2FD"
                                        title: "基准相电压波形"
                                        subtitle: "128个采样点"

                                        dataPoints: harmonicTestVoltageWaveform.map(function(value, index) {
                                            return { month: index.toString(), value: value / 10, label: "采样点 " + index }
                                        })
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 16
                                    }

                                    EAreaChart {
                                        id: allCurrentChart
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 300
                                        backgroundColor: theme.secondaryColor
                                        lineColor: "#4CAF50"
                                        areaColor: "#E8F5E9"
                                        title: "基准相电流波形"
                                        subtitle: "128个采样点"

                                        dataPoints: harmonicTestCurrentWaveform.map(function(value, index) {
                                            return { month: index.toString(), value: value, label: "采样点 " + index }
                                        })
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 50
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "电压整定数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "电压整定状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !voltageCalibrationInProgress && voltageCalibrationRefPhase !== ""
                                        onClicked: {
                                            refreshVoltageCalibrationData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !voltageCalibrationInProgress
                                        onClicked: {
                                            startVoltageCalibrationTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: voltageCalibrationStatus !== "" ? voltageCalibrationStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电压整定数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                ColumnLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "基准相:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: voltageCalibrationRefPhase !== "" ? voltageCalibrationRefPhase : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }

                                        Text {
                                            text: "电压最大值(V):"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: voltageCalibrationRefPhase !== "" ? voltageCalibrationUmax.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "电压最小值(V):"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: voltageCalibrationRefPhase !== "" ? voltageCalibrationUmin.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 2
                                color: theme.borderColor
                                opacity: 0.5
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "频率整定数据"
                                    color: theme.textColor
                                    font.pixelSize: 18
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "频率整定状态"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    EButton {
                                        text: "刷新数据"
                                        size: "xs"
                                        enabled: !frequencyCalibrationInProgress && frequencyCalibrationRefPhase !== ""
                                        onClicked: {
                                            refreshFrequencyCalibrationData()
                                        }
                                    }

                                    EButton {
                                        text: "重新测试"
                                        size: "xs"
                                        enabled: !frequencyCalibrationInProgress
                                        onClicked: {
                                            startFrequencyCalibrationTest()
                                        }
                                    }

                                    Item {
                                        Layout.preferredWidth: 20
                                    }
                                }

                                Text {
                                    text: frequencyCalibrationStatus !== "" ? frequencyCalibrationStatus : "等待开始..."
                                    color: theme.textColor
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "频率整定数据"
                                    color: theme.textColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                ColumnLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    GridLayout {
                                        columns: 6
                                        columnSpacing: 32
                                        rowSpacing: 12
                                        Layout.fillWidth: true

                                        Text {
                                            text: "基准相:"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: frequencyCalibrationRefPhase !== "" ? frequencyCalibrationRefPhase : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }

                                        Text {
                                            text: "频率最大值(Hz):"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: frequencyCalibrationRefPhase !== "" ? frequencyCalibrationFmax.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Text {
                                            text: "频率最小值(Hz):"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: frequencyCalibrationRefPhase !== "" ? frequencyCalibrationFmin.toFixed(2) : "-"
                                            color: theme.textColor
                                            font.pixelSize: 13
                                            font.family: "Courier New"
                                        }

                                        Item { width: 0; height: 0 }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: threePhaseParamsComponent
                EHoverCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                            text: "三相电气参数"
                            color: theme.textColor
                            font.pixelSize: 16
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 8
                        }

                        GridLayout {
                            columns: 6
                            rowSpacing: 12
                            columnSpacing: 4
                            Layout.fillWidth: true

                            Text {
                                text: ""
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }

                            Text {
                                text: "A相"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
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
                                Layout.fillWidth: true
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
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "电压"
                                color: theme.textColor
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: threePhaseVoltageA.toFixed(2) + " V"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: theme.textColor
                                opacity: 0.3
                            }

                            Text {
                                text: threePhaseVoltageB.toFixed(2) + " V"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: theme.textColor
                                opacity: 0.3
                            }

                            Text {
                                text: threePhaseVoltageC.toFixed(2) + " V"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "电流"
                                color: theme.textColor
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: threePhaseCurrentA.toFixed(3) + " A"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: theme.textColor
                                opacity: 0.3
                            }

                            Text {
                                text: threePhaseCurrentB.toFixed(3) + " A"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.fillHeight: true
                                color: theme.textColor
                                opacity: 0.3
                            }

                            Text {
                                text: threePhaseCurrentC.toFixed(3) + " A"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 16
                        }

                        Text {
                            text: "系统频率: " + threePhaseFrequency.toFixed(2) + " Hz"
                            color: theme.textColor
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Component {
                id: waveTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "波动实验状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !waveTestInProgress && waveTestRefPhase !== ""
                                    onClicked: {
                                        refreshWaveTestData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !waveTestInProgress && waveTestRefPhase !== ""
                                    onClicked: {
                                        startWaveTest()
                                    }
                                }
                            }

                            Text {
                                text: waveTestStatus !== "" ? waveTestStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "波动实验数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: waveTestRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: waveTestRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: waveTestRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压最大值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: waveTestVoltageMax.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压最小值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: waveTestVoltageMin.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "频率最大值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: waveTestFrequencyMax.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "频率最小值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: waveTestFrequencyMin.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: suddenAddTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "突加实验状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !suddenAddTestInProgress && suddenAddTestRefPhase !== ""
                                    onClicked: {
                                        refreshSuddenAddTestData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !suddenAddTestInProgress && suddenAddTestRefPhase !== ""
                                    onClicked: {
                                        startSuddenAddTest()
                                    }
                                }
                            }

                            Text {
                                text: suddenAddTestStatus !== "" ? suddenAddTestStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "突加实验数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: suddenAddTestRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: suddenAddTestRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddTestRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电压数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddTestTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddTestStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddTestExtremeValue / 10).toFixed(1) + " V"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "倍率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddTestMultiplier.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "频率数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddFrequencyTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddFrequencyStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddFrequencyExtremeValue / 100).toFixed(2) + " Hz"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "额定空载频率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddRatedNoLoadFrequency.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电流数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddCurrentTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddCurrentStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenAddCurrentExtremeValue / 1000).toFixed(3) + " A"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "倍率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenAddCurrentMultiplier.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: suddenLoadTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "突卸实验状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !suddenLoadTestInProgress && suddenLoadTestRefPhase !== ""
                                    onClicked: {
                                        refreshSuddenLoadTestData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !suddenLoadTestInProgress && suddenLoadTestRefPhase !== ""
                                    onClicked: {
                                        startSuddenLoadTest()
                                    }
                                }
                            }

                            Text {
                                text: suddenLoadTestStatus !== "" ? suddenLoadTestStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "突卸实验数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: suddenLoadTestRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: suddenLoadTestRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadTestRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电压数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadTestTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadTestStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadTestExtremeValue / 10).toFixed(1) + " V"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "倍率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadTestMultiplier.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "频率数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadFrequencyTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadFrequencyStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadFrequencyExtremeValue / 100).toFixed(2) + " Hz"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "额定空载频率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadRatedNoLoadFrequency.toFixed(2) + " Hz"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 8
                                }

                                Text {
                                    text: "电流数据"
                                    color: theme.textColor
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "容差带:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadCurrentTolerance.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "稳定时间:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadCurrentStableTime / 1000).toFixed(3) + " S"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "极值数据:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: (suddenLoadCurrentExtremeValue / 1000).toFixed(3) + " A"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "倍率:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: suddenLoadCurrentMultiplier.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: harmonicTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "谐波实验状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !harmonicTestInProgress && harmonicTestRefPhase !== ""
                                    onClicked: {
                                        refreshHarmonicTestData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !harmonicTestInProgress && harmonicTestRefPhase !== ""
                                    onClicked: {
                                        startHarmonicTest()
                                    }
                                }
                            }

                            Text {
                                text: harmonicTestStatus !== "" ? harmonicTestStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "谐波实验数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: harmonicTestRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: harmonicTestRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 150
                                    }

                                    Text {
                                        text: harmonicTestRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }

                                // Text {
                                //     text: "电压波形"
                                //     color: theme.textColor
                                //     font.pixelSize: 13
                                //     font.bold: true
                                // }

                                EAreaChart {
                                    id: voltageChart
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    backgroundColor: theme.secondaryColor
                                    lineColor: "#2196F3"
                                    areaColor: "#E3F2FD"
                                    title: "基准相电压波形"
                                    subtitle: "128个采样点"

                                    dataPoints: harmonicTestVoltageWaveform.map(function(value, index) {
                                        return { month: index.toString(), value: value / 10, label: "采样点 " + index }
                                    })


                                }



                                Item {
                                    Layout.fillWidth: true
                                    height: 16
                                }

                                // Text {
                                //     text: "电流波形"
                                //     color: theme.textColor
                                //     font.pixelSize: 13
                                //     font.bold: true
                                // }

                                EAreaChart {
                                    id: currentChart
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 300
                                    backgroundColor: theme.secondaryColor
                                    lineColor: "#4CAF50"
                                    areaColor: "#E8F5E9"
                                    title: "基准相电流波形"
                                    subtitle: "128个采样点"

                                    dataPoints: harmonicTestCurrentWaveform.map(function(value, index) {
                                        return { month: index.toString(), value: value, label: "采样点 " + index }
                                    })


                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: 50
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: testHistoryComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 16

                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        Text {
                            text: "历史测试数据"
                            color: theme.textColor
                            font.pixelSize: 16
                            font.bold: true
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            EButton {
                                text: testDataHistory["wave"] ? "查看波动实验数据" : "波动实验无数据"
                                size: "s"
                                Layout.fillWidth: true
                                enabled: testDataHistory["wave"] !== null
                                onClicked: {
                                    loadTestData("wave")
                                }
                            }

                            EButton {
                                text: testDataHistory["suddenAdd"] ? "查看突加实验数据" : "突加实验无数据"
                                size: "s"
                                Layout.fillWidth: true
                                enabled: testDataHistory["suddenAdd"] !== null
                                onClicked: {
                                    loadTestData("suddenAdd")
                                }
                            }

                            EButton {
                                text: testDataHistory["suddenLoad"] ? "查看突卸实验数据" : "突卸实验无数据"
                                size: "s"
                                Layout.fillWidth: true
                                enabled: testDataHistory["suddenLoad"] !== null
                                onClicked: {
                                    loadTestData("suddenLoad")
                                }
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            EButton {
                                text: testDataHistory["harmonic"] ? "查看谐波实验数据" : "谐波实验无数据"
                                size: "s"
                                Layout.fillWidth: true
                                enabled: testDataHistory["harmonic"] !== null
                                onClicked: {
                                    loadTestData("harmonic")
                                }
                            }

                            EButton {
                                text: "清除历史数据"
                                size: "s"
                                Layout.fillWidth: true
                                onClicked: {
                                    testDataHistory = {
                                        "wave": null,
                                        "suddenAdd": null,
                                        "suddenLoad": null,
                                        "harmonic": null
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }

            Component {
                id: voltageCalibrationDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "电压整定状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !voltageCalibrationInProgress && voltageCalibrationRefPhase !== ""
                                    onClicked: {
                                        refreshVoltageCalibrationData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !voltageCalibrationInProgress
                                    onClicked: {
                                        startVoltageCalibrationTest()
                                    }
                                }
                            }

                            Text {
                                text: voltageCalibrationStatus !== "" ? voltageCalibrationStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "电压整定数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: voltageCalibrationRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: voltageCalibrationRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: voltageCalibrationRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压最大值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: voltageCalibrationUmax.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压最小值(V):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: voltageCalibrationUmin.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: frequencyCalibrationDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "频率整定状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "刷新数据"
                                    size: "xs"
                                    enabled: !frequencyCalibrationInProgress && frequencyCalibrationRefPhase !== ""
                                    onClicked: {
                                        refreshFrequencyCalibrationData()
                                    }
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !frequencyCalibrationInProgress
                                    onClicked: {
                                        startFrequencyCalibrationTest()
                                    }
                                }
                            }

                            Text {
                                text: frequencyCalibrationStatus !== "" ? frequencyCalibrationStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "频率整定数据"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                                visible: frequencyCalibrationRefPhase !== ""
                            }

                            ColumnLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                visible: frequencyCalibrationRefPhase !== ""

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相:"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: frequencyCalibrationRefPhase
                                        color: theme.textColor
                                        font.pixelSize: 12
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "频率最大值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: frequencyCalibrationFmax.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "频率最小值(Hz):"
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        Layout.preferredWidth: 100
                                    }

                                    Text {
                                        text: frequencyCalibrationFmin.toFixed(2)
                                        color: theme.textColor
                                        font.pixelSize: 12
                                        font.family: "Courier New"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: waveformRecordTestDataComponent
                ECard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 12

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "录波试验状态"
                                    color: theme.textColor
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                EButton {
                                    text: "重新测试"
                                    size: "xs"
                                    enabled: !waveformRecordTestInProgress
                                    onClicked: {
                                        startWaveformRecordTest()
                                    }
                                }
                            }

                            Text {
                                text: waveformRecordTestStatus !== "" ? waveformRecordTestStatus : "等待开始..."
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            Text {
                                text: "录波试验说明"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动录波模式成功后，将进入录波状态，不接受后续数据采集。如需返回静态模式，请点击\"返回静态\"按钮。"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Component {
                id: testInstructionsComponent
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: rightPanel.width - 32
                        spacing: 16

                        Loader {
                            id: innerContentLoader
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            sourceComponent: showParameterInput ? parameterInputComponent : testListComponent
                        }
                    }
                }
            }

            Component {
                id: testListComponent
                ColumnLayout {
                    spacing: 16

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "一键测试说明"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "全标签一键测试：自动测试所有标签的实验，每个标签按顺序执行7个实验，完成后自动导出报表"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "单标签一键测试：只测试当前标签的实验，按顺序执行7个实验，完成后自动导出报表"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "实验顺序：召测静态三相参数 → 波动实验 → 谐波实验 → 电压整定 → 频率整定 → 突加实验 → 突卸实验"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "波动实验 (60H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动机组电压/频率波动性能测试，对应报告中波动试验极值数据采集"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 60 B6"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x60 = 0xB6"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 60 0B"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 试验完成后，发送55 01 61 B7可召测电压/频率最大最小值、基准值，用于计算稳态波动参数"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "突加实验 (62H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动负载突加瞬态性能测试，对应报告中突加电压/频率、瞬态偏差、稳定时间测试"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 62 B8"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x62 = 0xB8"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 62 0D"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 试验完成后，可发送64H/65H/66H命令，获取电压/频率/电流突加的200个采样点、稳定时间、极值数据"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "突卸实验 (63H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动负载突卸瞬态性能测试，对应报告中突卸电压/频率、瞬态偏差、稳定时间测试"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 63 B9"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x63 = 0xB9"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 63 0E"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 试验完成后，可发送67H/68H/69H命令，获取电压/频率/电流突卸的全量瞬态过程数据"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "谐波实验 (70H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动电压/电流谐波分析测试，对应报告中电压波形畸变率Ku%测试项"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 70 C6"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x70 = 0xC6"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 70 1B"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 1.召测波形数据:55 01 71 C7，获取基准相电压/电流128点波形 2.召测谐波数据:55 01 73 C9，获取50次谐波数据用于计算畸变率"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "启动电压整定 (76H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动电压整定试验，对应报告中电压整定范围、稳态电压偏差测试项"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 76 CC"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x76 = 0xCC"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 76 21"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 1.召测数据:55 01 79 CF，获取电压整定范围、稳态电压偏差 2.召测数据:55 01 7A D0，获取稳态频率偏差、频率降"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "启动频率整定 (77H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动频率整定试验，对应报告中频率整定范围、稳态频率偏差测试项"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 77 CD"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x77 = 0xCD"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 77 22"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 1.召测数据:55 01 79 CF，获取电压整定范围、稳态电压偏差 2.召测数据:55 01 7A D0，获取稳态频率偏差、频率降"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "启动录波 (78H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "启动录波功能，对应报告中波形畸变率测试项"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 78 CE"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x78 = 0xCE"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 78 23"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 1.召测波形数据:55 01 71 C7，获取基准相电压/电流128点波形 2.召测谐波数据:55 01 73 C9，获取50次谐波数据用于计算畸变率"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "返回静态 (72H)"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "强制仪表返回静态测量模式，终止当前测试"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "完整发送报文: 55 01 72 C8"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "校验码: 0x55 + 0x01 + 0x72 = 0xC8"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "仪表正常应答: AA 01 72 1D"
                                color: theme.textColor
                                font.pixelSize: 12
                                font.family: "Courier New"
                            }

                            Text {
                                text: "配套说明: 所有实验完成后，建议发送此命令让仪表返回静态测量模式"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 8
                            width: parent.width

                            Text {
                                text: "计算公式"
                                color: theme.textColor
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Text {
                                text: "电压波动率 δUb% = (Max - Min) / (Max + Min) * 100%"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "频率波动率 δFb% = (Max - Min) / (Max + Min) * 100%"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "稳态频率带 βf=(Max - Min) *100%/ 额定频率Fr"
                                color: theme.textColor
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            Component {
                id: parameterInputComponent
                ColumnLayout {
                    spacing: 16

                    ECard {
                        Layout.fillWidth: true
                        padding: 16

                        ColumnLayout {
                            spacing: 12
                            width: parent.width

                            Text {
                                text: "发电机参数设置"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: "请输入发电机参数，带 * 号为必填项"
                                color: theme.textColor
                                font.pixelSize: 12
                                opacity: 0.7
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 8
                            }

                            ColumnLayout {
                                spacing: 10
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "额定电压/V *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempRatedVoltage.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempRatedVoltage = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电压倍率 *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempVoltageMultiplier.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempVoltageMultiplier = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "电流倍率 *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempCurrentMultiplier.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempCurrentMultiplier = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "功率因数 *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempPowerFactor.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempPowerFactor = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "额定功率/KW *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempRatedPower.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempRatedPower = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "额定频率/Hz *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempRatedFrequency.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempRatedFrequency = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "空载频率/Hz *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempNoLoadFrequency.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempNoLoadFrequency = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "满载频率/Hz *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempFullLoadFrequency.toString()

                                        onAccepted: {
                                            var val = parseFloat(text)
                                            if (!isNaN(val)) {
                                                tempFullLoadFrequency = val
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "原动机"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempPrimeMover

                                        onAccepted: {
                                            tempPrimeMover = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "调速器"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempGovernor

                                        onAccepted: {
                                            tempGovernor = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "发电机励磁方式"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempExcitationMode

                                        onAccepted: {
                                            tempExcitationMode = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "环境温度"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempAmbientTemperature

                                        onAccepted: {
                                            tempAmbientTemperature = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "相对湿度"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempRelativeHumidity

                                        onAccepted: {
                                            tempRelativeHumidity = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "大气压力"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempAtmosphericPressure

                                        onAccepted: {
                                            tempAtmosphericPressure = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "测量人员"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempSurveyor

                                        onAccepted: {
                                            tempSurveyor = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "检定人员"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EInput {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        text: tempVerifier

                                        onAccepted: {
                                            tempVerifier = text
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    Text {
                                        text: "基准相 *"
                                        color: theme.textColor
                                        font.pixelSize: 14
                                        Layout.preferredWidth: 140
                                    }

                                    EDropdown {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        model: [
                                            { text: "A相" },
                                            { text: "B相" },
                                            { text: "C相" }
                                        ]
                                        selectedIndex: tempReferencePhase
                                        onSelectionChanged: {
                                            tempReferencePhase = index
                                        }
                                        title: "请选择基准相"
                                        containerColor: theme.secondaryColor
                                        textColor: theme.textColor
                                        horizontalPadding: 12
                                        radius: 8
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 12
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 200
                            }

                            RowLayout {
                                spacing: 12
                                Layout.alignment: Qt.AlignRight

                                EButton {
                                    text: "取消"
                                    size: "s"
                                    containerColor: theme.secondaryColor
                                    textColor: theme.textColor
                                    shadowEnabled: true
                                    onClicked: {
                                        showParameterInput = false
                                    }
                                }

                                EButton {
                                    text: "确定"
                                    size: "s"
                                    containerColor: theme.isDark ? "#2196F3" : "#2196F3"
                                    textColor: "white"
                                    shadowEnabled: true
                                    onClicked: {
                                        saveParameters()
                                        sendAllParameters()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: exportDialogComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: true

            Rectangle {
                id: exportDialog
                width: 360
                height: 320
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "选择导出格式"
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    EButton {
                        id: excelButton
                        Layout.fillWidth: true
                        text: "Excel格式 (.csv)"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            exportReport("excel")
                        }
                    }

                    EButton {
                        id: pdfButton
                        Layout.fillWidth: true
                        text: "PDF格式 (.pdf)"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            exportReport("pdf")
                        }
                    }

                    /* EButton {
                        id: previewButton
                        Layout.fillWidth: true
                        text: "预览报表"
                        size: "s"
                        containerColor: theme.isDark ? "#4CAF50" : "#4CAF50"
                        textColor: "white"
                        shadowEnabled: true
                        onClicked: {
                            showExportDialog = false
                            deviceParamsRequested = false
                            deviceParamsReceived = false
                            pendingPreview = true
                            requestDeviceParams()
                            deviceParamsTimer.start()
                            deviceParamsCheckTimer.start()
                        }
                    } */

                    Item {
                        Layout.fillHeight: true
                    }

                    EButton {
                        id: cancelButton
                        Layout.alignment: Qt.AlignRight
                        text: "取消"
                        size: "s"
                        containerColor: theme.secondaryColor
                        textColor: theme.textColor
                        shadowEnabled: true
                        onClicked: {
                            showExportDialog = false
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: exportDialogLoader
        sourceComponent: showExportDialog ? exportDialogComponent : null
        anchors.fill: parent
    }

    Loader {
        id: parameterSendResultLoader
        sourceComponent: showParameterSendResult ? parameterSendResultComponent : null
        anchors.fill: parent
    }

    // 报表参数配置对话框
    Component {
        id: reportConfigDialogComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: true

            Rectangle {
                id: reportConfigDialog
                width: Math.min(parent.width - 40, 600)
                height: Math.min(parent.height - 40, 650)
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Text {
                        text: "报表参数设置"
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "选择要显示在报表中的内容"
                        color: theme.textColor
                        font.pixelSize: 13
                        opacity: 0.7
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            spacing: 12
                            Layout.fillWidth: true

                            // 主章节配置
                            Repeater {
                                model: {
                                    reportConfigRefreshCounter
                                    return reportConfig.filter(function(item) { return !item.section })
                                }
                                delegate: ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    property string currentSectionId: modelData.id

                                    RowLayout {
                                        spacing: 12
                                        Layout.fillWidth: true

                                        Rectangle {
                                            width: 24
                                            height: 24
                                            border.width: 2
                                            border.color: theme.primaryColor
                                            color: modelData.enabled ? theme.primaryColor : "transparent"
                                            radius: 4

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.enabled ? "✓" : ""
                                                color: "white"
                                                font.pixelSize: 16
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    // 找到原始数组中对应项并修改
                                                    for (var i = 0; i < reportConfig.length; i++) {
                                                        if (reportConfig[i].id === modelData.id) {
                                                            reportConfig[i].enabled = !reportConfig[i].enabled
                                                            break
                                                        }
                                                    }
                                                    reportConfigRefreshCounter++
                                                }
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: theme.textColor
                                            font.pixelSize: 14
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // 子项配置（如果有）
                                    Repeater {
                                        model: {
                                            reportConfigRefreshCounter
                                            return reportConfig.filter(function(item) { return item.section === modelData.id })
                                        }
                                        delegate: RowLayout {
                                            id: subItemRow
                                            spacing: 12
                                            Layout.leftMargin: 36
                                            Layout.fillWidth: true

                                            property bool isEnabled: (function() {
                                                for (var i = 0; i < reportConfig.length; i++) {
                                                    if (reportConfig[i].id === modelData.id) {
                                                        return reportConfig[i].enabled
                                                    }
                                                }
                                                return true
                                            })()

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                border.width: 2
                                                border.color: theme.secondaryColor
                                                color: subItemRow.isEnabled ? theme.primaryColor : "transparent"
                                                radius: 3

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: subItemRow.isEnabled ? "✓" : ""
                                                    color: "white"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        for (var i = 0; i < reportConfig.length; i++) {
                                                            if (reportConfig[i].id === modelData.id) {
                                                                reportConfig[i].enabled = !reportConfig[i].enabled
                                                                break
                                                            }
                                                        }
                                                        reportConfigRefreshCounter++
                                                    }
                                                }
                                            }

                                            Text {
                                                text: modelData.name
                                                color: theme.textColor
                                                font.pixelSize: 13
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        EButton {
                            text: "全选"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            shadowEnabled: true
                            Layout.fillWidth: true
                            onClicked: {
                                for (var i = 0; i < reportConfig.length; i++) {
                                    reportConfig[i].enabled = true
                                }
                                reportConfigRefreshCounter++
                            }
                        }

                        EButton {
                            text: "全不选"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            shadowEnabled: true
                            Layout.fillWidth: true
                            onClicked: {
                                for (var i = 0; i < reportConfig.length; i++) {
                                    reportConfig[i].enabled = false
                                }
                                reportConfigRefreshCounter++
                            }
                        }

                        EButton {
                            text: "重置"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            shadowEnabled: true
                            Layout.fillWidth: true
                            onClicked: {
                                resetReportConfig()
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        EButton {
                            text: "取消"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            shadowEnabled: true
                            Layout.fillWidth: true
                            onClicked: {
                                showReportConfigDialog = false
                            }
                        }

                        EButton {
                            text: "确定"
                            size: "s"
                            containerColor: theme.isDark ? "#4CAF50" : "#4CAF50"
                            textColor: "white"
                            shadowEnabled: true
                            Layout.fillWidth: true
                            onClicked: {
                                showReportConfigDialog = false
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: reportConfigDialogLoader
        sourceComponent: showReportConfigDialog ? reportConfigDialogComponent : null
        anchors.fill: parent
    }

    function getReportData() {
        var date = Qt.formatDateTime(new Date(), "yyyy-MM-dd")
        var time = Qt.formatDateTime(new Date(), "hh:mm:ss")
        
        var ratedVoltageToUse = (deviceParamsReceived && deviceRatedVoltage > 0) ? deviceRatedVoltage : paramSettings.ratedVoltage
        var ratedFrequencyToUse = (deviceParamsReceived && deviceRatedFrequency > 0) ? deviceRatedFrequency : paramSettings.ratedFrequency
        var noLoadFrequencyToUse = (deviceParamsReceived && deviceFrequencySteady > 0) ? deviceFrequencySteady : paramSettings.noLoadFrequency
        var measuredVoltageToUse = (deviceParamsReceived && deviceVoltageSteady > 0) ? deviceVoltageSteady : 0
        var measuredFrequencyToUse = (deviceParamsReceived && deviceFrequencySteady > 0) ? deviceFrequencySteady : 0
        
        var steadyVoltageDeviationStr = ""
        var steadyFrequencyDeviationStr = ""
        var voltageVolatilityStr = ""
        var frequencyVolatilityStr = ""
        var steadyFrequencyBandStr = ""
        var allWaveVoltageMax = 0
        var allWaveVoltageMin = Number.MAX_VALUE
        var voltageSettingRangeStr = ""
        
        var allVoltageMax = 0
        var allVoltageMin = Number.MAX_VALUE
        for (var j = 0; j < tabDataStorage.length; j++) {
            var tabData = tabDataStorage[j]
            if (tabData.waveTestRefPhase !== "") {
                if (tabData.waveTestVoltageMax > allVoltageMax) {
                    allVoltageMax = tabData.waveTestVoltageMax
                }
                if (tabData.waveTestVoltageMin < allVoltageMin) {
                    allVoltageMin = tabData.waveTestVoltageMin
                }
                // 计算电压整定范围（电压数值）
                if (tabData.waveTestVoltageMax > allWaveVoltageMax) {
                    allWaveVoltageMax = tabData.waveTestVoltageMax
                }
                if (tabData.waveTestVoltageMin < allWaveVoltageMin) {
                    allWaveVoltageMin = tabData.waveTestVoltageMin
                }
            }
        }
        
        // 生成电压整定范围字符串（电压数值）
        if (allWaveVoltageMax > 0 && allWaveVoltageMin < Number.MAX_VALUE) {
            voltageSettingRangeStr = allWaveVoltageMin.toFixed(0) + "~" + allWaveVoltageMax.toFixed(0)
        }
        
        if (allVoltageMax > 0 && allVoltageMin < Number.MAX_VALUE && ratedVoltageToUse > 0) {
            var steadyVoltageDeviation = ((allVoltageMax - allVoltageMin) / (2 * ratedVoltageToUse)) * 100
            steadyVoltageDeviationStr = steadyVoltageDeviation.toFixed(2)
        }
        
        // 找到第二个0%负载的数据
        var zeroLoadCount = 0
        var zeroLoadFrequency = 0
        for (var i = 0; i < tabDataStorage.length; i++) {
            var loadLabel = tabLabels[i]
            if (loadLabel === "0%") {
                zeroLoadCount++
                if (zeroLoadCount === 2) {
                    var data = tabDataStorage[i]
                    if (data.staticThreePhaseParamsReceived) {
                        zeroLoadFrequency = data.staticFrequency
                    }
                    break
                }
            }
        }
        
        // 计算频率降
        if (zeroLoadFrequency > 0 && ratedFrequencyToUse > 0) {
            var steadyFrequencyDeviation = ((zeroLoadFrequency - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
            steadyFrequencyDeviationStr = steadyFrequencyDeviation.toFixed(2)
        }
        
        if (testDataHistory["wave"] !== null) {
            var waveData = testDataHistory["wave"]
            if (waveData["voltageVolatility"] !== undefined) {
                voltageVolatilityStr = waveData["voltageVolatility"].toFixed(2)
            }
            if (waveData["frequencyVolatility"] !== undefined) {
                frequencyVolatilityStr = waveData["frequencyVolatility"].toFixed(2)
            }
            if (waveData["frequencyMax"] !== undefined && waveData["frequencyMin"] !== undefined && ratedFrequencyToUse > 0) {
                var fMax = waveData["frequencyMax"]
                var fMin = waveData["frequencyMin"]
                var steadyFrequencyBand = ((fMax - fMin) * 100) / ratedFrequencyToUse
                steadyFrequencyBandStr = steadyFrequencyBand.toFixed(2)
            }
        }
        
        var suddenAddVoltageDeviation = ""
        var suddenAddVoltageStableTime = ""
        var suddenAddFrequencyDeviation = ""
        var suddenAddFrequencyStableTime = ""
        
        var suddenLoadVoltageDeviation = ""
        var suddenLoadVoltageStableTime = ""
        var suddenLoadFrequencyDeviation = ""
        var suddenLoadFrequencyStableTime = ""
        
        // 计算所有功率下的最大值
        var maxSuddenAddVoltageDeviationValue = 0
        var maxSuddenAddVoltageStableTimeValue = 0
        var maxSuddenAddFrequencyDeviationValue = 0
        var maxSuddenAddFrequencyStableTimeValue = 0
        
        var maxSuddenLoadVoltageDeviationValue = 0
        var maxSuddenLoadVoltageStableTimeValue = 0
        var maxSuddenLoadFrequencyDeviationValue = 0
        var maxSuddenLoadFrequencyStableTimeValue = 0
        
        for (var j = 0; j < tabDataStorage.length; j++) {
            var tabData = tabDataStorage[j]
            
            // 处理突加数据
            if (tabData.suddenAddTestExtremeValue > 0) {
                var suddenAddVoltageExtremeRaw = tabData.suddenAddTestExtremeValue
                var suddenAddVoltageExtreme = suddenAddVoltageExtremeRaw / 10
                if (ratedVoltageToUse > 0 && suddenAddVoltageExtreme > 0) {
                    var dev = Math.abs(((suddenAddVoltageExtreme - ratedVoltageToUse) / ratedVoltageToUse) * 100)
                    if (dev > maxSuddenAddVoltageDeviationValue) {
                        maxSuddenAddVoltageDeviationValue = dev
                    }
                }
                if (tabData.suddenAddTestStableTime > maxSuddenAddVoltageStableTimeValue) {
                    maxSuddenAddVoltageStableTimeValue = tabData.suddenAddTestStableTime
                }
            }
            
            if (tabData.suddenAddFrequencyExtremeValue > 0) {
                var suddenAddFrequencyExtremeRaw = tabData.suddenAddFrequencyExtremeValue
                var suddenAddFrequencyExtreme = suddenAddFrequencyExtremeRaw / 100
                if (ratedFrequencyToUse > 0 && suddenAddFrequencyExtreme > 0) {
                    var freqDev = Math.abs(((suddenAddFrequencyExtreme - ratedFrequencyToUse) / ratedFrequencyToUse) * 100)
                    if (freqDev > maxSuddenAddFrequencyDeviationValue) {
                        maxSuddenAddFrequencyDeviationValue = freqDev
                    }
                }
                if (tabData.suddenAddFrequencyStableTime > maxSuddenAddFrequencyStableTimeValue) {
                    maxSuddenAddFrequencyStableTimeValue = tabData.suddenAddFrequencyStableTime
                }
            }
            
            // 处理突卸数据
            if (tabData.suddenLoadTestExtremeValue > 0) {
                var suddenLoadVoltageExtremeRaw = tabData.suddenLoadTestExtremeValue
                var suddenLoadVoltageExtreme = suddenLoadVoltageExtremeRaw / 10
                if (ratedVoltageToUse > 0 && suddenLoadVoltageExtreme > 0) {
                    var loadDev = Math.abs(((suddenLoadVoltageExtreme - ratedVoltageToUse) / ratedVoltageToUse) * 100)
                    if (loadDev > maxSuddenLoadVoltageDeviationValue) {
                        maxSuddenLoadVoltageDeviationValue = loadDev
                    }
                }
                if (tabData.suddenLoadTestStableTime > maxSuddenLoadVoltageStableTimeValue) {
                    maxSuddenLoadVoltageStableTimeValue = tabData.suddenLoadTestStableTime
                }
            }
            
            if (tabData.suddenLoadFrequencyExtremeValue > 0) {
                var suddenLoadFrequencyExtremeRaw = tabData.suddenLoadFrequencyExtremeValue
                var suddenLoadFrequencyExtreme = suddenLoadFrequencyExtremeRaw / 100
                if (ratedFrequencyToUse > 0 && suddenLoadFrequencyExtreme > 0) {
                    var loadFreqDev = Math.abs(((suddenLoadFrequencyExtreme - ratedFrequencyToUse) / ratedFrequencyToUse) * 100)
                    if (loadFreqDev > maxSuddenLoadFrequencyDeviationValue) {
                        maxSuddenLoadFrequencyDeviationValue = loadFreqDev
                    }
                }
                if (tabData.suddenLoadFrequencyStableTime > maxSuddenLoadFrequencyStableTimeValue) {
                    maxSuddenLoadFrequencyStableTimeValue = tabData.suddenLoadFrequencyStableTime
                }
            }
        }
        
        if (maxSuddenAddVoltageDeviationValue > 0) {
            suddenAddVoltageDeviation = maxSuddenAddVoltageDeviationValue.toFixed(2)
        }
        if (maxSuddenAddVoltageStableTimeValue > 0) {
            suddenAddVoltageStableTime = (maxSuddenAddVoltageStableTimeValue / 1000).toFixed(3)
        }
        if (maxSuddenAddFrequencyDeviationValue > 0) {
            suddenAddFrequencyDeviation = maxSuddenAddFrequencyDeviationValue.toFixed(2)
        }
        if (maxSuddenAddFrequencyStableTimeValue > 0) {
            suddenAddFrequencyStableTime = (maxSuddenAddFrequencyStableTimeValue / 1000).toFixed(3)
        }
        
        if (maxSuddenLoadVoltageDeviationValue > 0) {
            suddenLoadVoltageDeviation = maxSuddenLoadVoltageDeviationValue.toFixed(2)
        }
        if (maxSuddenLoadVoltageStableTimeValue > 0) {
            suddenLoadVoltageStableTime = (maxSuddenLoadVoltageStableTimeValue / 1000).toFixed(3)
        }
        if (maxSuddenLoadFrequencyDeviationValue > 0) {
            suddenLoadFrequencyDeviation = maxSuddenLoadFrequencyDeviationValue.toFixed(2)
        }
        if (maxSuddenLoadFrequencyStableTimeValue > 0) {
            suddenLoadFrequencyStableTime = (maxSuddenLoadFrequencyStableTimeValue / 1000).toFixed(3)
        }
        
        var voltageDistortionRateStr = ""
        if (testDataHistory["harmonic"] !== null) {
            var harmonicData = testDataHistory["harmonic"]
            if (harmonicData["voltageDistortionRate"] !== undefined && harmonicData["voltageDistortionRate"] > 0) {
                voltageDistortionRateStr = harmonicData["voltageDistortionRate"].toFixed(4)
            }
        }
        
        var tableData = []
        for (var i = 0; i < tabDataStorage.length; i++) {
            var loadLabel = tabLabels[i]
            var data = tabDataStorage[i]
            // 始终使用基于标签百分比计算的功率值
            var percentage = parseFloat(loadLabel) / 100
            var power = paramSettings.ratedPower * percentage
            var powerValue = power.toFixed(2)
            // 计算当前负载的稳态频率带
            var steadyFreqBandValue = ""
            if (data.waveTestRefPhase !== "" && ratedFrequencyToUse > 0) {
                if (data.waveTestFrequencyMax > 0 && data.waveTestFrequencyMin > 0) {
                    var steadyFreqBand = ((data.waveTestFrequencyMax - data.waveTestFrequencyMin) * 100) / ratedFrequencyToUse
                    steadyFreqBandValue = steadyFreqBand.toFixed(2)
                }
            }
            // 计算频率整定范围（使用当前负载的频率整定数据）
            var freqRangeUp = ""
            var freqRangeDown = ""
            if (data.frequencyCalibrationRefPhase !== "" && ratedFrequencyToUse > 0) {
                if (data.frequencyCalibrationFmax > 0) {
                    var upValue = ((data.frequencyCalibrationFmax - ratedFrequencyToUse) / ratedFrequencyToUse) * 100
                    freqRangeUp = upValue.toFixed(2)
                }
                if (data.frequencyCalibrationFmin > 0) {
                    var downValue = ((ratedFrequencyToUse - data.frequencyCalibrationFmin) / ratedFrequencyToUse) * 100
                    freqRangeDown = downValue.toFixed(2)
                }
            }
            
            tableData.push({
                load: loadLabel,
                power: powerValue,
                ua: data.staticThreePhaseParamsReceived ? data.staticVoltageA.toFixed(2) : "",
                ub: data.staticThreePhaseParamsReceived ? data.staticVoltageB.toFixed(2) : "",
                uc: data.staticThreePhaseParamsReceived ? data.staticVoltageC.toFixed(2) : "",
                ia: data.staticThreePhaseParamsReceived ? data.staticCurrentA.toFixed(2) : "",
                ib: data.staticThreePhaseParamsReceived ? data.staticCurrentB.toFixed(2) : "",
                ic: data.staticThreePhaseParamsReceived ? data.staticCurrentC.toFixed(2) : "",
                pf: data.staticThreePhaseParamsReceived ? data.staticPowerFactor.toFixed(4) : "",
                freq: data.staticThreePhaseParamsReceived ? data.staticFrequency.toFixed(3) : "",
                steadyFreqBand: steadyFreqBandValue,
                freqRangeUp: freqRangeUp,
                freqRangeDown: freqRangeDown
            })
        }
        
        // 确保数值转换为字符串格式，便于显示
        var ratedVoltageStr = ""
        if (ratedVoltageToUse > 0) {
            ratedVoltageStr = String(ratedVoltageToUse)
        } else if (paramSettings.ratedVoltage > 0) {
            ratedVoltageStr = String(paramSettings.ratedVoltage)
        }
        
        var ratedFrequencyStr = ""
        if (ratedFrequencyToUse > 0) {
            ratedFrequencyStr = String(ratedFrequencyToUse)
        } else if (paramSettings.ratedFrequency > 0) {
            ratedFrequencyStr = String(paramSettings.ratedFrequency)
        }
        
        var ratedPowerStr = ""
        if (paramSettings.ratedPower && paramSettings.ratedPower > 0) {
            ratedPowerStr = String(paramSettings.ratedPower)
        }
        
        var powerFactorStr = ""
        if (paramSettings.powerFactor !== undefined && paramSettings.powerFactor !== null) {
            powerFactorStr = String(paramSettings.powerFactor)
        }
        
        var relativeHumidityStr = paramSettings.relativeHumidity ? String(paramSettings.relativeHumidity) : ""
        var ambientTemperatureStr = paramSettings.ambientTemperature ? String(paramSettings.ambientTemperature) : ""
        var atmosphericPressureStr = paramSettings.atmosphericPressure ? String(paramSettings.atmosphericPressure) : ""
        
        console.log("getReportData - 额定电压值:", ratedVoltageToUse, "显示字符串:", ratedVoltageStr)
        console.log("getReportData - 额定频率值:", ratedFrequencyToUse, "显示字符串:", ratedFrequencyStr)
        
        return {
            date: date,
            time: time,
            ratedVoltage: ratedVoltageStr,
            ratedFrequency: ratedFrequencyStr,
            ratedPower: ratedPowerStr,
            powerFactor: powerFactorStr,
            governor: paramSettings.governor ? paramSettings.governor : "",
            excitationMode: paramSettings.excitationMode ? paramSettings.excitationMode : "",
            relativeHumidity: relativeHumidityStr,
            ambientTemperature: ambientTemperatureStr,
            atmosphericPressure: atmosphericPressureStr,
            surveyor: paramSettings.surveyor ? paramSettings.surveyor : "",
            verifier: paramSettings.verifier ? paramSettings.verifier : "",
            steadyVoltageDeviation: steadyVoltageDeviationStr,
            steadyFrequencyDeviation: steadyFrequencyDeviationStr,
            steadyFrequencyBand: steadyFrequencyBandStr,
            suddenAddVoltageDeviation: suddenAddVoltageDeviation,
            suddenAddVoltageStableTime: suddenAddVoltageStableTime,
            suddenAddFrequencyDeviation: suddenAddFrequencyDeviation,
            suddenAddFrequencyStableTime: suddenAddFrequencyStableTime,
            suddenLoadVoltageDeviation: suddenLoadVoltageDeviation,
            suddenLoadVoltageStableTime: suddenLoadVoltageStableTime,
            suddenLoadFrequencyDeviation: suddenLoadFrequencyDeviation,
            suddenLoadFrequencyStableTime: suddenLoadFrequencyStableTime,
            voltageSettingRange: voltageSettingRangeStr,
            voltageDistortionRate: voltageDistortionRateStr,
            tableData: tableData
        }
    }

    property var currentReportData: null

    Component {
        id: reportPreviewComponent
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            visible: true

            property var reportData: null

            function initModels() {
                if (!reportData) return

                techSpecListModel.clear()
                techSpecListModel.append({
                    col1: "1、机组型号",
                    col2: "0",
                    col3: "机组编号",
                    col4: "0",
                    col5: "视在功率",
                    col6: "0",
                    col7: "额定功率",
                    col8: reportData.ratedPower,
                    col9: "功率因数",
                    col10: reportData.powerFactor
                })
                techSpecListModel.append({
                    col1: "2、额定频率",
                    col2: reportData.ratedFrequency,
                    col3: "额定电压",
                    col4: reportData.ratedVoltage,
                    col5: "额定电流",
                    col6: "0",
                    col7: "控制屏型号",
                    col8: "",
                    col9: "控制屏编号",
                    col10: ""
                })
                techSpecListModel.append({
                    col1: "3、引擎型号",
                    col2: "",
                    col3: "引擎编号",
                    col4: "",
                    col5: "原产地",
                    col6: "",
                    col7: "调速器",
                    col8: reportData.governor,
                    col9: "",
                    col10: ""
                })
                techSpecListModel.append({
                    col1: "4、电机型号",
                    col2: "",
                    col3: "电机编号",
                    col4: "",
                    col5: "原产地",
                    col6: "",
                    col7: "励磁方式",
                    col8: reportData.excitationMode,
                    col9: "AVR型号",
                    col10: ""
                })

                testItemListModel.clear()
                testItemListModel.append({
                    col1: "1、相对湿度(%)：",
                    col2: reportData.relativeHumidity,
                    col3: "环境温度(℃)：",
                    col4: reportData.ambientTemperature,
                    col5: "大气压力(kPa)：",
                    col6: reportData.atmosphericPressure,
                    col7: "检查机组外观：",
                    col8: ""
                })
                testItemListModel.append({
                    col1: "2、检查指示仪表",
                    col2: "",
                    col3: "检查超速停机",
                    col4: "",
                    col5: "检查高水温保护",
                    col6: "",
                    col7: "检查高缸温保护",
                    col8: ""
                })
                testItemListModel.append({
                    col1: "检查低油压保护",
                    col2: "",
                    col3: "检查紧急停机",
                    col4: "",
                    col5: "检查电池充电",
                    col6: "",
                    col7: "",
                    col8: ""
                })
                testItemListModel.append({
                    col1: "3、测量电枢绕组对地绝缘电阻(Ω)",
                    col2: "",
                    col3: "测量励磁绕组对地绝缘电阻(Ω)",
                    col4: "",
                    col5: "测量副励磁绕组对地绝缘电阻(Ω)",
                    col6: "",
                    col7: "",
                    col8: ""
                })
                testItemListModel.append({
                    col1: "绝缘介质强度试验",
                    col2: "",
                    col3: "检查相序",
                    col4: "",
                    col5: "检查常温启动性能（启动三次）",
                    col6: "",
                    col7: "",
                    col8: ""
                })

                mainDataListModel.clear()
                if (reportData.tableData) {
                    for (var i = 0; i < reportData.tableData.length; i++) {
                        mainDataListModel.append(reportData.tableData[i])
                    }
                }

                testResultListModel.clear()
                testResultListModel.append({
                    col1: "测试结果",
                    col2: "电压波形畸变率Ku%:",
                    col3: reportData.voltageDistortionRate,
                    col4: "稳态电压偏差δUst%:",
                    col5: reportData.steadyVoltageDeviation,
                    col6: "稳态频率带βF%:",
                    col7: reportData.steadyFrequencyBand,
                    col8: "",
                    col9: "",
                    col10: "",
                    col11: "",
                    col12: "",
                    col13: "",
                    col14: ""
                })
                testResultListModel.append({
                    col1: "",
                    col2: "频率降δFst%:",
                    col3: reportData.steadyFrequencyDeviation,
                    col4: "电压整定范围:",
                    col5: reportData.voltageSettingRange,
                    col6: "",
                    col7: "",
                    col8: "",
                    col9: "",
                    col10: "",
                    col11: "",
                    col12: "",
                    col13: "",
                    col14: ""
                })

                transientTestListModel.clear()
                transientTestListModel.append({
                    col1: "",
                    col2: "突加电压瞬态电压偏差δu%:",
                    col3: reportData.suddenAddVoltageDeviation,
                    col4: "突加电压稳定时间(s):",
                    col5: reportData.suddenAddVoltageStableTime,
                    col6: "突加频率瞬态频率偏差δf%:",
                    col7: reportData.suddenAddFrequencyDeviation,
                    col8: "突加频率稳定时间(s):",
                    col9: reportData.suddenAddFrequencyStableTime,
                    col10: "",
                    col11: "",
                    col12: "",
                    col13: "",
                    col14: ""
                })
                transientTestListModel.append({
                    col1: "",
                    col2: "突卸电压瞬态电压偏差δu%:",
                    col3: reportData.suddenLoadVoltageDeviation,
                    col4: "突卸电压稳定时间(s):",
                    col5: reportData.suddenLoadVoltageStableTime,
                    col6: "突卸频率瞬态频率偏差δf%:",
                    col7: reportData.suddenLoadFrequencyDeviation,
                    col8: "突卸频率稳定时间(s):",
                    col9: reportData.suddenLoadFrequencyStableTime,
                    col10: "",
                    col11: "",
                    col12: "",
                    col13: "",
                    col14: ""
                })

                conclusionListModel.clear()
                conclusionListModel.append({
                    col1: "测试人员：",
                    col2: reportData.surveyor,
                    col3: "检验人员：",
                    col4: reportData.verifier,
                    col5: "审核人：",
                    col6: "",
                    col7: "会签：",
                    col8: ""
                })
            }

            Rectangle {
                id: previewDialog
                width: Math.min(parent.width - 40, 1100)
                height: Math.min(parent.height - 40, 750)
                anchors.centerIn: parent
                color: theme.secondaryColor
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Text {
                        text: "机组稳态性能测试报告"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "标准：GB/T 2820.1-2009    试验日期：" + (reportData ? reportData.date : "") + "    试验时间：" + (reportData ? reportData.time : "")
                        color: theme.textColor
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 8
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            spacing: 16

                            Text {
                                text: " 技术规格"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: techSpecTable
                                Layout.fillWidth: true
                                height: 180
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 32
                                fontSize: 11

                                headers: [
                                    { key: "col1", label: "" },
                                    { key: "col2", label: "" },
                                    { key: "col3", label: "" },
                                    { key: "col4", label: "" },
                                    { key: "col5", label: "" },
                                    { key: "col6", label: "" },
                                    { key: "col7", label: "" },
                                    { key: "col8", label: "" },
                                    { key: "col9", label: "" },
                                    { key: "col10", label: "" }
                                ]

                                model: ListModel {
                                    id: techSpecListModel
                                }
                            }

                            Text {
                                text: " 试验项目"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: testItemTable
                                Layout.fillWidth: true
                                height: 150
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 30
                                fontSize: 11

                                headers: [
                                    { key: "col1", label: "" },
                                    { key: "col2", label: "" },
                                    { key: "col3", label: "" },
                                    { key: "col4", label: "" },
                                    { key: "col5", label: "" },
                                    { key: "col6", label: "" },
                                    { key: "col7", label: "" },
                                    { key: "col8", label: "" }
                                ]

                                model: ListModel {
                                    id: testItemListModel
                                }
                            }

                            Text {
                                text: " 测量电压和额定频率的稳态参数"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: mainDataTable
                                Layout.fillWidth: true
                                height: 400
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 32
                                fontSize: 11

                                headers: [
                                    { key: "load", label: "负载" },
                                    { key: "power", label: "功率(kW)" },
                                    { key: "ua", label: "UA(V)" },
                                    { key: "ub", label: "UB(V)" },
                                    { key: "uc", label: "UC(V)" },
                                    { key: "ia", label: "IA(A)" },
                                    { key: "ib", label: "IB(A)" },
                                    { key: "ic", label: "IC(A)" },
                                    { key: "pf", label: "稳态功率因数" },
                                    { key: "freq", label: "频率F1 (Hz)" },
                                    { key: "steadyFreqBand", label: "稳态频率带βF%" },
                                    { key: "freqRangeUp", label: "频率整定范围上升(%)" },
                                    { key: "freqRangeDown", label: "频率整定范围下降(%)" }
                                ]

                                model: ListModel {
                                    id: mainDataListModel
                                }
                            }

                            Text {
                                text: "测试结果"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: testResultTable
                                Layout.fillWidth: true
                                height: 120
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 32
                                fontSize: 11

                                headers: [
                                    { key: "col1", label: "" },
                                    { key: "col2", label: "" },
                                    { key: "col3", label: "" },
                                    { key: "col4", label: "" },
                                    { key: "col5", label: "" },
                                    { key: "col6", label: "" },
                                    { key: "col7", label: "" },
                                    { key: "col8", label: "" },
                                    { key: "col9", label: "" },
                                    { key: "col10", label: "" },
                                    { key: "col11", label: "" },
                                    { key: "col12", label: "" },
                                    { key: "col13", label: "" },
                                    { key: "col14", label: "" }
                                ]

                                model: ListModel {
                                    id: testResultListModel
                                }
                            }

                            Text {
                                text: " 瞬态测试"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: transientTestTable
                                Layout.fillWidth: true
                                height: 120
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 32
                                fontSize: 11

                                headers: [
                                    { key: "col1", label: "" },
                                    { key: "col2", label: "" },
                                    { key: "col3", label: "" },
                                    { key: "col4", label: "" },
                                    { key: "col5", label: "" },
                                    { key: "col6", label: "" },
                                    { key: "col7", label: "" },
                                    { key: "col8", label: "" },
                                    { key: "col9", label: "" },
                                    { key: "col10", label: "" },
                                    { key: "col11", label: "" },
                                    { key: "col12", label: "" },
                                    { key: "col13", label: "" },
                                    { key: "col14", label: "" }
                                ]

                                model: ListModel {
                                    id: transientTestListModel
                                }
                            }

                            Text {
                                text: "实验结论"
                                color: theme.textColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            EDataTable {
                                id: conclusionTable
                                Layout.fillWidth: true
                                height: 100
                                backgroundVisible: true
                                shadowEnabled: false
                                radius: 8
                                headerHeight: 36
                                rowHeight: 32
                                fontSize: 11

                                headers: [
                                    { key: "col1", label: "" },
                                    { key: "col2", label: "" },
                                    { key: "col3", label: "" },
                                    { key: "col4", label: "" },
                                    { key: "col5", label: "" },
                                    { key: "col6", label: "" },
                                    { key: "col7", label: "" },
                                    { key: "col8", label: "" }
                                ]

                                model: ListModel {
                                    id: conclusionListModel
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: 20
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 12

                        EButton {
                            text: "关闭"
                            size: "s"
                            containerColor: theme.secondaryColor
                            textColor: theme.textColor
                            shadowEnabled: true
                            onClicked: {
                                showReportPreview = false
                            }
                        }

                        EButton {
                            text: "导出报表"
                            size: "s"
                            containerColor: theme.isDark ? "#2196F3" : "#2196F3"
                            textColor: "white"
                            shadowEnabled: true
                            onClicked: {
                                showReportPreview = false
                                showExportDialog = true
                            }
                        }
                    }
                }

                Component.onCompleted: {
                    reportData = getReportData()
                    initModels()
                }
            }
        }
    }

    Loader {
        id: reportPreviewLoader
        sourceComponent: showReportPreview ? reportPreviewComponent : null
        anchors.fill: parent
    }

    Loader {
        id: waitingDialogLoader
        sourceComponent: showWaitingDialog ? waitingDialogComponent : null
        anchors.fill: parent
    }

    Loader {
        id: testConfigDialogLoader
        sourceComponent: showTestConfigDialog ? testConfigDialogComponent : null
        anchors.fill: parent
    }
}