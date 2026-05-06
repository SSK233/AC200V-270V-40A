// ============================================================================//
// Modbus管理器实现文件 (ModbusManager.cpp)
// 功能：负责Modbus RTU串行通信的管理，包括设备连接、数据读取和写入
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

// 包含必要的头文件
#include "ModbusManager.h"
#include "SerialPortManager.h"
#include "SerialRequestManager.h"
#include <QDebug>
#include <QVariant>
#include <QSerialPort>
#include <QDateTime>
#include <QThread>
#include <cmath>

// CRC16计算函数
quint16 calculateCRC16(const QByteArray &data) {
    quint16 crc = 0xFFFF;
    for (int i = 0; i < data.size(); i++) {
        crc ^= static_cast<quint8>(data[i]);
        for (int j = 0; j < 8; j++) {
            if (crc & 0x0001) {
                crc = (crc >> 1) ^ 0xA001;
            } else {
                crc >>= 1;
            }
        }
    }
    return crc;
}

// 生成Modbus RTU读取保持寄存器的数据帧
QByteArray generateModbusReadFrame(int slaveAddress, int registerAddress, int registerCount = 1) {
    QByteArray frame;
    
    // 从站地址
    frame.append(static_cast<char>(slaveAddress));
    
    // 功能码 0x03 (读取保持寄存器)
    frame.append(static_cast<char>(0x03));
    
    // 寄存器起始地址 (高位在前)
    frame.append(static_cast<char>((registerAddress >> 8) & 0xFF));
    frame.append(static_cast<char>(registerAddress & 0xFF));
    
    // 寄存器数量 (高位在前)
    frame.append(static_cast<char>((registerCount >> 8) & 0xFF));
    frame.append(static_cast<char>(registerCount & 0xFF));
    
    // 计算CRC16
    quint16 crc = calculateCRC16(frame);
    
    // 添加CRC (低位在前)
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));
    
    return frame;
}

// 生成Modbus RTU写入单个寄存器的数据帧
QByteArray generateModbusWriteFrame(int slaveAddress, int registerAddress, quint16 value) {
    QByteArray frame;
    
    // 从站地址
    frame.append(static_cast<char>(slaveAddress));
    
    // 功能码 0x06 (写入单个保持寄存器)
    frame.append(static_cast<char>(0x06));
    
    // 寄存器地址 (高位在前)
    frame.append(static_cast<char>((registerAddress >> 8) & 0xFF));
    frame.append(static_cast<char>(registerAddress & 0xFF));
    
    // 寄存器值 (高位在前)
    frame.append(static_cast<char>((value >> 8) & 0xFF));
    frame.append(static_cast<char>(value & 0xFF));
    
    // 计算CRC16
    quint16 crc = calculateCRC16(frame);
    
    // 添加CRC (低位在前)
    frame.append(static_cast<char>(crc & 0xFF));
    frame.append(static_cast<char>((crc >> 8) & 0xFF));
    
    return frame;
}

// 验证Modbus RTU帧的CRC16校验
bool verifyModbusFrameCRC(const QByteArray &frame) {
    if (frame.size() < 4) {
        return false;
    }
    
    QByteArray dataPart = frame.left(frame.size() - 2);
    quint16 receivedCRC = static_cast<quint8>(frame[frame.size() - 2]) | 
                          (static_cast<quint8>(frame[frame.size() - 1]) << 8);
    quint16 calculatedCRC = calculateCRC16(dataPart);
    
    return receivedCRC == calculatedCRC;
}



/**
 * @brief ModbusManager构造函数
 * @param parent 父对象
 * @details 初始化Modbus管理器，创建读取定时器
 */
ModbusManager::ModbusManager(QObject *parent)
    : QObject(parent)
    , m_serialPortManager(nullptr)
    , m_readTimer(nullptr)
    // , m_voltage(0.0)
    // , m_current(0.0)
    // , m_power(0.0)
    , m_connected(false)
    , m_fanState(0)
    // , m_fanState2(0) // 从站2不再使用
    , m_highTempState(0)
    // , m_highTempState2(0) // 从站2不再使用
    // , m_fanSwitch2State(false) // 从站2不再使用
    , m_burstAddState(0)
    , m_burstRemoveState(0)
    // , m_burstAddState2(0) // 从站2不再使用
    // , m_burstRemoveState2(0) // 从站2不再使用
    , m_hasFanStateData(false)
    // , m_hasFanStateData2(false) // 从站2不再使用
    , m_hasHighTempData(false)
    // , m_hasHighTempData2(false) // 从站2不再使用
    , m_singlePhaseVoltage(0.0)
    , m_singlePhaseCurrent(0.0)
    , m_singlePhasePower(0.0)
    , m_pendingReads(0)
    , m_firstTimeoutTime(0)
{
    // 创建读取定时器
    m_readTimer = new QTimer(this);
    m_readTimer->setInterval(1000); // 默认读取间隔为1000毫秒
    // 连接定时器超时信号到读取所有寄存器的槽函数
    connect(m_readTimer, &QTimer::timeout, this, &ModbusManager::readAllRegisters);
    
    // 创建连接超时定时器
    m_connectionTimeoutTimer = new QTimer(this);
    m_connectionTimeoutTimer->setInterval(10000); // 10秒超时
    m_connectionTimeoutTimer->setSingleShot(true); // 单次触发
    // 连接定时器超时信号到连接超时槽函数
    connect(m_connectionTimeoutTimer, &QTimer::timeout, this, [this]() {
        if (m_connected && !m_hasFanStateData) {
            emit connectionTimeout();
        }
    });
}

