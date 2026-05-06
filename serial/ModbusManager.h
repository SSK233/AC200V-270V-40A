// ============================================================================//
// Modbus管理器头文件 (ModbusManager.h)
// 功能：负责Modbus RTU串行通信的管理，包括设备连接、数据读取和写入
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

#ifndef MODBUSMANAGER_H
#define MODBUSMANAGER_H

#include <QObject>
#include <QTimer>
#include <QByteArray>
#include <QPair>

class SerialPortManager;
class SerialRequestManager;

// /**
//  * @brief 电压读取相关常量定义
//  * @details 定义读取电压数据的Modbus配置
//  */
// constexpr int VOLTAGE_SLAVE_ADDRESS = 3;//从站地址3
// constexpr int VOLTAGE_REGISTER_ADDRESS = 0;//寄存器地址0

// /**
//  * @brief 电流读取相关常量定义
//  * @details 定义读取电流数据的Modbus配置
//  */
// constexpr int CURRENT_SLAVE_ADDRESS = 3;//从站地址3
// constexpr int CURRENT_REGISTER_ADDRESS = 1;//寄存器地址1

// /**
//  * @brief 功率读取相关常量定义
//  * @details 定义读取功率数据的Modbus配置
//  */
// constexpr int POWER_SLAVE_ADDRESS = 3;//从站地址3
// constexpr int POWER_REGISTER_ADDRESS = 3;//寄存器地址3

// /**
//  * @brief 电压写入相关常量定义
//  * @details 定义写入电压数据的Modbus配置
//  */
// constexpr int WRITE_VOLTAGE_SLAVE_ADDRESS = 1;//从站地址
// constexpr int WRITE_VOLTAGE_REGISTER_ADDRESS = 50;//寄存器地址

/**
 * @brief 电流写入相关常量定义
 * @details 定义写入电流数据的Modbus配置
 */
constexpr int WRITE_CURRENT_SLAVE_ADDRESS = 1;//从站地址1
// constexpr int WRITE_CURRENT_SLAVE_ADDRESS_2 = 2;//从站地址2（从站2不再使用）
constexpr int WRITE_CURRENT_REGISTER_ADDRESS_1 = 50;//寄存器地址50（1路电流）
constexpr int WRITE_CURRENT_REGISTER_ADDRESS_2 = 51;//寄存器地址51（2路电流）
constexpr int WRITE_CURRENT_REGISTER_ADDRESS_3 = 52;//寄存器地址52（3路电流）

/**
 * @brief 风机控制相关常量定义
 * @details 定义风机控制的Modbus配置
 */
constexpr int FAN_SLAVE_ADDRESS = 1;//从站地址1
constexpr int FAN_REGISTER_ADDRESS = 1;//寄存器地址1

/**
 * @brief 风机状态读取相关常量定义
 * @details 定义读取风机状态的Modbus配置
 */
constexpr int FAN_STATE_SLAVE_ADDRESS = 1;//从站地址1
constexpr int FAN_STATE_REGISTER_ADDRESS = 2;//寄存器地址2

// /**
//  * @brief 从站2风机状态读取相关常量定义
//  * @details 定义读取从站2风机状态的Modbus配置
//  */
// constexpr int FAN_STATE_SLAVE_ADDRESS_2 = 2;//从站地址2
// constexpr int FAN_STATE_REGISTER_ADDRESS_2 = 100;//寄存器地址100

/**
 * @brief 高温报警状态读取相关常量定义
 * @details 定义读取高温报警状态的Modbus配置
 */
constexpr int HIGH_TEMP_SLAVE_ADDRESS = 1;//从站地址1
constexpr int HIGH_TEMP_REGISTER_ADDRESS = 3;//寄存器地址3

