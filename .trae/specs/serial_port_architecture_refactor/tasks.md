# 串口架构重构 - The Implementation Plan (Decomposed and Prioritized Task List)

## [ ] Task 1: 增强 SerialPortManager 支持原始字节操作
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 扩展 SerialPortManager，增加支持 QByteArray 直接读写的方法
  - 保持现有的 QString 接口不变
  - 新增信号，支持原始字节数据通知
- **Acceptance Criteria Addressed**: [AC-1]
- **Test Requirements**:
  - `programmatic` TR-1.1: 验证新增的 writeBytes 和 readBytes 方法能正常工作
  - `programmatic` TR-1.2: 验证 bytesReceived 信号能正确发送原始数据
- **Notes**: 需要设计好接口，使其既能被 C++ 调用，也能被 QML 调用

## [ ] Task 2: 重构 ModbusManager 使用 SerialPortManager
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 移除 ModbusManager 中直接使用 QModbusRtuSerialMaster 打开串口的代码
  - 修改 ModbusManager，通过 SerialPortManager 进行数据收发
  - 实现 Modbus RTU 帧的组装和解析
  - 保持现有的 ModbusManager 公开接口不变
- **Acceptance Criteria Addressed**: [AC-2, AC-4]
- **Test Requirements**:
  - `programmatic` TR-2.1: 验证 ModbusManager 不再直接打开串口
  - `programmatic` TR-2.2: 验证 Modbus 读写操作能正常工作
  - `programmatic` TR-2.3: 验证没有串口访问冲突错误
- **Notes**: 这是核心重构任务，需要仔细实现 Modbus RTU 协议

## [ ] Task 3: 创建/重构发电机测试通信管理
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 创建 GeneratorTestManager 类（或直接在 QML 中完善）
  - 发电机测试通信通过 SerialPortManager 进行
  - 保持现有发电机测试协议功能完整
- **Acceptance Criteria Addressed**: [AC-3, AC-4]
- **Test Requirements**:
  - `programmatic` TR-3.1: 验证发电机测试通信通过 SerialPortManager
  - `programmatic` TR-3.2: 验证发电机测试功能正常工作
- **Notes**: 根据现有 GeneratorTestPage.qml 的实现方式决定

## [ ] Task 4: 更新 HomePage.qml 串口控制逻辑
- **Priority**: P0
- **Depends On**: Task 1, Task 2, Task 3
- **Description**: 
  - 修改串口开关逻辑，只通过 SerialPortManager 打开串口一次
  - 移除同时打开两个串口的代码
  - 确保 ModbusManager 在串口打开后正确初始化
- **Acceptance Criteria Addressed**: [AC-4, AC-5]
- **Test Requirements**:
  - `programmatic` TR-4.1: 验证点击串口开关只打开一次串口
  - `programmatic` TR-4.2: 验证无串口访问冲突
- **Notes**: 主要修改 HomePage.qml 中的 serialPortSwitch 处理逻辑

## [ ] Task 5: 更新 GeneratorTestPage.qml 通信逻辑
- **Priority**: P0
- **Depends On**: Task 3
- **Description**: 
  - 修改 GeneratorTestPage.qml，通过 SerialPortManager 进行通信
  - 确保发电机测试各项功能正常工作
- **Acceptance Criteria Addressed**: [AC-3, AC-5]
- **Test Requirements**:
  - `programmatic` TR-5.1: 验证发电机测试页面能正常通信
  - `human-judgement` TR-5.2: 验证发电机测试各项功能正常
- **Notes**: 需要确保所有测试功能（波动、突加、突卸、谐波等）都能正常工作

## [ ] Task 6: 集成测试与功能验证
- **Priority**: P1
- **Depends On**: Task 4, Task 5
- **Description**: 
  - 全面测试所有功能
  - 验证 Modbus 通信正常
  - 验证发电机测试正常
  - 验证无串口冲突
- **Acceptance Criteria Addressed**: [AC-5]
- **Test Requirements**:
  - `human-judgement` TR-6.1: 完整的用户场景测试
  - `programmatic` TR-6.2: 检查日志中无串口冲突错误
- **Notes**: 这是最终验证步骤