/**
 * @brief ModbusManager析构函数
 * @details 断开Modbus设备连接，释放资源
 */
ModbusManager::~ModbusManager()
{
    disconnectPort();
}

/**
 * @brief 设置串口管理器
 * @param serialPortManager 串口管理器指针
 */
void ModbusManager::setSerialPortManager(SerialPortManager *serialPortManager)
{
    if (m_serialPortManager) {
        disconnect(m_serialPortManager, &SerialPortManager::bytesReceived,
                   this, &ModbusManager::onBytesReceived);
        disconnect(m_serialPortManager, &SerialPortManager::isConnectedChanged,
                   this, &ModbusManager::onSerialPortConnectedChanged);
    }
    
    m_serialPortManager = serialPortManager;
    
    if (m_serialPortManager) {
        connect(m_serialPortManager, &SerialPortManager::bytesReceived,
                this, &ModbusManager::onBytesReceived);
        connect(m_serialPortManager, &SerialPortManager::isConnectedChanged,
                this, &ModbusManager::onSerialPortConnectedChanged);
        
        // 连接SerialRequestManager的错误信号
        SerialRequestManager *requestManager = m_serialPortManager->requestManager();
        if (requestManager) {
            connect(requestManager, &SerialRequestManager::requestFailed,
                    this, &ModbusManager::onRequestFailed);
        }
        
        // 初始化连接状态
        if (m_serialPortManager->isConnected()) {
            m_connected = true;
            emit connectedChanged();
        }
    }
}

/**
 * @brief 连接到Modbus设备
 * @param portName 串口名称
 * @param baudRate 波特率
 * @param parity 校验位（0：无校验，1：奇校验，2：偶校验）
 * @return 连接是否成功
 * @details 初始化Modbus状态，不打开新串口（串口已通过SerialPortManager打开）
 */
bool ModbusManager::connectToPort(const QString &portName, int baudRate, int parity)
{
    if (!m_serialPortManager) {
        qDebug() << "ModbusManager: SerialPortManager not set";
        return false;
    }
    
    // 如果已经连接，先断开
    if (m_connected) {
        disconnectPort();
    }
    
    // 输出连接参数
    QString parityStr = (parity == 0) ? "无校验" : (parity == 1) ? "奇校验" : "偶校验";
    qDebug() << "========================================";
    qDebug() << "Modbus 初始化参数:";
    qDebug() << "  串口号:" << portName;
    qDebug() << "  波特率:" << baudRate;
    qDebug() << "  校验位:" << parityStr;
    qDebug() << "  数据位: 8";
    qDebug() << "  停止位: 1";
    qDebug() << "========================================";
    
    // 检查SerialPortManager是否已连接
    bool success = m_serialPortManager->isConnected();
    if (success) {
        m_connected = true;
        emit connectedChanged();
        qDebug() << "ModbusManager 状态初始化完成，使用已打开的串口";
    } else {
        qDebug() << "ModbusManager 初始化失败：串口未打开";
    }
    
    return success;
}

/**
 * @brief 断开与Modbus设备的连接
 * @details 停止读取并清理Modbus状态，不关闭串口（串口由SerialPortManager管理）
 */
void ModbusManager::disconnectPort()
{
    // 停止读取
    stopReading();
    // 停止连接超时定时器
    if (m_connectionTimeoutTimer) {
        m_connectionTimeoutTimer->stop();
    }
    // 更新连接状态
    m_connected = false;
    emit connectedChanged();
    
    // 重置风机状态和高温状态
    if (m_hasFanStateData) {
        m_hasFanStateData = false;
        emit hasFanStateDataChanged();
    }
    if (m_hasHighTempData) {
        m_hasHighTempData = false;
        emit hasHighTempDataChanged();
    }
    // 重置状态值
    m_fanState = 0;
    emit fanStateChanged();
    m_highTempState = 0;
    emit highTempStateChanged();
    
    qDebug() << "ModbusManager 状态已清理，串口保持打开";
}

/**
 * @brief 开始定时读取数据
 * @param intervalMs 读取间隔，单位为毫秒
 * @details 启动定时器，定时读取Modbus寄存器
 */
void ModbusManager::startReading(int intervalMs)
{
    if (m_readTimer) {
        // 设置读取间隔
        m_readTimer->setInterval(intervalMs);
        // 启动定时器
        m_readTimer->start();
        qDebug() << "Started reading Modbus registers every" << intervalMs << "ms";
    }
}

/**
 * @brief 停止定时读取数据
 * @details 停止读取定时器
 */
void ModbusManager::stopReading()
{
    if (m_readTimer) {
        m_readTimer->stop();
    }
}

/**
 * @brief 串口连接状态变化槽函数
 * @details 处理串口连接状态变化，更新Modbus连接状态
 */