// /**
//  * @brief 从站2高温报警状态读取相关常量定义
//  * @details 定义读取从站2高温报警状态的Modbus配置
//  */
// constexpr int HIGH_TEMP_SLAVE_ADDRESS_2 = 2;//从站地址2
// constexpr int HIGH_TEMP_REGISTER_ADDRESS_2 = 101;//寄存器地址101

/**
 * @brief 卸载控制相关常量定义
 * @details 定义卸载控制的Modbus配置
 */
constexpr int UNLOAD_SLAVE_ADDRESS = 1;//从站地址1
constexpr int UNLOAD_REGISTER_ADDRESS_1 = 35;//寄存器地址35（1路卸载）
constexpr int UNLOAD_REGISTER_ADDRESS_2 = 36;//寄存器地址36（2路卸载）
constexpr int UNLOAD_REGISTER_ADDRESS_3 = 37;//寄存器地址37（3路卸载）
constexpr int UNLOAD_REGISTER_ADDRESS_ALL = 38;//寄存器地址38（一键卸载所有）

/**
 * @brief 急停控制相关常量定义
 * @details 定义急停控制的Modbus配置
 */
constexpr int EMERGENCY_STOP_SLAVE_ADDRESS = 1;//从站地址1
constexpr int EMERGENCY_STOP_REGISTER_ADDRESS = 5;//寄存器地址5

/**
 * @brief 电压模式控制相关常量定义
 * @details 定义电压模式控制的Modbus配置，寄存器30
 *          0=300V模式, 1=250V模式, 2=100V模式
 */
constexpr int VOLTAGE_MODE_SLAVE_ADDRESS = 1;//从站地址1
constexpr int VOLTAGE_MODE_REGISTER_ADDRESS = 30;//寄存器地址30

/**
 * @brief Modbus管理器类
 * @details 负责Modbus RTU串行通信的管理，包括设备连接、数据读取和写入
 */
class ModbusManager : public QObject
{
    Q_OBJECT
    // /**
    //  * @brief 电压值属性
    //  * @details 存储当前读取的电压值，单位为伏特(V)
    //  */
    // Q_PROPERTY(double voltage READ voltage NOTIFY voltageChanged)
    
    // /**
    //  * @brief 电流值属性
    //  * @details 存储当前读取的电流值，单位为安培(A)
    //  */
    // Q_PROPERTY(double current READ current NOTIFY currentChanged)
    
    // /**
    //  * @brief 功率值属性
    //  * @details 存储当前读取的功率值，单位为千瓦(kW)
    //  */
    // Q_PROPERTY(double power READ power NOTIFY powerChanged)
    
    /**
     * @brief 连接状态属性
     * @details 存储当前Modbus设备的连接状态
     */
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    
    /**
     * @brief 风机状态属性
     * @details 存储当前风机的状态
     */
    Q_PROPERTY(int fanState READ fanState NOTIFY fanStateChanged)
    
    /**
     * @brief 高温报警状态属性
     * @details 存储当前高温报警的状态
     */
    Q_PROPERTY(int highTempState READ highTempState NOTIFY highTempStateChanged)
    
    /**
     * @brief 从站1突加状态属性
     * @details 存储从站1突加状态（寄存器102）
     */
    Q_PROPERTY(int burstAddState READ burstAddState NOTIFY burstAddStateChanged)
    
    /**
     * @brief 从站1突卸状态属性
     * @details 存储从站1突卸状态（寄存器103）
     */
    Q_PROPERTY(int burstRemoveState READ burstRemoveState NOTIFY burstRemoveStateChanged)
    
    /**
     * @brief 风机状态数据有效性属性
     * @details 标识是否已获取有效的风机状态数据
     */
    Q_PROPERTY(bool hasFanStateData READ hasFanStateData NOTIFY hasFanStateDataChanged)
    
    /**
     * @brief 高温报警状态数据有效性属性
     * @details 标识是否已获取有效的高温报警状态数据
     */
    Q_PROPERTY(bool hasHighTempData READ hasHighTempData NOTIFY hasHighTempDataChanged)
    
