// ============================================================================//
// 串口管理器头文件 (SerialPortManager.h)
// 功能：管理串口通信，包括端口扫描、连接控制和数据传输
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

#ifndef SERIALPORTMANAGER_H
#define SERIALPORTMANAGER_H

#include <QObject>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QStringList>
#include <QVariantList>

/**
 * @class SerialPortManager
 * @brief 串口管理器类
 * @details 负责串口通信的管理，包括端口扫描、连接控制和数据传输
 * @inherits QObject
 */
class SerialRequestManager;

class SerialPortManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(QString currentPort READ currentPort NOTIFY currentPortChanged)

public:
    /**
     * @brief 构造函数
     * @param parent 父对象指针
     */
    explicit SerialPortManager(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~SerialPortManager();

    /**
     * @brief 获取可用串口列表
     * @return 可用串口名称列表
     */
    QStringList availablePorts() const;
    
    /**
     * @brief 获取连接状态
     * @return 是否已连接
     */
    bool isConnected() const;
    
    /**
     * @brief 获取当前连接的串口名称
     * @return 当前串口名称
     */
    QString currentPort() const;

    /**
     * @brief 获取串口请求管理器
     * @return 串口请求管理器指针
     */
    SerialRequestManager *requestManager() const;

    /**
     * @brief 刷新可用串口列表
     */
    Q_INVOKABLE void refreshPorts();
    
    /**
     * @brief 打开串口
     * @param portName 串口名称
     * @param baudRate 波特率，默认为9600
     * @return 是否打开成功
     */
    Q_INVOKABLE bool openPort(const QString &portName, int baudRate = 9600);
    
    /**
     * @brief 关闭串口
     */
    Q_INVOKABLE void closePort();
    
    /**
     * @brief 发送数据
     * @param data 要发送的数据（UTF-8编码的字符串或16进制格式字符串）
     * @return 是否发送成功
     * 
     * 支持两种格式：
     * 1. 普通字符串：直接以UTF-8编码发送
     * 2. 16进制格式：如"55 01 60 B6"，会自动解析为字节数组发送
     */
    Q_INVOKABLE bool sendData(const QString &data);
    
    /**
     * @brief 读取数据
     * @return 读取的数据
     */
    Q_INVOKABLE QString readData();
    
    Q_INVOKABLE bool writeBytes(const QByteArray &data);
    Q_INVOKABLE QByteArray readBytes();

signals:
    /**
     * @brief 可用串口列表变化信号
     */
    void availablePortsChanged();
    
    /**
     * @brief 连接状态变化信号
     */
    void isConnectedChanged();
    
    /**
     * @brief 当前串口变化信号
     */
    void currentPortChanged();
    
    /**
     * @brief 数据接收信号
     * @param data 接收到的数据
     */
    void dataReceived(const QString &data);
    
    /**
     * @brief 字节数据接收信号
     * @param data 接收到的原始字节数据
     */
    void bytesReceived(const QByteArray &data);
    
    /**
     * @brief 错误发生信号
     * @param error 错误信息
     */
    void errorOccurred(const QString &error);

private slots:
    /**
     * @brief 数据可读槽函数
     * @details 处理串口接收到的数据
     */
    void onReadyRead();
    
    /**
     * @brief 错误发生槽函数
     * @param error 错误类型
     * @details 处理串口错误
     */
    void onErrorOccurred(QSerialPort::SerialPortError error);

private:
    QSerialPort *m_serialPort;        // 串口对象
    QStringList m_availablePorts;     // 可用串口列表
    bool m_isConnected;               // 连接状态
    QString m_currentPort;            // 当前连接的串口名称
    QByteArray m_readBuffer;          // 读取缓冲区
    SerialRequestManager *m_requestManager; // 串口请求管理器

    /**
     * @brief 更新可用串口列表
     */
    void updateAvailablePorts();
};

#endif