void ModbusManager::onSerialPortConnectedChanged()
{
    if (!m_serialPortManager) {
        return;
    }
    
    bool newConnected = m_serialPortManager->isConnected();
    if (m_connected != newConnected) {
        m_connected = newConnected;
        emit connectedChanged();
        qDebug() << "Modbus state changed:" << (newConnected ? "connected" : "disconnected");
        
        if (newConnected) {
            qDebug() << "========================================";
            qDebug() << "设备连接成功:";
            qDebug() << "  从站地址:" << WRITE_CURRENT_SLAVE_ADDRESS;
            qDebug() << "========================================";
            m_firstTimeoutTime = 0;
            if (m_connectionTimeoutTimer) {
                m_connectionTimeoutTimer->stop();
                m_connectionTimeoutTimer->start();
            }
        } else {
            if (m_connectionTimeoutTimer) {
                m_connectionTimeoutTimer->stop();
            }
            if (m_hasFanStateData) {
                m_hasFanStateData = false;
                emit hasFanStateDataChanged();
            }
            // if (m_hasFanStateData2) {
            //     m_hasFanStateData2 = false;
            //     emit hasFanStateData2Changed();
            // }
            if (m_hasHighTempData) {
                m_hasHighTempData = false;
                emit hasHighTempDataChanged();
            }
            // if (m_hasHighTempData2) {
            //     m_hasHighTempData2 = false;
            //     emit hasHighTempData2Changed();
            // }
            m_fanState = 0;
            emit fanStateChanged();
            // m_fanState2 = 0;
            // emit fanState2Changed();
            m_highTempState = 0;
            emit highTempStateChanged();
            // m_highTempState2 = 0;
            // emit highTempState2Changed();
            // m_fanSwitch2State = false;
            // emit fanSwitch2StateChanged();
            qDebug() << "========================================";
            qDebug() << "设备断开连接，已重置状态:";
            qDebug() << "  从站1风机状态: 0";
            qDebug() << "  从站1高温状态: 0";
            qDebug() << "========================================";
        }
    }
}

/**
 * @brief 处理接收到的Modbus RTU响应帧
 * @param data 接收到的数据
 */
