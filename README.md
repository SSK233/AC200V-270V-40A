# 负载箱测试系统

基于 Qt 6 的 Modbus RTU 通信测试与数据采集系统。

## 项目概述

这是一个用于负载箱设备测试的上位机软件，支持通过 Modbus RTU 协议与设备通信，实现电压、电流、功率等参数的实时监控与数据记录。

## 安装包

demo4setup.exe

## 目录结构

```
demo4/
├── components/              # QML 组件库
│   ├── ETheme.qml          # 主题配置（深色/浅色模式）
│   ├── EButton.qml       # 按钮组件
│   ├── ECard.qml          # 卡片组件
│   ├── EAreaChart.qml     # 面积图组件（波形显示）
│   ├── EAlertDialog.qml   # 确认对话框
│   ├── EDropdown.qml     # 下拉选择框
│   ├── EInput.qml       # 输入框
│   ├── ESwitchButton.qml # 开关按钮
│   ├── EList.qml        # 列表组件
│   ├── WaveformDataManager.qml  # 波形数据管理器
│   ├── EDataRecorder.qml # 数据记录器组件
│   └── ...               # 其他UI组件
├── pages/                  # 页面文件
│   ├── HomePage.qml       # 首页 - 设备控制
│   ├── WaveformPage.qml   # 波形图页 - 数据记录
│   ├── SettingsPage.qml   # 设置页
│   └── StepRunPage.qml    # 步骤运行页面
├── serial/                 # C++ 后端模块
│   ├── SerialPortManager.h/cpp   # 串口管理
│   ├── ModbusManager.h/cpp        # Modbus 通信管理
│   └── DataRecorder.h/cpp        # 数据记录器
├── fonts/                  # 资源文件
│   ├── fontawesome-free-6.7.2-desktop/  # Font Awesome 图标字体
│   └── pic/              # 背景图片
├── Main.qml               # 主窗口
├── main.cpp              # 程序入口
├── CMakeLists.txt       # CMake 配置
├── package.bat           # 打包脚本
├── app.rc                # 应用资源文件
└── src.qrc             # 资源文件
```

## 核心功能

### 1. 首页 (HomePage)

- **串口通信控制**
  - 串口选择与连接
  - 波特率、校验位配置
  - 串口开关控制
- **设备控制**
  - 风机开关控制
  - 风机状态显示
  - 高温报警状态显示
  - 急停控制
- **参数设置**
  - 电流输入与显示（3路）
  - 载入/卸载操作（3路独立控制）

### 2. 波形图页 (WaveformPage)

**注意：** 波形图显示界面和数据记录功能已移除，仅保留qml文件作为备用。

### 3. 步骤运行页 (StepRunPage)

- **步骤化运行控制**
  - 多步骤参数设置
  - 运行状态监控
  - 自动执行流程

## C++ 后端模块

### SerialPortManager

串口通信管理类，负责：

- 扫描可用串口
- 串口打开/关闭
- 数据收发

### ModbusManager

Modbus RTU 通信管理类，负责：

- 读取风机状态
- 读取高温报警状态
- 控制风机开关
- 写入电流设定值（3路）
- 控制卸载操作（3路独立控制）
- 控制急停操作

### DataRecorder

**注意：** 数据记录功能已移除，仅保留类文件作为备用。

## 技术栈

- **框架**: Qt 6.8+
- **语言**: C++17 + QML
- **通信协议**: Modbus RTU
- **构建系统**: CMake 3.16+
- **UI组件库**: EvolveUI（自定义组件库）

## 编译要求

### 依赖项

```bash
# Qt 6 模块：
- Qt6::Quick
- Qt6::Multimedia
- Qt6::Network
- Qt6::SerialPort
- Qt6::SerialBus
```

### 编译命令

```bash
mkdir build && cd build
cmake ..
cmake --build .
```

## 注意事项

### 1. Modbus 通信配置

- **串口参数**必须与设备一致\*\*
  - 波特率：默认 9600
  - 数据位：8
  - 停止位：1
  - 校验位：无校验/奇校验/偶校验
- **寄存器地址映射**
  - **读取寄存器**
    - 风机状态：从站地址 1，寄存器 2 (只读)
    - 高温报警：从站地址 1，寄存器 3 (只读)
  - **写入寄存器**
    - 设定电流（1路）：从站地址 1，寄存器 50 (只写)
    - 设定电流（2路）：从站地址 1，寄存器 51 (只写)
    - 设定电流（3路）：从站地址 1，寄存器 52 (只写)
    - 风机控制：从站地址 1，寄存器 1 (只写)
    - 卸载命令（1路）：从站地址 1，寄存器 35 (只写)
    - 卸载命令（2路）：从站地址 1，寄存器 36 (只写)
    - 卸载命令（3路）：从站地址 1，寄存器 37 (只写)
    - 卸载命令（全部）：从站地址 1，寄存器 38 (只写)
    - 急停控制：从站地址 1，寄存器 5 (只写)

### 2. 功能变更说明

- **波形图显示**：已移除，仅保留qml文件作为备用
- **数据记录**：已移除，仅保留相关类文件作为备用

### 3. 主题切换

- 支持深色/浅色两种主题模式
- 背景图片随主题自动切换

### 4. 开发注意事项

- **QML 信号处理**：Qt 6 要求使用 `function()` 语法
  ```qml
  // 正确写法
  onSignalName: function(param) { ... }
  ```
- **Canvas 绑制颜色**：必须使用 `Qt.rgba()` 格式
  ```qml
  ctx.strokeStyle = Qt.rgba(r, g, b, a);
  ```
- **Q\_PROPERTY 通知**：属性变更需要发送 NOTIFY 信号以支持 QML 绑定

## 许可证

本项目仅供学习和测试使用。

## 作者

新胜电阻器有限公司，skf
