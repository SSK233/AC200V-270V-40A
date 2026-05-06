# AC200V-270V-40A 负载箱测试系统

基于 Qt 6 的 Modbus RTU 通信测试与数据采集系统，用于负载箱设备测试的上位机软件。

## 项目概述

本项目通过 Modbus RTU 协议与负载箱设备通信，实现电压/电流设置、风机控制、电气参数实时监控、发电机测试等功能。

## 目录结构

```
AC200V-270V-40A/
├── components/                  # QML 自定义组件库 (EvolveUI)
│   ├── ETheme.qml              # 主题配置（深色/浅色模式）
│   ├── EButton.qml             # 按钮组件
│   ├── ECard.qml               # 卡片组件
│   ├── EHoverCard.qml          # 悬浮卡片组件
│   ├── ESwitchButton.qml       # 开关按钮
│   ├── EDropdown.qml           # 下拉选择框
│   ├── EInput.qml              # 输入框
│   ├── EAlertDialog.qml        # 确认对话框
│   ├── EAreaChart.qml          # 面积图组件
│   ├── EBarChart.qml           # 柱状图组件
│   ├── EPieChart.qml           # 饼图组件
│   ├── EDataTable.qml          # 数据表格组件
│   ├── EList.qml               # 列表组件
│   ├── EAccordion.qml          # 手风琴折叠面板
│   ├── ECarousel.qml           # 轮播组件
│   ├── ESlider.qml             # 滑块组件
│   ├── ECheckBox.qml           # 复选框
│   ├── ERadioButton.qml        # 单选按钮
│   ├── EClock.qml              # 时钟组件
│   ├── EClockCard.qml          # 时钟卡片（含天气）
│   ├── ECalendar.qml           # 日历组件
│   ├── EColorPicker.qml        # 颜色选择器
│   ├── EDrawer.qml             # 抽屉组件
│   ├── EToast.qml              # 提示组件
│   ├── ENavBar.qml             # 导航栏
│   ├── ELoader.qml             # 加载动画
│   ├── EAnimatedWindow.qml     # 动画窗口
│   ├── EDataRecorder.qml       # 数据记录器组件
│   ├── WaveformDataManager.qml # 波形数据管理器
│   ├── MessageToast.qml        # 消息提示组件
│   └── ...
├── pages/                      # 页面文件
│   ├── HomePage.qml            # 首页 - 设备控制与电气参数
│   ├── SettingsPage.qml        # 设置页 - 主题切换/调试模式
│   └── ManualPage.qml          # 操作说明页
├── serial/                     # C++ 后端模块
│   ├── SerialPortManager.h/cpp     # 串口管理
│   ├── ModbusManager.h/cpp         # Modbus RTU 通信管理
│   ├── GeneratorTestManager.h/cpp  # 发电机测试管理
│   ├── SerialRequestManager.h/cpp  # 串口请求队列管理
│   └── DataRecorder.h/cpp          # 数据记录器
├── fonts/                      # 资源文件
│   ├── fontawesome-free-6.7.2-desktop/  # Font Awesome 图标字体
│   └── pic/                    # 背景图片
├── Main.qml                    # 主窗口
├── main.cpp                    # 程序入口
├── CMakeLists.txt              # CMake 配置
├── package.bat                 # 打包脚本
├── app.rc                      # 应用资源文件
└── src.qrc                     # Qt 资源文件
```

## 当前活动页面

### 1. 首页 (HomePage)

- **串口通信控制**
  - 刷新可用串口列表
  - 串口选择与连接
  - 波特率配置（1200 ~ 115200，默认 9600）
  - 校验位配置（无校验/奇校验/偶校验）
  - 串口开关控制
- **风机控制**
  - 风机开关1控制（从站1）
  - 风机状态指示灯（绿色运行/红色停止）
- **设备状态监测**
  - 高温报警状态指示灯
  - 急停按钮
- **电气参数显示**
  - 单相电压、电流、功率实时显示
  - 三相电气参数（A/B/C 相电压、电流、频率，默认隐藏）
- **电压/电流设置**
  - 电压输入：范围 200 ~ 270V，步进 1V
  - 电流输入：范围 0.1 ~ 40A，步进 0.1A
  - 载入/卸载操作
- **运行时间统计**
  - 累计运行时间
  - 本次运行时间
- **时钟与天气**
  - 实时数字时钟
  - 网络天气信息展示