void ModbusManager::onBytesReceived(const QByteArray &data)
{
    m_receiveBuffer.append(data);
    
    while (m_receiveBuffer.size() >= 5) {
        // 查找有效的Modbus帧
        int frameStart = 0;
        bool foundValidFrame = false;
        int expectedLength = 0;
        
        for (int i = 0; i < m_receiveBuffer.size(); i++) {
            // 检查功能码并确定预期长度
            if (i + 1 < m_receiveBuffer.size()) {
                quint8 slaveAddr = static_cast<quint8>(m_receiveBuffer[i]);
                quint8 functionCode = static_cast<quint8>(m_receiveBuffer[i + 1]);
                
                if (functionCode == 0x03) {
                    // 读保持寄存器响应：从站地址(1) + 功能码(1) + 字节数(1) + 数据(N) + CRC(2)
                    if (i + 2 < m_receiveBuffer.size()) {
                        quint8 byteCount = static_cast<quint8>(m_receiveBuffer[i + 2]);
                        expectedLength = 3 + byteCount + 2; // 1+1+1 + N + 2
                        
                        if (m_receiveBuffer.size() >= i + expectedLength) {
                            frameStart = i;
                            foundValidFrame = true;
                            break;
                        }
                    }
                } else if (functionCode == 0x06) {
                    // 写单个寄存器响应：从站地址(1) + 功能码(1) + 寄存器地址(2) + 寄存器值(2) + CRC(2) = 8字节
                    expectedLength = 8;
                    
                    if (m_receiveBuffer.size() >= i + expectedLength) {
                        frameStart = i;
                        foundValidFrame = true;
                        break;
                    }
                }
            }
        }
        
        if (!foundValidFrame) {
            break;
        }
        
        QByteArray frame = m_receiveBuffer.mid(frameStart, expectedLength);
        m_receiveBuffer.remove(0, frameStart + expectedLength);
        
        if (!verifyModbusFrameCRC(frame)) {
            continue;
        }
        
        quint8 slaveAddress = static_cast<quint8>(frame[0]);
        quint8 functionCode = static_cast<quint8>(frame[1]);
        
        if (m_pendingRequests.isEmpty()) {
            continue;
        }
        
        PendingRequest request = m_pendingRequests.takeFirst();
        
        if (request.slaveAddress != slaveAddress) {
            continue;
        }
        
        if (functionCode == 0x03) {
            // 解析读保持寄存器响应
            quint8 byteCount = static_cast<quint8>(frame[2]);
            if (byteCount >= 2) {
                // 检查是否是读取多个寄存器的响应
                if (request.registerAddress == FAN_STATE_REGISTER_ADDRESS && byteCount >= 8) {
                    // 一次读取4个寄存器（100-103）
                    if (slaveAddress == FAN_STATE_SLAVE_ADDRESS) {
                        // 寄存器100: 风机状态
                        quint16 fanStateValue = (static_cast<quint8>(frame[3]) << 8) | static_cast<quint8>(frame[4]);
                        m_fanState = fanStateValue;
                        if (!m_hasFanStateData) {
                            m_hasFanStateData = true;
                            emit hasFanStateDataChanged();
                            m_connectionTimeoutTimer->stop();
                        }
                        if (m_firstTimeoutTime != 0) {
                            m_firstTimeoutTime = 0;
                        }
                        emit fanStateChanged();
                        
                        // 寄存器101: 温度状态
                        quint16 tempStateValue = (static_cast<quint8>(frame[5]) << 8) | static_cast<quint8>(frame[6]);
                        m_highTempState = tempStateValue;
                        if (!m_hasHighTempData) {
                            m_hasHighTempData = true;
                            emit hasHighTempDataChanged();
                        }
                        emit highTempStateChanged();
                        
                        // 寄存器102: 突加状态
                        quint16 burstAddValue = (static_cast<quint8>(frame[7]) << 8) | static_cast<quint8>(frame[8]);
                        m_burstAddState = burstAddValue;
                        emit burstAddStateChanged();
                        
                        // 寄存器103: 突卸状态
                        quint16 burstRemoveValue = (static_cast<quint8>(frame[9]) << 8) | static_cast<quint8>(frame[10]);
                        m_burstRemoveState = burstRemoveValue;
                        emit burstRemoveStateChanged();
                    }
                    // 从站2不再使用，移除从站2的状态处理
                    // else if (slaveAddress == FAN_STATE_SLAVE_ADDRESS_2 && m_fanSwitch2State) {
                    //     // 寄存器100: 风机状态
                    //     quint16 fanStateValue = (static_cast<quint8>(frame[3]) << 8) | static_cast<quint8>(frame[4]);
                    //     m_fanState2 = fanStateValue;
                    //     if (!m_hasFanStateData2) {
                    //         m_hasFanStateData2 = true;
                    //         emit hasFanStateData2Changed();
                    //     }
                    //     emit fanState2Changed();
                    //     
                    //     // 寄存器101: 温度状态
                    //     quint16 tempStateValue = (static_cast<quint8>(frame[5]) << 8) | static_cast<quint8>(frame[6]);
                    //     m_highTempState2 = tempStateValue;
                    //     if (!m_hasHighTempData2) {
                    //         m_hasHighTempData2 = true;
                    //         emit hasHighTempData2Changed();
                    //     }
                    //     emit highTempState2Changed();
                    //     
                    //     // 寄存器102: 突加状态
                    //     quint16 burstAddValue = (static_cast<quint8>(frame[7]) << 8) | static_cast<quint8>(frame[8]);
                    //     m_burstAddState2 = burstAddValue;
                    //     emit burstAddState2Changed();
                    //     
                    //     // 寄存器103: 突卸状态
                    //     quint16 burstRemoveValue = (static_cast<quint8>(frame[9]) << 8) | static_cast<quint8>(frame[10]);
                    //     m_burstRemoveState2 = burstRemoveValue;
                    //     emit burstRemoveState2Changed();
                    // }
                } else if (request.registerAddress == 0 && slaveAddress == 2 && byteCount >= 24) {
                    // 从站2：寄存器0-11（电压、电流、功率、小数点位置）
                    // 寄存器0: 电压
                    quint16 voltageRaw = (static_cast<quint8>(frame[3]) << 8) | static_cast<quint8>(frame[4]);
                    // 寄存器1: 电流
                    quint16 currentRaw = (static_cast<quint8>(frame[5]) << 8) | static_cast<quint8>(frame[6]);
                    // 寄存器2: 功率
                    quint16 powerRaw = (static_cast<quint8>(frame[7]) << 8) | static_cast<quint8>(frame[8]);
                    // 寄存器3-10: （保留）
                    // 寄存器11: 功率小数点（高位）+ 电流小数点（高位）+ 电压小数点（低位）
                    quint8 powerDecimal = static_cast<quint8>(frame[25]);
                    quint8 currentDecimal = static_cast<quint8>((static_cast<quint8>(frame[26]) >> 4) & 0x0F);
                    quint8 voltageDecimal = static_cast<quint8>(static_cast<quint8>(frame[26]) & 0x0F);
                    
                    // 计算实际值
                    // 公式：实际值 = 原始值 / 10000 * 10^(小数点位置)
                    // 电压小数点3，原始值9000 → 9000/10000*1000=900
                    double voltageMultiplier = pow(10.0, voltageDecimal);
                    m_singlePhaseVoltage = static_cast<double>(voltageRaw) / 10000.0 * voltageMultiplier;
                    emit singlePhaseVoltageChanged();
                    
                    double currentMultiplier = pow(10.0, currentDecimal);
                    m_singlePhaseCurrent = static_cast<double>(currentRaw) / 10000.0 * currentMultiplier;
                    emit singlePhaseCurrentChanged();
                    
                    double powerMultiplier = pow(10.0, powerDecimal);
                    m_singlePhasePower = static_cast<double>(powerRaw) / 10000.0 * powerMultiplier;
                    emit singlePhasePowerChanged();
                } else {
                    // 单个寄存器读取（兼容旧逻辑）
                    quint16 rawValue = (static_cast<quint8>(frame[3]) << 8) | static_cast<quint8>(frame[4]);
                    
                    // 更新相应的数据
                    if (slaveAddress == FAN_STATE_SLAVE_ADDRESS && request.registerAddress == FAN_STATE_REGISTER_ADDRESS) {
                        m_fanState = rawValue;
                        if (!m_hasFanStateData) {
                            m_hasFanStateData = true;
                            emit hasFanStateDataChanged();
                            m_connectionTimeoutTimer->stop();
                        }
                        if (m_firstTimeoutTime != 0) {
                            m_firstTimeoutTime = 0;
                        }
                        emit fanStateChanged();
                    } else if (slaveAddress == HIGH_TEMP_SLAVE_ADDRESS && request.registerAddress == HIGH_TEMP_REGISTER_ADDRESS) {
                        m_highTempState = rawValue;
                        if (!m_hasHighTempData) {
                            m_hasHighTempData = true;
                            emit hasHighTempDataChanged();
                        }
                        emit highTempStateChanged();
                    } else if (slaveAddress == FAN_STATE_SLAVE_ADDRESS && request.registerAddress == 102) {
                        m_burstAddState = rawValue;
                        emit burstAddStateChanged();
                    } else if (slaveAddress == FAN_STATE_SLAVE_ADDRESS && request.registerAddress == 103) {
                        m_burstRemoveState = rawValue;
                        emit burstRemoveStateChanged();
                    }
                }
            }
        } else if (functionCode == 0x06) {
            // 解析写单个寄存器响应
            quint16 regAddress = (static_cast<quint8>(frame[2]) << 8) | 
                                 static_cast<quint8>(frame[3]);
            quint16 rawValue = (static_cast<quint8>(frame[4]) << 8) | 
                               static_cast<quint8>(frame[5]);
            
            // 检查是否是风机状态写入响应
            if (regAddress == FAN_REGISTER_ADDRESS) {
                qDebug() << "========================================";
                qDebug() << "【风机开关】接收到写入响应:";
                qDebug() << "  从站地址:" << slaveAddress;
                qDebug() << "  寄存器地址:" << regAddress;
                qDebug() << "  写入值:" << rawValue << "(" << (rawValue == 1 ? "ON" : "OFF") << ")";
                qDebug() << "========================================";
            }
            
            // // 如果是写入风机2的状态
            // if (slaveAddress == 2 && regAddress == FAN_REGISTER_ADDRESS) {
            //     m_fanSwitch2State = (rawValue == 1);
            //     emit fanSwitch2StateChanged();
            // }
        }
    }
}

