// ============================================================================//
// 串口管理器实现文件 (SerialPortManager.cpp)
// 功能：管理串口通信，包括端口扫描、连接控制和数据传输
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

#include "SerialPortManager.h"
#include "SerialRequestManager.h"
#include <QDebug>
#include <QString>
#include <QChar>
#include <QThread>

/**
 * @brief 构造函数
 * @param parent 父对象指针
 *
 * 初始化串口管理器，设置默认参数，并连接信号槽
 */
SerialPortManager::SerialPortManager(QObject *parent)
    : QObject(parent)
    , m_serialPort(new QSerialPort(this))
    , m_isConnected(false)
    , m_requestManager(new SerialRequestManager(this))
{
    updateAvailablePorts();

    connect(m_serialPort, &QSerialPort::readyRead, this, &SerialPortManager::onReadyRead);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &SerialPortManager::onErrorOccurred);
    
    m_requestManager->setSerialPortManager(this);
}

SerialRequestManager *SerialPortManager::requestManager() const
{
    return m_requestManager;
}

/**
 * @brief 析构函数
 *
 * 关闭已打开的串口连接
 */
SerialPortManager::~SerialPortManager()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }
}

/**
 * @brief 获取可用串口列表
 * @return 可用串口名称列表
 */
QStringList SerialPortManager::availablePorts() const
{
    return m_availablePorts;
}

/**
 * @brief 获取串口连接状态
 * @return true表示已连接，false表示未连接
 */
bool SerialPortManager::isConnected() const
{
    return m_isConnected;
}

/**
 * @brief 获取当前串口名称
 * @return 当前连接的串口名称
 */
QString SerialPortManager::currentPort() const
{
    return m_currentPort;
}

/**
 * @brief 刷新可用串口列表
 *
 * 更新可用串口列表并发送信号通知
 */
void SerialPortManager::refreshPorts()
{
    updateAvailablePorts();
    emit availablePortsChanged();
}

/**
 * @brief 打开指定串口
 * @param portName 串口名称
 * @param baudRate 波特率（默认9600）
 * @return true表示打开成功，false表示打开失败
 *
 * 配置串口参数：8位数据位、无校验、1位停止位、无流控制
 */
bool SerialPortManager::openPort(const QString &portName, int baudRate)
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudRate);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serialPort->open(QIODevice::ReadWrite)) {
        m_isConnected = true;
        m_currentPort = portName;
        emit isConnectedChanged();
        emit currentPortChanged();
        return true;
    } else {
        emit errorOccurred(m_serialPort->errorString());
        return false;
    }
}

/**
 * @brief 关闭当前串口
 *
 * 关闭串口并重置连接状态和当前端口信息
 */
void SerialPortManager::closePort()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        m_isConnected = false;
        m_currentPort.clear();
        emit isConnectedChanged();
        emit currentPortChanged();
    }
}

/**
 * @brief 向串口发送数据
 * @param data 要发送的数据（UTF-8编码的字符串或16进制格式字符串）
 * @return true表示发送成功，false表示发送失败
 *
 * 支持两种格式：
 * 1. 普通字符串：直接以UTF-8编码发送
 * 2. 16进制格式：如"55 01 60 B6"，会自动解析为字节数组发送
 */
bool SerialPortManager::sendData(const QString &data)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("串口未打开");
        return false;
    }

    QByteArray byteArray;
    
    // 检测是否是16进制格式（包含空格且都是16进制字符）
    if (data.contains(" ") || data.contains("0x") || data.contains("0X")) {
        // 16进制格式：解析为字节数组
        QStringList hexList = data.split(" ", Qt::SkipEmptyParts);
        for (const QString &hexStr : hexList) {
            bool ok;
            QString cleanHex = hexStr;
            // 移除0x或0X前缀
            if (cleanHex.startsWith("0x", Qt::CaseInsensitive)) {
                cleanHex = cleanHex.mid(2);
            }
            quint8 byte = cleanHex.toUInt(&ok, 16);
            if (ok) {
                byteArray.append(static_cast<char>(byte));
            } else {
                emit errorOccurred("无效的16进制格式: " + hexStr);
                return false;
            }
        }
    } else {
        // 普通字符串：UTF-8编码
        byteArray = data.toUtf8();
    }

    qint64 bytesWritten = m_serialPort->write(byteArray);
    return bytesWritten != -1;
}

