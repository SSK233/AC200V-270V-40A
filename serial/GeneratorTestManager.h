// ============================================================================//
// 发电机测试管理器头文件 (GeneratorTestManager.h)
// 功能：统一管理发电机测试的所有通信，包括测试命令、数据解析
// 版本：2.0.0
// 作者：skf
// 日期：2026-03-17
// ============================================================================//

#ifndef GENERATORTESTMANAGER_H
#define GENERATORTESTMANAGER_H

#include <QObject>
#include <QByteArray>
#include <QString>
#include <QVariant>
#include <QTimer>

class SerialPortManager;
class SerialRequestManager;

/**
 * @brief 发电机测试管理器类
 *
 * 该类负责统一管理发电机测试的所有通信，包括：
 * - 设备参数读取
 * - 三相参数读取
 * - 波动实验
 * - 突加/突卸实验
 * - 谐波实验
 * - 电压/频率整定实验
 * - 波形录波
 * - 数据解析和处理
 */
class GeneratorTestManager : public QObject
{
    Q_OBJECT

    /**
     * @brief 接收到的数据（十六进制字符串）
     */
    Q_PROPERTY(QString receivedData READ receivedData NOTIFY receivedDataChanged)
    
    /**
     * @brief 最后发送的命令（十六进制字符串）
     */
    Q_PROPERTY(QString lastSentCommand READ lastSentCommand NOTIFY lastSentCommandChanged)

public:
    /**
     * @brief 构造函数
     * @param parent 父对象指针
     */
    explicit GeneratorTestManager(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~GeneratorTestManager();

    /**
     * @brief 设置串口管理器
     * @param manager 串口管理器指针
     */
    Q_INVOKABLE void setSerialPortManager(SerialPortManager *manager);

    /**
     * @brief 发送十六进制消息（带超时和重传机制）
     * @param hexMessage 十六进制消息字符串，字节之间用空格分隔
     */
    Q_INVOKABLE void sendHexMessage(const QString &hexMessage);
    
    /**
     * @brief 直接发送十六进制消息（不使用请求管理器）
     * @param hexMessage 十六进制消息字符串，字节之间用空格分隔
     */
    Q_INVOKABLE void sendHexMessageDirect(const QString &hexMessage);
    
    /**
     * @brief 计算校验和
     * @param hexString 十六进制字符串
     * @return 校验和的十六进制字符串
     */
    Q_INVOKABLE QString calculateChecksum(const QString &hexString);
    
    /**
     * @brief 将浮点数转换为IEEE754单精度浮点数的十六进制字符串
     * @param value 要转换的浮点数值
     * @return IEEE754格式的十六进制字符串
     */
    Q_INVOKABLE QString parseFloatToIEEE754(double value);
    
    /**
     * @brief 将IEEE754单精度浮点数的十六进制字符串转换为浮点数
     * @param hexString IEEE754格式的十六进制字符串
     * @return 转换后的浮点数值
     */
    Q_INVOKABLE double parseIEEE754Float(const QString &hexString);

    /**
     * @brief 获取接收到的数据
     * @return 接收到的十六进制字符串
     */
    QString receivedData() const;
    
    /**
     * @brief 获取最后发送的命令
     * @return 最后发送的十六进制命令字符串
     */
    QString lastSentCommand() const;

    // =========================================================================
    // 设备参数和三相参数相关函数
    // =========================================================================
    
    /**
     * @brief 请求设备参数
     */
    Q_INVOKABLE void requestDeviceParams();
    
    /**
     * @brief 请求三相参数
     */
    Q_INVOKABLE void requestThreePhaseParams();
    
    /**
     * @brief 解析设备参数响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseDeviceParamsResponse(const QString &hexData);
    
    /**
     * @brief 解析三相参数响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseThreePhaseParamsResponse(const QString &hexData);

    // =========================================================================
    // 波动实验相关函数
    // =========================================================================
    
    /**
     * @brief 启动波动测试
     */
    Q_INVOKABLE void startWaveTest();
    
    /**
     * @brief 请求波动测试数据
     */
    Q_INVOKABLE void requestWaveTestData();
    
    /**
     * @brief 停止波动测试
     */
    Q_INVOKABLE void stopWaveTest();
    
    /**
     * @brief 解析波动测试响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseWaveTestResponse(const QString &hexData);

    // =========================================================================
    // 突加实验相关函数
    // =========================================================================
    
    /**
     * @brief 启动突加负载测试
     */
    Q_INVOKABLE void startSuddenAddTest();
    
    /**
     * @brief 请求突加测试电压数据
     */
    Q_INVOKABLE void requestSuddenAddTestData();
    
    /**
     * @brief 请求突加测试频率数据
     */
    Q_INVOKABLE void requestSuddenAddFrequencyData();
    
    /**
     * @brief 请求突加测试电流数据
     */
    Q_INVOKABLE void requestSuddenAddCurrentData();
    
    /**
     * @brief 停止突加负载测试
     */
    Q_INVOKABLE void stopSuddenAddTest();
    
    /**
     * @brief 解析突加测试电压响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenAddTestResponse(const QString &hexData);
    
    /**
     * @brief 解析突加测试频率响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenAddFrequencyResponse(const QString &hexData);
    
    /**
     * @brief 解析突加测试电流响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenAddCurrentResponse(const QString &hexData);

    // =========================================================================
    // 突卸实验相关函数
    // =========================================================================
    
    /**
     * @brief 启动突卸负载测试
     */
    Q_INVOKABLE void startSuddenLoadTest();
    
    /**
     * @brief 请求突卸测试电压数据
     */
    Q_INVOKABLE void requestSuddenLoadTestData();
    
    /**
     * @brief 请求突卸测试频率数据
     */
    Q_INVOKABLE void requestSuddenLoadFrequencyData();
    
    /**
     * @brief 请求突卸测试电流数据
     */
    Q_INVOKABLE void requestSuddenLoadCurrentData();
    
    /**
     * @brief 停止突卸负载测试
     */
    Q_INVOKABLE void stopSuddenLoadTest();
    
    /**
     * @brief 解析突卸测试电压响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenLoadTestResponse(const QString &hexData);
    
    /**
     * @brief 解析突卸测试频率响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenLoadFrequencyResponse(const QString &hexData);
    
    /**
     * @brief 解析突卸测试电流响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseSuddenLoadCurrentResponse(const QString &hexData);

    // =========================================================================
    // 谐波实验相关函数
    // =========================================================================
    
    /**
     * @brief 启动谐波测试
     */
    Q_INVOKABLE void startHarmonicTest();
    
    /**
     * @brief 请求谐波测试波形数据
     */
    Q_INVOKABLE void requestHarmonicWaveformData();
    
    /**
     * @brief 请求谐波测试数据
     */
    Q_INVOKABLE void requestHarmonicTestData();
    
    /**
     * @brief 请求退出谐波测试
     */
    Q_INVOKABLE void requestHarmonicExit();
    
    /**
     * @brief 停止谐波测试
     */
    Q_INVOKABLE void stopHarmonicTest();
    
    /**
     * @brief 解析谐波测试波形响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseHarmonicWaveformResponse(const QString &hexData);

    // =========================================================================
    // 整定实验和录波测试相关函数
    // =========================================================================
    
    /**
     * @brief 启动电压整定测试
     */
    Q_INVOKABLE void startVoltageCalibrationTest();
    
    /**
     * @brief 启动频率整定测试
     */
    Q_INVOKABLE void startFrequencyCalibrationTest();
    
    /**
     * @brief 请求整定测试数据
     */
    Q_INVOKABLE void requestCalibrationTestData();
    
    /**
     * @brief 停止整定测试
     */
    Q_INVOKABLE void stopCalibrationTest();
    
    /**
     * @brief 解析整定测试响应
     * @param hexData 接收到的十六进制数据
     * @return 解析成功返回true，否则返回false
     */
    Q_INVOKABLE bool parseCalibrationTestResponse(const QString &hexData);

    /**
     * @brief 启动波形录波测试
     */
    Q_INVOKABLE void startWaveformRecordTest();
    
    /**
     * @brief 停止波形录波测试
     */
    Q_INVOKABLE void stopWaveformRecordTest();

    /**
     * @brief 发送参数命令
     * @param commandCode 命令码（十六进制，两位）
     * @param valueHex 参数值（十六进制，可选）
     */
    Q_INVOKABLE void sendParameterCommand(const QString &commandCode, const QString &valueHex);

    // =========================================================================
    // 设备参数和三相参数Getter函数
    // =========================================================================
    
    Q_INVOKABLE QVariant getDevicePtRatio() const;
    Q_INVOKABLE QVariant getDeviceCtRatio() const;
    Q_INVOKABLE QVariant getDeviceVoltageSteady() const;
    Q_INVOKABLE QVariant getDeviceCurrentSteady() const;
    Q_INVOKABLE QVariant getDeviceFrequencySteady() const;
    Q_INVOKABLE QVariant getDeviceRatedVoltage() const;
    Q_INVOKABLE QVariant getDeviceRatedCurrent() const;
    Q_INVOKABLE QVariant getDeviceRatedFrequency() const;

    Q_INVOKABLE QVariant getThreePhaseVoltageA() const;
    Q_INVOKABLE QVariant getThreePhaseVoltageB() const;
    Q_INVOKABLE QVariant getThreePhaseVoltageC() const;
    Q_INVOKABLE QVariant getThreePhaseCurrentA() const;
    Q_INVOKABLE QVariant getThreePhaseCurrentB() const;
    Q_INVOKABLE QVariant getThreePhaseCurrentC() const;
    Q_INVOKABLE QVariant getThreePhaseFrequency() const;

    // =========================================================================
    // 波动实验Getter函数
    // =========================================================================
    
    Q_INVOKABLE QString getWaveTestRefPhase() const;
    Q_INVOKABLE QVariant getWaveTestVoltageMax() const;
    Q_INVOKABLE QVariant getWaveTestVoltageMin() const;
    Q_INVOKABLE QVariant getWaveTestFrequencyMax() const;
    Q_INVOKABLE QVariant getWaveTestFrequencyMin() const;

    // =========================================================================
    // 突加实验Getter函数
    // =========================================================================
    
    Q_INVOKABLE QString getSuddenAddTestRefPhase() const;
    Q_INVOKABLE QVariant getSuddenAddTestTolerance() const;
    Q_INVOKABLE QVariant getSuddenAddTestStableTime() const;
    Q_INVOKABLE QVariant getSuddenAddTestExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenAddTestMultiplier() const;
    Q_INVOKABLE QVariant getSuddenAddFrequencyTolerance() const;
    Q_INVOKABLE QVariant getSuddenAddFrequencyStableTime() const;
    Q_INVOKABLE QVariant getSuddenAddFrequencyExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenAddRatedNoLoadFrequency() const;
    Q_INVOKABLE QVariant getSuddenAddCurrentTolerance() const;
    Q_INVOKABLE QVariant getSuddenAddCurrentStableTime() const;
    Q_INVOKABLE QVariant getSuddenAddCurrentExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenAddCurrentMultiplier() const;

    // =========================================================================
    // 突卸实验Getter函数
    // =========================================================================
    
    Q_INVOKABLE QString getSuddenLoadTestRefPhase() const;
    Q_INVOKABLE QVariant getSuddenLoadTestTolerance() const;
    Q_INVOKABLE QVariant getSuddenLoadTestStableTime() const;
    Q_INVOKABLE QVariant getSuddenLoadTestExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenLoadTestMultiplier() const;
    Q_INVOKABLE QVariant getSuddenLoadFrequencyTolerance() const;
    Q_INVOKABLE QVariant getSuddenLoadFrequencyStableTime() const;
    Q_INVOKABLE QVariant getSuddenLoadFrequencyExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenLoadRatedNoLoadFrequency() const;
    Q_INVOKABLE QVariant getSuddenLoadCurrentTolerance() const;
    Q_INVOKABLE QVariant getSuddenLoadCurrentStableTime() const;
    Q_INVOKABLE QVariant getSuddenLoadCurrentExtremeValue() const;
    Q_INVOKABLE QVariant getSuddenLoadCurrentMultiplier() const;

    // =========================================================================
    // 谐波实验Getter函数
    // =========================================================================
    
    Q_INVOKABLE QString getHarmonicTestRefPhase() const;
    Q_INVOKABLE QVariantList getHarmonicTestVoltageWaveform() const;
    Q_INVOKABLE QVariantList getHarmonicTestCurrentWaveform() const;

    // =========================================================================
    // 整定实验Getter函数
    // =========================================================================
    
    Q_INVOKABLE QString getVoltageCalibrationRefPhase() const;
    Q_INVOKABLE QVariant getVoltageCalibrationUmax() const;
    Q_INVOKABLE QVariant getVoltageCalibrationUmin() const;
    Q_INVOKABLE QString getFrequencyCalibrationRefPhase() const;
    Q_INVOKABLE QVariant getFrequencyCalibrationFmax() const;
    Q_INVOKABLE QVariant getFrequencyCalibrationFmin() const;
    
    /**
     * @brief 清空接收缓冲区
     */
    Q_INVOKABLE void clearReceiveBuffer();

signals:
    /**
     * @brief 数据接收信号
     * @param data 接收到的十六进制数据
     */
    void dataReceived(const QString &data);
    
    /**
     * @brief 错误发生信号
     * @param error 错误信息
     */
    void errorOccurred(const QString &error);
    
    /**
     * @brief 接收到的数据改变信号
     */
    void receivedDataChanged();
    
    /**
     * @brief 最后发送的命令改变信号
     */
    void lastSentCommandChanged();

    /**
     * @brief 设备参数更新信号
     */
    void deviceParamsUpdated();
    
    /**
     * @brief 三相参数更新信号
     */
    void threePhaseParamsUpdated();
    
    /**
     * @brief 波动测试数据更新信号
     */
    void waveTestDataUpdated();
    
    /**
     * @brief 突加测试数据更新信号
     */
    void suddenAddTestDataUpdated();
    
    /**
     * @brief 突加频率数据更新信号
     */
    void suddenAddFrequencyDataUpdated();
    
    /**
     * @brief 突加电流数据更新信号
     */
    void suddenAddCurrentDataUpdated();
    
    /**
     * @brief 突卸测试数据更新信号
     */
    void suddenLoadTestDataUpdated();
    
    /**
     * @brief 突卸频率数据更新信号
     */
    void suddenLoadFrequencyDataUpdated();
    
    /**
     * @brief 突卸电流数据更新信号
     */
    void suddenLoadCurrentDataUpdated();
    
    /**
     * @brief 谐波波形数据更新信号
     */
    void harmonicWaveformDataUpdated();
    
    /**
     * @brief 整定测试数据更新信号
     */
    void calibrationTestDataUpdated();

private slots:
    /**
     * @brief 处理来自SerialRequestManager的数据（带超时重传机制）
     * @param data 接收到的数据
     */
    void onDataReceived(const QByteArray &data);
    
    /**
     * @brief 处理串口错误
     * @param error 错误信息
     */
    void onSerialPortError(const QString &error);
    
    /**
     * @brief 处理直接来自串口的数据（不带超时重传机制）
     * @param data 接收到的数据
     */
    void onDirectDataReceived(const QByteArray &data);

private:
    SerialPortManager *m_serialPortManager;       ///< 串口管理器指针
    SerialRequestManager *m_requestManager;       ///< 请求管理器指针
    QByteArray m_receiveBuffer;                    ///< 接收数据缓冲区
    QString m_receivedData;                        ///< 接收到的数据
    QString m_lastSentCommand;                     ///< 最后发送的命令
    
    /**
     * @brief 根据命令获取预期的响应长度
     * @param command 最后发送的命令字符串
     * @return 预期的响应字节数，0表示未知长度
     */
    int getExpectedResponseLength(const QString &command);

    // =========================================================================
    // 设备参数和三相参数成员变量
    // =========================================================================
    
    double m_devicePtRatio;        ///< 设备PT变比
    double m_deviceCtRatio;        ///< 设备CT变比
    double m_deviceVoltageSteady;  ///< 设备电压稳态值
    double m_deviceCurrentSteady;  ///< 设备电流稳态值
    double m_deviceFrequencySteady; ///< 设备频率稳态值
    double m_deviceRatedVoltage;   ///< 设备额定电压
    double m_deviceRatedCurrent;   ///< 设备额定电流
    double m_deviceRatedFrequency; ///< 设备额定频率

    double m_threePhaseVoltageA;   ///< A相电压
    double m_threePhaseVoltageB;   ///< B相电压
    double m_threePhaseVoltageC;   ///< C相电压
    double m_threePhaseCurrentA;   ///< A相电流
    double m_threePhaseCurrentB;   ///< B相电流
    double m_threePhaseCurrentC;   ///< C相电流
    double m_threePhaseFrequency;  ///< 频率

    // =========================================================================
    // 波动实验成员变量
    // =========================================================================
    
    QString m_waveTestRefPhase;         ///< 波动实验基准相
    double m_waveTestVoltageMax;        ///< 波动实验电压最大值
    double m_waveTestVoltageMin;        ///< 波动实验电压最小值
    double m_waveTestFrequencyMax;      ///< 波动实验频率最大值
    double m_waveTestFrequencyMin;      ///< 波动实验频率最小值

    // =========================================================================
    // 突加实验成员变量
    // =========================================================================
    
    QString m_suddenAddTestRefPhase;         ///< 突加实验基准相
    double m_suddenAddTestTolerance;          ///< 突加实验电压偏差
    int m_suddenAddTestStableTime;            ///< 突加实验电压稳定时间
    int m_suddenAddTestExtremeValue;          ///< 突加实验电压极值
    double m_suddenAddTestMultiplier;         ///< 突加实验电压倍率
    double m_suddenAddFrequencyTolerance;     ///< 突加实验频率偏差
    int m_suddenAddFrequencyStableTime;       ///< 突加实验频率稳定时间
    int m_suddenAddFrequencyExtremeValue;     ///< 突加实验频率极值
    double m_suddenAddRatedNoLoadFrequency;   ///< 突加实验额定空载频率
    double m_suddenAddCurrentTolerance;       ///< 突加实验电流偏差
    int m_suddenAddCurrentStableTime;         ///< 突加实验电流稳定时间
    int m_suddenAddCurrentExtremeValue;       ///< 突加实验电流极值
    double m_suddenAddCurrentMultiplier;      ///< 突加实验电流倍率

    // =========================================================================
    // 突卸实验成员变量
    // =========================================================================
    
    QString m_suddenLoadTestRefPhase;         ///< 突卸实验基准相
    double m_suddenLoadTestTolerance;          ///< 突卸实验电压偏差
    int m_suddenLoadTestStableTime;            ///< 突卸实验电压稳定时间
    int m_suddenLoadTestExtremeValue;          ///< 突卸实验电压极值
    double m_suddenLoadTestMultiplier;         ///< 突卸实验电压倍率
    double m_suddenLoadFrequencyTolerance;     ///< 突卸实验频率偏差
    int m_suddenLoadFrequencyStableTime;       ///< 突卸实验频率稳定时间
    int m_suddenLoadFrequencyExtremeValue;     ///< 突卸实验频率极值
    double m_suddenLoadRatedNoLoadFrequency;   ///< 突卸实验额定空载频率
    double m_suddenLoadCurrentTolerance;       ///< 突卸实验电流偏差
    int m_suddenLoadCurrentStableTime;         ///< 突卸实验电流稳定时间
    int m_suddenLoadCurrentExtremeValue;       ///< 突卸实验电流极值
    double m_suddenLoadCurrentMultiplier;      ///< 突卸实验电流倍率

    // =========================================================================
    // 谐波实验成员变量
    // =========================================================================
    
    QString m_harmonicTestRefPhase;             ///< 谐波实验基准相
    QVariantList m_harmonicTestVoltageWaveform; ///< 谐波实验电压波形数据
    QVariantList m_harmonicTestCurrentWaveform; ///< 谐波实验电流波形数据

    // =========================================================================
    // 整定实验成员变量
    // =========================================================================
    
    QString m_voltageCalibrationRefPhase;       ///< 电压整定基准相
    double m_voltageCalibrationUmax;             ///< 电压整定最大值
    double m_voltageCalibrationUmin;             ///< 电压整定最小值
    QString m_frequencyCalibrationRefPhase;     ///< 频率整定基准相
    double m_frequencyCalibrationFmax;           ///< 频率整定最大值
    double m_frequencyCalibrationFmin;           ///< 频率整定最小值

    /**
     * @brief 将十六进制字符串转换为字节数组
     * @param hexString 十六进制字符串，字节之间用空格分隔
     * @return 转换后的字节数组
     */
    QByteArray hexStringToByteArray(const QString &hexString);
    
    /**
     * @brief 将字节数组转换为十六进制字符串
     * @param data 要转换的字节数组
     * @return 转换后的十六进制字符串，字节之间用空格分隔
     */
    QString byteArrayToHexString(const QByteArray &data);
    
    /**
     * @brief 内部发送函数
     * @param data 要发送的数据
     * @param description 发送描述，用于调试日志
     */
    void sendInternal(const QByteArray &data, const QString &description);
};

#endif // GENERATORTESTMANAGER_H