/**
 * @brief 读取所有寄存器槽函数
 * @details 读取所有需要的Modbus寄存器值
 */
void ModbusManager::readAllRegisters()
{
    if (!m_connected || !m_serialPortManager) {
        return;
    }
    
    m_pendingRequests.clear();
    m_readQueue.clear();
    
    SerialRequestManager *requestManager = m_serialPortManager->requestManager();
    if (!requestManager) {
        return;
    }
    
    // 定义要读取的寄存器配置
    struct RegisterConfig {
        int slaveAddress;
        int startAddress;
        int registerCount;
    };
    
    QList<RegisterConfig> configs;
    
    // 从站1：寄存器100-103（风机状态、温度状态、突加状态、突卸状态）
    configs.append({FAN_STATE_SLAVE_ADDRESS, FAN_STATE_REGISTER_ADDRESS, 4});
    
    // 从站2：寄存器0-11（电压、电流、功率、小数点位置）
    configs.append({2, 0, 12});
    
    // 从站2不再使用，移除从站2的配置
    // if (m_fanSwitch2State) {
    //     configs.append({FAN_STATE_SLAVE_ADDRESS_2, FAN_STATE_REGISTER_ADDRESS_2, 4});
    // }
    
    // 发送所有读取请求
    for (const RegisterConfig &config : configs) {
        PendingRequest request;
        request.slaveAddress = config.slaveAddress;
        request.registerAddress = config.startAddress;
        request.isRead = true;
        m_pendingRequests.append(request);
        
        // 生成读取多个寄存器的请求
        QByteArray frame = generateModbusReadFrame(config.slaveAddress, config.startAddress, config.registerCount);
        requestManager->addRequest(RequestPriority::Normal, frame);
    }
}

/**
 * @brief 读取保持寄存器
 * @param slaveAddress 从站地址
 * @param registerAddress 寄存器地址
 * @details 发送Modbus读取请求，读取指定的保持寄存器
 */
void ModbusManager::readHoldingRegister(int slaveAddress, int registerAddress)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        return;
    }
    
    SerialRequestManager *requestManager = m_serialPortManager->requestManager();
    if (!requestManager) {
        return;
    }
    
    QByteArray frame = generateModbusReadFrame(slaveAddress, registerAddress, 1);
    
    PendingRequest request;
    request.slaveAddress = slaveAddress;
    request.registerAddress = registerAddress;
    request.isRead = true;
    m_pendingRequests.append(request);
    
    requestManager->addRequest(RequestPriority::Normal, frame);
}

/**
 * @brief 写入保持寄存器
 * @param slaveAddress 从站地址
 * @param registerAddress 寄存器地址
 * @param value 要写入的值
 * @details 发送Modbus写入请求，写入指定的保持寄存器
 */
void ModbusManager::writeHoldingRegister(int slaveAddress, int registerAddress, double value)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write";
        return;
    }
    
    SerialRequestManager *requestManager = m_serialPortManager->requestManager();
    if (!requestManager) {
        return;
    }
    
    quint16 rawValue = static_cast<quint16>(qRound(value));
    QByteArray frame = generateModbusWriteFrame(slaveAddress, registerAddress, rawValue);
    
    PendingRequest request;
    request.slaveAddress = slaveAddress;
    request.registerAddress = registerAddress;
    request.isRead = false;
    m_pendingRequests.append(request);
    
    // 只有风机状态写入才输出详细调试信息
    if (registerAddress == FAN_REGISTER_ADDRESS) {
        qDebug() << "========================================";
        qDebug() << "【风机开关】发送写入请求:";
        qDebug() << "  从站地址:" << slaveAddress;
        qDebug() << "  寄存器地址:" << registerAddress;
        qDebug() << "  写入值:" << rawValue << "(" << (rawValue == 1 ? "ON" : "OFF") << ")";
        
        QString frameHex;
        for (int i = 0; i < frame.size(); i++) {
            frameHex += QString("%1 ").arg(static_cast<quint8>(frame[i]), 2, 16, QChar('0')).toUpper();
        }
        qDebug() << "  发送帧:" << frameHex;
        qDebug() << "========================================";
    }
    
    requestManager->addRequest(RequestPriority::High, frame);
}

