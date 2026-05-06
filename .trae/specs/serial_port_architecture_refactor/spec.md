# 串口架构重构 - Product Requirement Document

## Overview
- **Summary**: 重构串口通信架构，解决串口访问冲突问题，实现多个协议（Modbus和发电机测试协议）共享单一串口
- **Purpose**: 解决当前两个独立模块同时打开同一串口导致的"拒绝访问"和权限错误问题
- **Target Users**: 发电机测试系统的最终用户

## Goals
- SerialPortManager 负责底层串口操作（打开/关闭/读写），支持多个协议共享串口
- ModbusManager 通过 SerialPortManager 来发送和接收数据，而不是自己打开串口
- 发电机测试相关的通信独立管理，也通过 SerialPortManager 来发送和接收数据
- 解决串口访问冲突问题，确保串口可以正常打开和通信

## Non-Goals (Out of Scope)
- 不改变现有 Modbus 协议的具体实现逻辑
- 不改变发电机测试协议的具体实现逻辑
- 不修改现有 UI 界面的外观
- 不添加新的通信协议

## Background & Context
当前问题：
1. SerialPortManager 和 ModbusManager 都各自打开串口，导致串口访问冲突
2. 发电机测试相关代码直接使用 SerialPortManager，而 ModbusManager 使用自己的串口
3. 错误信息显示："Cannot open serial device due to permissions" 和 "拒绝访问"

原架构问题：
- 两个独立的串口管理器同时尝试打开同一个物理串口
- 没有统一的串口资源管理机制

## Functional Requirements
- **FR-1**: SerialPortManager 提供统一的串口打开/关闭/读写接口
- **FR-2**: SerialPortManager 支持多个协议模块通过它进行串口通信
- **FR-3**: ModbusManager 使用 SerialPortManager 进行数据收发，不再直接打开串口
- **FR-4**: 发电机测试通信通过 SerialPortManager 进行数据收发
- **FR-5**: 保持现有 Modbus 和发电机测试协议的功能完整性

## Non-Functional Requirements
- **NFR-1**: 串口打开成功率达到 100%（无冲突时）
- **NFR-2**: 通信延迟不超过原有架构
- **NFR-3**: 代码重构后保持可维护性和可读性

## Constraints
- **Technical**: 使用 Qt/QML 框架，保持与现有代码风格一致
- **Business**: 必须在不破坏现有功能的前提下完成重构
- **Dependencies**: 依赖 Qt 的 QSerialPort 类

## Assumptions
- 现有 Modbus 协议实现是正确的
- 现有发电机测试协议实现是正确的
- Qt 的 QSerialPort 支持底层字节操作

## Acceptance Criteria

### AC-1: SerialPortManager 提供统一串口接口
- **Given**: 系统启动
- **When**: 调用 SerialPortManager 的接口
- **Then**: SerialPortManager 能够正确打开、关闭、读写串口
- **Verification**: `programmatic`

### AC-2: ModbusManager 使用 SerialPortManager
- **Given**: ModbusManager 需要通信
- **When**: ModbusManager 发送或接收数据
- **Then**: 数据通过 SerialPortManager 进行传输
- **Verification**: `programmatic`

### AC-3: 发电机测试使用 SerialPortManager
- **Given**: 发电机测试页面需要通信
- **When**: 发电机测试发送或接收数据
- **Then**: 数据通过 SerialPortManager 进行传输
- **Verification**: `programmatic`

### AC-4: 串口访问无冲突
- **Given**: 用户选择串口并打开
- **When**: Modbus 和发电机测试同时需要通信
- **Then**: 串口能够正常打开，无"拒绝访问"错误
- **Verification**: `programmatic`

### AC-5: 功能完整性保持
- **Given**: 重构完成
- **When**: 执行原有功能操作
- **Then**: 所有原有功能正常工作
- **Verification**: `human-judgment`

## Open Questions
- [ ] 发电机测试通信是否需要独立的 Manager 类，还是直接在 QML 中通过 SerialPortManager 处理？