/**
 * @brief 读取串口接收缓冲区数据
 * @return 读取到的数据（UTF-8编码的字符串）
 *
 * 读取后清空缓冲区
 */
QString SerialPortManager::readData()
{
    QString data = QString::fromUtf8(m_readBuffer);
    m_readBuffer.clear();
    return data;
}

/**
 * @brief 向串口发送原始字节数据
 * @param data 要发送的原始字节数据
 * @return true表示发送成功，false表示发送失败
 */
bool SerialPortManager::writeBytes(const QByteArray &data)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred("串口未打开");
        return false;
    }

    // 检查是否是读取命令（功能码03），如果是则不显示调试信息
    bool isReadCommand = false;
    if (data.size() >= 2) {
        quint8 functionCode = static_cast<quint8>(data[1]);
        isReadCommand = (functionCode == 0x03);
    }
    
    // 只显示非读取命令的调试信息
    if (!isReadCommand) {
        qDebug() << "=================================";
        QString hexStr;
        for (int i = 0; i < data.size(); i++) {
            hexStr += QString("%1 ").arg(static_cast<quint8>(data[i]), 2, 16, QChar('0')).toUpper();
        }
        qDebug() << "【SerialPort】准备发送数据:数据: \"" << hexStr.trimmed() << "\"";
    }
    
    qint64 bytesWritten = m_serialPort->write(data);
    
    if (bytesWritten != -1) {
        bool flushSuccess = m_serialPort->flush();
        
        // 尝试等待一小段时间确保数据发送
        QThread::msleep(10);
        
        if (!isReadCommand) {
            qDebug() << "发送完成";
            qDebug() << "=================================";
        }
    } else {
        if (!isReadCommand) {
            qDebug() << "发送失败:" << m_serialPort->errorString();
            qDebug() << "=================================";
        }
    }
    
    return bytesWritten != -1;
}

/**
 * @brief 读取串口接收缓冲区的原始字节数据
 * @return 读取到的原始字节数据
 *
 * 读取后清空缓冲区
 */
QByteArray SerialPortManager::readBytes()
{
    QByteArray data = m_readBuffer;
    m_readBuffer.clear();
    return data;
}

/**
 * @brief 串口数据可读时的槽函数
 *
 * 读取所有可用数据，追加到缓冲区，并发送数据接收信号（16进制格式）
 */
void SerialPortManager::onReadyRead()
{
    QByteArray data = m_serialPort->readAll();
    m_readBuffer.append(data);
    
    // 检查是否是读取命令的响应（功能码03），如果是则不显示调试信息
    bool isReadResponse = false;
    if (data.size() >= 2) {
        quint8 functionCode = static_cast<quint8>(data[1]);
        isReadResponse = (functionCode == 0x03);
    }
    
    // 将原始字节数据转换为16进制字符串格式（如 "AA 01 60 0B"）
    QString hexString;
    for (int i = 0; i < data.size(); ++i) {
        if (i > 0) {
            hexString += " ";
        }
        hexString += QString("%1").arg(static_cast<quint8>(data[i]), 2, 16, QChar('0')).toUpper();
    }
    
    // 打印完整的原始接收到的数据
    qDebug() << "=================================";
    qDebug() << "【SerialPort】接收到原始数据字节数:" << data.size();
    qDebug() << "【SerialPort】完整原始数据（十六进制）:" << hexString;
    qDebug() << "=================================";
    
    emit dataReceived(hexString);
    emit bytesReceived(data);
}

/**
 * @brief 串口错误发生时的槽函数
 * @param error 错误类型
 *
 * 发送错误信息信号
 */
void SerialPortManager::onErrorOccurred(QSerialPort::SerialPortError error)
{
    if (error != QSerialPort::NoError) {
        emit errorOccurred(m_serialPort->errorString());
    }
}

/**
 * @brief 更新可用串口列表
 *
 * 遍历系统所有可用串口并存储到列表中
 */
void SerialPortManager::updateAvailablePorts()
{
    m_availablePorts.clear();
    const auto ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &port : ports) {
        m_availablePorts.append(port.portName());
    }
}