// /**
//  * @brief 写入电压值
//  * @param value 要写入的电压值
//  * @details 写入电压值到指定的寄存器
//  */
// void ModbusManager::writeVoltage(double value)
// {
//     writeHoldingRegister(WRITE_VOLTAGE_SLAVE_ADDRESS, WRITE_VOLTAGE_REGISTER_ADDRESS, value);
// }

/**
 * @brief 写入电流值
 * @param value 要写入的电流值
 * @param channel 电流通道（1-3）
 * @details 写入电流值到指定的寄存器
 */
// 计算从站2的档位组合（从站2不再使用）
// int ModbusManager::calculateSlave2Power(double power)
// {
//     // 从站2的档位：10, 20, 20, 50, 100（从大到小排序）
//     QVector<int> gears = {100, 50, 20, 20, 10};
//     int total = 0;
//     
//     // 从最大的档位开始尝试，尽可能多地使用大档位
//     for (int gear : gears) {
//         if (total + gear <= power) {
//             total += gear;
//         }
//     }
//     
//     return total;
// }

void ModbusManager::writeCurrent(double value, int channel)
{
    qint64 startTime = QDateTime::currentMSecsSinceEpoch();
    qDebug() << "========================================";
    qDebug() << "【计时】writeCurrent开始 - 时间戳:" << startTime;
    qDebug() << "  输入值:" << value << "KW, 通道:" << channel;
    
    int registerAddress;
    switch(channel) {
    case 1:
        registerAddress = WRITE_CURRENT_REGISTER_ADDRESS_1;
        break;
    case 2:
        registerAddress = WRITE_CURRENT_REGISTER_ADDRESS_2;
        break;
    case 3:
        registerAddress = WRITE_CURRENT_REGISTER_ADDRESS_3;
        break;
    default:
        qDebug() << "Invalid current channel:" << channel;
        return;
    }
    
    qint64 afterSwitch = QDateTime::currentMSecsSinceEpoch();
    qDebug() << "【计时】switch语句耗时:" << (afterSwitch - startTime) << "ms";
    
    // 从站2不再使用，只发送到从站1
    double sendValue = value * 10;  // 电流值*10发送
    qDebug() << "========================================";
    qDebug() << "准备发送电流值到从站1:";
    qDebug() << "  通道:" << channel;
    qDebug() << "  从站1地址:" << WRITE_CURRENT_SLAVE_ADDRESS;
    qDebug() << "  从站1寄存器地址:" << registerAddress;
    qDebug() << "  原始电流值:" << value << "A" ;
    qDebug() << "  发送值(×10):" << sendValue;
    qDebug() << "========================================";
    
    writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS, registerAddress, sendValue);
    
    qint64 endTime = QDateTime::currentMSecsSinceEpoch();
    qDebug() << "【计时】writeCurrent总耗时:" << (endTime - startTime) << "ms";
    qDebug() << "========================================";
}



/**
 * @brief 写入风机状态
 * @param state 风机状态，true为开启，false为关闭
 * @param slaveAddress 从站地址
 * @details 写入风机状态到指定的寄存器
 */
void ModbusManager::writeFanState(bool state, int slaveAddress)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write fan state";
        return;
    }
    
    quint16 rawValue = state ? 1 : 0;
    
    // 从站2不再使用
    // if (slaveAddress == 2) {
    //     m_fanSwitch2State = state;
    //     emit fanSwitch2StateChanged();
    // }
    
    writeHoldingRegister(slaveAddress, FAN_REGISTER_ADDRESS, rawValue);
}