### 2. 设置页 (SettingsPage)

- 深色/浅色主题切换
- 调试模式开关（仅供开发人员使用）

### 3. 操作说明页 (ManualPage)

- 首页操作详细说明
- 发电机测试操作说明（含一键测试步骤）
- 设置页面操作说明
- 报表参数说明
- 使用注意事项

## C++ 后端模块

### SerialPortManager

串口通信管理类，负责：

- 扫描系统可用串口
- 串口打开/关闭
- 数据收发
- 串口配置（波特率、数据位、停止位、校验位）

### ModbusManager

Modbus RTU 通信管理类，负责：

- 连接/断开 Modbus 设备
- 定时读取寄存器数据
- 单相电气参数读取（电压、电流、功率）
- 风机状态读取与写入
- 高温报警状态读取
- 电流设定值写入
- 卸载操作控制
- 急停控制
- 电压模式/电压值写入

### GeneratorTestManager

发电机测试通信管理类，负责：

- 设备参数读取（PT/CT 变比、额定值等）
- 三相电参数读取与解析
- 波动实验（电压/频率波动率测试）
- 突加实验（负载突增瞬态特性测试）
- 突卸实验（负载突减瞬态特性测试）
- 谐波测试（波形畸变率测试）
- 电压/频率整定测试
- IEEE754 浮点数转换
- 校验和计算

### SerialRequestManager

串口请求队列管理类，负责：

- 优先级请求队列（Critical > High > Normal > Low）
- 请求间隔控制（防止发送过快）
- 响应超时与重传机制
- 重复请求检测
- 数据完整收集

### DataRecorder

数据记录器（备用状态，功能已移除）。

## Modbus 寄存器地址映射

| 功能 | 从站地址 | 寄存器地址 | 读写 |
|------|---------|-----------|------|
| 风机控制 | 1 | 1 | 只写 |
| 风机状态 | 1 | 2 | 只读 |
| 高温报警 | 1 | 3 | 只读 |
| 急停控制 | 1 | 5 | 只写 |
| 电压模式/设定 | 1 | 30 | 只写 |
| 设定电流（1路） | 1 | 50 | 只写 |
| 设定电流（2路） | 1 | 51 | 只写 |
| 设定电流（3路） | 1 | 52 | 只写 |
| 卸载（1路） | 1 | 35 | 只写 |
| 卸载（2路） | 1 | 36 | 只写 |
| 卸载（3路） | 1 | 37 | 只写 |
| 全部卸载 | 1 | 38 | 只写 |

## 已移除/隐藏功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 波形图显示 | 已移除 | CMakeLists 和 Main.qml 中已注释，QML 文件保留备用 |
| 数据记录 | 已移除 | DataRecorder 类保留备用，功能已停用 |
| 分步运行页 | 已隐藏 | StepRunPage.qml 存在但导航和 StackLayout 中已注释 |
| 发电机测试页 | 已隐藏 | GeneratorTestPage.qml 存在但导航和 StackLayout 中已注释 |
| 从站2 | 已移除 | 从站2 风机和高温报警相关代码已注释 |

## 技术栈

- **框架**: Qt 6.8+
- **语言**: C++17 + QML
- **通信协议**: Modbus RTU
- **构建系统**: CMake 3.16+
- **UI 组件库**: EvolveUI（自定义组件库）

## 编译要求

### 依赖项

```bash
# Qt 6 模块：
- Qt6::Quick
- Qt6::Multimedia
- Qt6::Network
- Qt6::SerialPort
- Qt6::SerialBus
- Qt6::Pdf
```

### 编译命令

```bash
mkdir build && cd build
cmake ..
cmake --build .
```

## 使用说明

### 基本操作流程

1. **连接串口**：刷新串口 → 选择串口 → 配置波特率/校验位 → 打开串口开关
2. **启动风机**：打开风机开关1，等待风机状态显示"运行"
3. **设置参数**：输入电压值（200~270V）和电流值（0.1~40A）
4. **执行操作**：点击"载入"将参数写入设备，点击"卸载"清除设定
5. **紧急停止**：点击"急停"按钮可立即停止所有设备运行

### 注意事项

- 串口参数必须与设备一致
- 风机运行时才能进行电流载入操作
- 急停后需重新开启风机开关才能继续操作
- 调试模式仅供开发人员使用，请勿在生产环境中开启

## 作者

新胜电阻器有限公司，skf