    /**
     * @brief 单相电压属性
     * @details 存储读取到的单相电压值
     */
    Q_PROPERTY(double singlePhaseVoltage READ singlePhaseVoltage NOTIFY singlePhaseVoltageChanged)
    
    /**
     * @brief 单相电流属性
     * @details 存储读取到的单相电流值
     */
    Q_PROPERTY(double singlePhaseCurrent READ singlePhaseCurrent NOTIFY singlePhaseCurrentChanged)
    
    /**
     * @brief 单相功率属性
     * @details 存储读取到的单相功率值
     */
    Q_PROPERTY(double singlePhasePower READ singlePhasePower NOTIFY singlePhasePowerChanged)

public:
    /**
     * @brief 构造函数
     * @param parent 父对象
     */
    explicit ModbusManager(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~ModbusManager();

    // /**
    //  * @brief 获取电压值
    //  * @return 当前电压值
    //  */
    // double voltage() const { return m_voltage; }
    
    // /**
    //  * @brief 获取电流值
    //  * @return 当前电流值
    //  */
    // double current() const { return m_current; }
    
    // /**
    //  * @brief 获取功率值
    //  * @return 当前功率值
    //  */
    // double power() const { return m_power; }
    
    /**
     * @brief 获取连接状态
     * @return 当前连接状态
     */
    bool connected() const { return m_connected; }
    
    /**
     * @brief 获取风机状态
     * @return 当前风机状态
     */
    int fanState() const { return m_fanState; }
    
    /**
     * @brief 获取高温报警状态
     * @return 当前高温报警状态
     */
    int highTempState() const { return m_highTempState; }
    
    /**
     * @brief 获取从站1突加状态
     * @return 从站1突加状态
     */
    int burstAddState() const { return m_burstAddState; }
    
    /**
     * @brief 获取从站1突卸状态
     * @return 从站1突卸状态
     */
    int burstRemoveState() const { return m_burstRemoveState; }
    
    /**
     * @brief 获取风机状态数据有效性
     * @return 是否有有效的风机状态数据
     */
    bool hasFanStateData() const { return m_hasFanStateData; }
    
    /**
     * @brief 获取高温报警状态数据有效性
     * @return 是否有有效的高温报警状态数据
     */
    bool hasHighTempData() const { return m_hasHighTempData; }
    
    /**
     * @brief 获取单相电压值
     * @return 当前单相电压值
     */
    double singlePhaseVoltage() const { return m_singlePhaseVoltage; }
    
    /**
     * @brief 获取单相电流值
     * @return 当前单相电流值
     */
    double singlePhaseCurrent() const { return m_singlePhaseCurrent; }
    
    /**
     * @brief 获取单相功率值
     * @return 当前单相功率值
     */
    double singlePhasePower() const { return m_singlePhasePower; }

    /**
     * @brief 连接到Modbus设备
     * @param portName 串口名称
     * @param baudRate 波特率，默认为9600
     * @param parity 校验位，默认为0（无校验）
     * @return 连接是否成功
     */
    Q_INVOKABLE bool connectToPort(const QString &portName, int baudRate = 9600, int parity = 0);
    
    /**
     * @brief 断开与Modbus设备的连接
     */
    Q_INVOKABLE void disconnectPort();
    
    /**
     * @brief 开始定时读取数据
     * @param intervalMs 读取间隔，单位为毫秒，默认为1000ms
     */
    Q_INVOKABLE void startReading(int intervalMs = 1000);
    
    /**
     * @brief 停止定时读取数据
     */
    Q_INVOKABLE void stopReading();
    
    // /**
    //  * @brief 写入电压值
    //  * @param value 要写入的电压值
    //  */
    // Q_INVOKABLE void writeVoltage(double value);
    
    /**
     * @brief 写入电流值
     * @param value 要写入的电流值
     * @param channel 电流通道（1-3）
     */
    Q_INVOKABLE void writeCurrent(double value, int channel);
    
    // /**
    //  * @brief 计算从站2的档位组合
    //  * @param power 功率值
    //  * @return 计算后的功率值
    //  */
    // int calculateSlave2Power(double power);
    

    
    /**
     * @brief 写入风机状态
     * @param state 风机状态，true为开启，false为关闭
     * @param slaveAddress 从站地址，默认为1
     */
    Q_INVOKABLE void writeFanState(bool state, int slaveAddress = 1);
    
    // /**
    //  * @brief 同时写入电压和电流值
    //  * @param voltage 要写入的电压值
    //  * @param current 要写入的电流值
    //  */
    // Q_INVOKABLE void writeVoltageAndCurrent(double voltage, double current);
    
    /**
     * @brief 写入卸载控制命令
     * @param channel 卸载通道（1-3），默认值为0表示全部卸载
     */
    Q_INVOKABLE void writeUnload(int channel = 0);
    
    /**
     * @brief 写入急停控制命令
     * @param state 急停状态，true为正常(1)，false为急停(0)
     */
    Q_INVOKABLE void writeEmergencyStop(bool state);

    /**
     * @brief 写入电压模式
     * @param mode 电压模式：0=300V, 1=250V, 2=100V
     */
    Q_INVOKABLE void writeVoltageMode(int mode);

    /**
     * @brief 直接写入电压值
     * @param voltage 电压值，范围200-270V
     */
    Q_INVOKABLE void writeVoltageValue(int voltage);
    
    /**
     * @brief 设置串口管理器
     * @param serialPortManager 串口管理器指针
     */
    Q_INVOKABLE void setSerialPortManager(SerialPortManager *serialPortManager);

    /**
     * @brief 写入保持寄存器
     * @param slaveAddress 从站地址
     * @param registerAddress 寄存器地址
     * @param value 要写入的值
     */
    Q_INVOKABLE void writeHoldingRegister(int slaveAddress, int registerAddress, double value);

signals:
    // /**
    //  * @brief 电压值变化信号
    //  * @details 当电压值发生变化时触发
    //  */
    // void voltageChanged();
    
    /**
     * @brief 急停命令发送完成信号
     * @details 当急停命令发送完成时触发
     */
    void emergencyStopSent();
    
    // /**
    //  * @brief 电流值变化信号
    //  * @details 当电流值发生变化时触发
    //  */
    // void currentChanged();
    
    // /**
    //  * @brief 功率值变化信号
    //  * @details 当功率值发生变化时触发
    //  */
    // void powerChanged();
    
    /**
     * @brief 连接状态变化信号
     * @details 当连接状态发生变化时触发
     */
    void connectedChanged();
    
    /**
     * @brief 风机状态变化信号
     * @details 当风机状态发生变化时触发
     */
    void fanStateChanged();
    
    /**
     * @brief 高温报警状态变化信号
     * @details 当高温报警状态发生变化时触发
     */
    void highTempStateChanged();
    
    /**
     * @brief 从站1突加状态变化信号
     * @details 当从站1突加状态发生变化时触发
     */
    void burstAddStateChanged();
    
    /**
     * @brief 从站1突卸状态变化信号
     * @details 当从站1突卸状态发生变化时触发
     */
    void burstRemoveStateChanged();
    
    /**
     * @brief 风机状态数据有效性变化信号
     * @details 当风机状态数据有效性发生变化时触发
     */
    void hasFanStateDataChanged();
    
    /**
     * @brief 高温报警状态数据有效性变化信号
     * @details 当高温报警状态数据有效性发生变化时触发
     */
    void hasHighTempDataChanged();
    
    /**
     * @brief 单相电压值变化信号
     * @details 当单相电压值发生变化时触发
     */
    void singlePhaseVoltageChanged();
    
    /**
     * @brief 单相电流值变化信号
     * @details 当单相电流值发生变化时触发
     */
    void singlePhaseCurrentChanged();
    
    /**
     * @brief 单相功率值变化信号
     * @details 当单相功率值发生变化时触发
     */
    void singlePhasePowerChanged();
    
    /**
     * @brief 错误发生信号
     * @details 当Modbus通信发生错误时触发
     * @param error 错误信息
     */
    void errorOccurred(const QString &error);
    
    /**
     * @brief 连接超时信号
     * @details 当连接后10秒内未收到有效数据时触发
     */
    void connectionTimeout();

private slots:
    /**
     * @brief 处理请求失败
     * @details 当SerialRequestManager的请求失败时触发
     * @param requestId 请求ID
     * @param error 错误信息
     */
    void onRequestFailed(int requestId, const QString &error);
    /**
     * @brief 串口数据接收槽函数
     * @details 处理串口接收到的数据
     * @param data 接收到的数据
     */
    void onBytesReceived(const QByteArray &data);
    
    /**
     * @brief 串口连接状态变化槽函数
     * @details 处理串口连接状态变化
     */
    void onSerialPortConnectedChanged();
    
    /**
     * @brief 读取所有寄存器槽函数
     * @details 定时读取所有需要的寄存器值
     */
    void readAllRegisters();

private:
    /**
     * @brief 串口管理器
     */
    SerialPortManager *m_serialPortManager;
    
    /**
     * @brief 读取定时器
     * @details 用于定时触发数据读取
     */
    QTimer *m_readTimer;
    
    /**
     * @brief 接收缓冲区
     * @details 用于存储接收到的Modbus数据
     */
    QByteArray m_receiveBuffer;
    
    /**
     * @brief 待处理的请求队列
     */
    struct PendingRequest {
        int slaveAddress;
        int registerAddress;
        bool isRead;
    };
    QList<PendingRequest> m_pendingRequests;
    
    // /**
    //  * @brief 电压值
    //  */
    // double m_voltage;
    
    // /**
    //  * @brief 电流值
    //  */
    // double m_current;
    
    // /**
    //  * @brief 功率值
    //  */
    // double m_power;
    
    /**
     * @brief 连接状态
     */
    bool m_connected;
    
    /**
     * @brief 风机状态
     */
    int m_fanState;
    
    /**
     * @brief 高温报警状态
     */
    int m_highTempState;
    
    /**
     * @brief 从站1突加状态
     */
    int m_burstAddState;
    
    /**
     * @brief 从站1突卸状态
     */
    int m_burstRemoveState;
    
    /**
     * @brief 风机状态数据有效性
     */
    bool m_hasFanStateData;
    
    /**
     * @brief 高温报警状态数据有效性
     */
    bool m_hasHighTempData;
    
    /**
     * @brief 单相电压值
     */
    double m_singlePhaseVoltage;
    
    /**
     * @brief 单相电流值
     */
    double m_singlePhaseCurrent;
    
    /**
     * @brief 单相功率值
     */
    double m_singlePhasePower;
    
    /**
     * @brief 待处理的读取请求数量
     */
    int m_pendingReads;
    
    /**
     * @brief 连接超时定时器
     * @details 用于检测连接后是否在10秒内收到有效数据
     */
    QTimer *m_connectionTimeoutTimer;
    
    /**
     * @brief 第一次读取超时时间
     * @details 用于记录从站断电后第一次读取超时的时间，用于检测10秒超时
     */
    qint64 m_firstTimeoutTime;
    
    /**
     * @brief 读取队列
     * @details 用于存储待读取的寄存器请求，实现顺序读取
     */
    QList<QPair<int, int>> m_readQueue;

    /**
     * @brief 读取保持寄存器
     * @param slaveAddress 从站地址
     * @param registerAddress 寄存器地址
     */
    void readHoldingRegister(int slaveAddress, int registerAddress);
};

#endif