// /**
//  * @brief 同时写入电压和电流值
//  * @param voltage 要写入的电压值
//  * @param current 要写入的电流值
//  * @details 同时写入电压和电流值到指定的寄存器
//  */
// void ModbusManager::writeVoltageAndCurrent(double voltage, double current)
// {
//     // 检查连接状态
//     if (!m_modbusMaster || m_modbusMaster->state() != QModbusDevice::ConnectedState) {
//         qDebug() << "Modbus not connected, cannot write";
//         return;
//     }
//     
//     // 将值转换为16位无符号整数
//     quint16 voltageRaw = static_cast<quint16>(qRound(voltage));
//     quint16 currentRaw = static_cast<quint16>(qRound(current));
//     
//     // 创建写入单元（写入2个寄存器）
//     QModbusDataUnit writeUnit(QModbusDataUnit::HoldingRegisters, WRITE_VOLTAGE_REGISTER_ADDRESS, 2);
//     writeUnit.setValue(0, voltageRaw);
//     writeUnit.setValue(1, currentRaw);
//     
//     // 输出写入请求信息
//     qDebug() << "========================================";
//     qDebug() << "发送写入请求:";
//     qDebug() << "  从站地址:" << WRITE_VOLTAGE_SLAVE_ADDRESS;
//     qDebug() << "  起始寄存器:" << WRITE_VOLTAGE_REGISTER_ADDRESS;
//     qDebug() << "  寄存器数量: 2";
//     qDebug() << "  电压值(原始):" << voltageRaw << "(" << voltage << "V)";
//     qDebug() << "  电流值(原始):" << currentRaw << "(" << current << "A)";
//     qDebug() << "========================================";
//     
//     // 发送写入请求
//     if (auto *reply = m_modbusMaster->sendWriteRequest(writeUnit, WRITE_VOLTAGE_SLAVE_ADDRESS)) {
//         if (!reply->isFinished()) {
//             // 连接写入完成信号
//             connect(reply, &QModbusReply::finished, this, [this, reply, voltage, current]() {
//                 qDebug() << "========================================";
//                 qDebug() << "收到PLC响应:";
//                 if (reply->error() == QModbusDevice::NoError) {
//                     // 写入成功
//                     const QModbusDataUnit result = reply->result();
//                     qDebug() << "  状态: 写入成功";
//                     qDebug() << "  从站地址:" << reply->serverAddress();
//                     qDebug() << "  功能码:" << static_cast<int>(result.registerType());
//                     qDebug() << "  起始地址:" << result.startAddress();
//                     qDebug() << "  写入寄存器数:" << result.valueCount();
//                     qDebug() << "  写入数据: 电压=" << voltage << "V, 电流=" << current << "A";
//                 } else {
//                     // 写入失败
//                     qDebug() << "  状态: 写入失败";
//                     qDebug() << "  错误码:" << static_cast<int>(reply->error());
//                     qDebug() << "  错误信息:" << reply->errorString();
//                 }
//                 qDebug() << "========================================";
//                 reply->deleteLater();
//             });
//         } else {
//             // 写入已完成，删除回复
//             delete reply;
//         }
//     } else {
//         // 发送请求失败
//         qDebug() << "发送请求失败:" << m_modbusMaster->errorString();
//     }
// }

/**
 * @brief 写入卸载控制命令
 * @param channel 卸载通道（1-3），默认值为0表示全部卸载
 * @details 写入卸载控制命令到指定的寄存器，使用功能码06（Write Single Holding Register）
 */
void ModbusManager::writeUnload(int channel)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write unload";
        return;
    }
    
    int registerAddress;
    if (channel == 0) {
        registerAddress = UNLOAD_REGISTER_ADDRESS_ALL;
        qDebug() << "========================================";
        qDebug() << "发送一键卸载请求(功能码06):";
        qDebug() << "  从站地址:" << UNLOAD_SLAVE_ADDRESS;
        qDebug() << "  寄存器地址:" << registerAddress;
        qDebug() << "  写入值: 1";
        qDebug() << "========================================";
    } else if (channel >= 1 && channel <= 3) {
        switch(channel) {
        case 1:
            registerAddress = UNLOAD_REGISTER_ADDRESS_1;
            break;
        case 2:
            registerAddress = UNLOAD_REGISTER_ADDRESS_2;
            break;
        case 3:
            registerAddress = UNLOAD_REGISTER_ADDRESS_3;
            break;
        default:
            qDebug() << "Invalid unload channel:" << channel;
            return;
        }
        qDebug() << "========================================";
        qDebug() << "发送卸载请求(功能码06):";
        qDebug() << "  从站地址:" << UNLOAD_SLAVE_ADDRESS;
        qDebug() << "  寄存器地址:" << registerAddress;
        qDebug() << "  写入值: 1";
        qDebug() << "========================================";
    } else {
        qDebug() << "Invalid unload channel:" << channel;
        return;
    }
    
    writeHoldingRegister(UNLOAD_SLAVE_ADDRESS, registerAddress, 1.0);
    
    // 从站2不再使用
    // if (m_fanSwitch2State) {
    //     qDebug() << "=======================================";
    //     qDebug() << "发送卸载请求到从站2(功能码06):";
    //     qDebug() << "  从站地址:" << WRITE_CURRENT_SLAVE_ADDRESS_2;
    //     qDebug() << "  寄存器地址:" << registerAddress;
    //     qDebug() << "  写入值: 1";
    //     qDebug() << "=======================================";
    //     writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS_2, registerAddress, 1.0);
    // }
}

/**
 * @brief 写入急停控制命令
 * @param state 急停状态，true为正常(1)，false为急停(0)
 * @details 写入急停控制命令到指定的寄存器，同时给从站1和从站2的寄存器5写1
 */
void ModbusManager::writeEmergencyStop(bool state)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write emergency stop";
        return;
    }
    
    if (!state) {
        qDebug() << "========================================";
        qDebug() << "发送急停命令到从站1的寄存器5:";
        qDebug() << "  从站1地址:" << WRITE_CURRENT_SLAVE_ADDRESS;
        qDebug() << "  寄存器地址: 5";
        qDebug() << "  写入值: 1";
        qDebug() << "========================================";
        
        writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS, 5, 1.0);
        
        QTimer::singleShot(1000, this, [this]() {
            qDebug() << "========================================";
            qDebug() << "1秒后发送急停复位命令到从站1的寄存器5:";
            qDebug() << "  从站1地址:" << WRITE_CURRENT_SLAVE_ADDRESS;
            qDebug() << "  寄存器地址: 5";
            qDebug() << "  写入值: 0";
            qDebug() << "========================================";
            
            writeHoldingRegister(WRITE_CURRENT_SLAVE_ADDRESS, 5, 0.0);
        });
    }
    
    quint16 rawValue = state ? 1 : 0;
    
    qDebug() << "========================================";
    qDebug() << "发送急停控制请求:";
    qDebug() << "  从站地址:" << EMERGENCY_STOP_SLAVE_ADDRESS;
    qDebug() << "  寄存器地址:" << EMERGENCY_STOP_REGISTER_ADDRESS;
    qDebug() << "  写入值:" << rawValue << "(" << (state ? "正常" : "急停") << ")";
    qDebug() << "========================================";
    
    writeHoldingRegister(EMERGENCY_STOP_SLAVE_ADDRESS, EMERGENCY_STOP_REGISTER_ADDRESS, rawValue);
    emit emergencyStopSent();
}

/**
 * @brief 写入电压模式
 * @param mode 电压模式：0=300V, 1=250V, 2=100V
 * @details 写入电压模式到寄存器30
 */
void ModbusManager::writeVoltageMode(int mode)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write voltage mode";
        return;
    }

    if (mode < 0 || mode > 2) {
        qDebug() << "Invalid voltage mode:" << mode << ", must be 0, 1, or 2";
        return;
    }

    QString modeText;
    switch(mode) {
    case 0:
        modeText = "300V";
        break;
    case 1:
        modeText = "250V";
        break;
    case 2:
        modeText = "100V";
        break;
    }

    qDebug() << "========================================";
    qDebug() << "发送电压模式设置请求:";
    qDebug() << "  从站地址:" << VOLTAGE_MODE_SLAVE_ADDRESS;
    qDebug() << "  寄存器地址:" << VOLTAGE_MODE_REGISTER_ADDRESS;
    qDebug() << "  写入值:" << mode << "(" << modeText << "模式)";
    qDebug() << "========================================";

    writeHoldingRegister(VOLTAGE_MODE_SLAVE_ADDRESS, VOLTAGE_MODE_REGISTER_ADDRESS, static_cast<double>(mode));
}

/**
 * @brief 直接写入电压值
 * @param voltage 电压值，范围200-270V
 * @details 直接写入电压值到寄存器30
 */
void ModbusManager::writeVoltageValue(int voltage)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qDebug() << "Modbus not connected, cannot write voltage value";
        return;
    }

    if (voltage < 200 || voltage > 270) {
        qDebug() << "Invalid voltage value:" << voltage << ", must be 200-270";
        return;
    }

    qDebug() << "========================================";
    qDebug() << "发送电压值设置请求:";
    qDebug() << "  从站地址:" << VOLTAGE_MODE_SLAVE_ADDRESS;
    qDebug() << "  寄存器地址:" << VOLTAGE_MODE_REGISTER_ADDRESS;
    qDebug() << "  写入值:" << voltage << "V";
    qDebug() << "========================================";

    writeHoldingRegister(VOLTAGE_MODE_SLAVE_ADDRESS, VOLTAGE_MODE_REGISTER_ADDRESS, static_cast<double>(voltage));
}

// 从站2不再使用
// void ModbusManager::setFanSwitch2State(bool state)
// {
//     m_fanSwitch2State = state;
//     emit fanSwitch2StateChanged();
//     
//     // 当风机2关闭时，重置从站2的相关状态
//     if (!state) {
//         // 重置从站2的状态数据
//         if (m_hasFanStateData2) {
//             m_hasFanStateData2 = false;
//             emit hasFanStateData2Changed();
//         }
//         if (m_hasHighTempData2) {
//             m_hasHighTempData2 = false;
//             emit hasHighTempData2Changed();
//         }
//         // 重置状态值
//         m_fanState2 = 0;
//         emit fanState2Changed();
//         m_highTempState2 = 0;
//         emit highTempState2Changed();
//         qDebug() << "========================================";
//         qDebug() << "风机2关闭，已重置从站2状态:";
//         qDebug() << "  从站2风机状态: 0";
//         qDebug() << "  从站2高温状态: 0";
//         qDebug() << "========================================";
//     }
// }

void ModbusManager::onRequestFailed(int requestId, const QString &error)
{
    qDebug() << "Modbus请求失败，ID:" << requestId << "错误:" << error;
    
    // 当请求失败时，重置数据有效性标志，这样温度状态和风机状态会显示为未连接
    bool resetData = false;
    
    if (m_hasFanStateData) {
        m_hasFanStateData = false;
        emit hasFanStateDataChanged();
        resetData = true;
    }
    if (m_hasHighTempData) {
        m_hasHighTempData = false;
        emit hasHighTempDataChanged();
        resetData = true;
    }
    // 从站2不再使用
    // if (m_hasFanStateData2) {
    //     m_hasFanStateData2 = false;
    //     emit hasFanStateData2Changed();
    //     resetData = true;
    // }
    // if (m_hasHighTempData2) {
    //     m_hasHighTempData2 = false;
    //     emit hasHighTempData2Changed();
    //     resetData = true;
    // }
    
    if (resetData) {
        qDebug() << "Modbus数据有效性标志已重置，状态将显示为未连接";
    }
}
