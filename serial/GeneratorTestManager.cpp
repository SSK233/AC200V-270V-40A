// ============================================================================//
// 发电机测试管理器实现文件 (GeneratorTestManager.cpp)
// 功能：统一管理发电机测试的所有通信，包括测试命令、数据解析
// 版本：2.0.0
// 作者：skf
// 日期：2026-03-17
// ============================================================================//

#include "GeneratorTestManager.h"
#include "SerialPortManager.h"
#include "SerialRequestManager.h"
#include <QDebug>
#include <QChar>
#include <QDataStream>
#include <QMetaObject>

/**
 * @brief 构造函数
 * @param parent 父对象指针
 *
 * 初始化GeneratorTestManager，设置所有成员变量的初始值
 */
GeneratorTestManager::GeneratorTestManager(QObject *parent)
    : QObject(parent)
    , m_serialPortManager(nullptr)
    , m_requestManager(nullptr)
    , m_devicePtRatio(0.0)
    , m_deviceCtRatio(0.0)
    , m_deviceVoltageSteady(0.0)
    , m_deviceCurrentSteady(0.0)
    , m_deviceFrequencySteady(0.0)
    , m_deviceRatedVoltage(0.0)
    , m_deviceRatedCurrent(0.0)
    , m_deviceRatedFrequency(0.0)
    , m_threePhaseVoltageA(0.0)
    , m_threePhaseVoltageB(0.0)
    , m_threePhaseVoltageC(0.0)
    , m_threePhaseCurrentA(0.0)
    , m_threePhaseCurrentB(0.0)
    , m_threePhaseCurrentC(0.0)
    , m_threePhaseFrequency(0.0)
    , m_waveTestVoltageMax(0.0)
    , m_waveTestVoltageMin(0.0)
    , m_waveTestFrequencyMax(0.0)
    , m_waveTestFrequencyMin(0.0)
    , m_suddenAddTestTolerance(0.0)
    , m_suddenAddTestStableTime(0)
    , m_suddenAddTestExtremeValue(0)
    , m_suddenAddTestMultiplier(0.0)
    , m_suddenAddFrequencyTolerance(0.0)
    , m_suddenAddFrequencyStableTime(0)
    , m_suddenAddFrequencyExtremeValue(0)
    , m_suddenAddRatedNoLoadFrequency(0.0)
    , m_suddenAddCurrentTolerance(0.0)
    , m_suddenAddCurrentStableTime(0)
    , m_suddenAddCurrentExtremeValue(0)
    , m_suddenAddCurrentMultiplier(0.0)
    , m_suddenLoadTestTolerance(0.0)
    , m_suddenLoadTestStableTime(0)
    , m_suddenLoadTestExtremeValue(0)
    , m_suddenLoadTestMultiplier(0.0)
    , m_suddenLoadFrequencyTolerance(0.0)
    , m_suddenLoadFrequencyStableTime(0)
    , m_suddenLoadFrequencyExtremeValue(0)
    , m_suddenLoadRatedNoLoadFrequency(0.0)
    , m_suddenLoadCurrentTolerance(0.0)
    , m_suddenLoadCurrentStableTime(0)
    , m_suddenLoadCurrentExtremeValue(0)
    , m_suddenLoadCurrentMultiplier(0.0)
    , m_voltageCalibrationUmax(0.0)
    , m_voltageCalibrationUmin(0.0)
    , m_frequencyCalibrationFmax(0.0)
    , m_frequencyCalibrationFmin(0.0)
{
}

/**
 * @brief 析构函数
 *
 * 清理GeneratorTestManager资源
 */
GeneratorTestManager::~GeneratorTestManager()
{
}

/**
 * @brief 设置串口管理器
 * @param manager 串口管理器指针
 *
 * 连接串口管理器的信号，并获取请求管理器
 */
void GeneratorTestManager::setSerialPortManager(SerialPortManager *manager)
{
    if (m_serialPortManager) {
        disconnect(m_serialPortManager, &SerialPortManager::errorOccurred,
                   this, &GeneratorTestManager::onSerialPortError);
    }

    m_serialPortManager = manager;

    if (m_serialPortManager) {
        m_requestManager = m_serialPortManager->requestManager();
        connect(m_serialPortManager, &SerialPortManager::errorOccurred,
                this, &GeneratorTestManager::onSerialPortError);
    }
}

/**
 * @brief 发送十六进制消息
 * @param hexMessage 十六进制消息字符串，字节之间用空格分隔
 *
 * 通过请求管理器发送十六进制消息，带有超时和重传机制
 */
void GeneratorTestManager::sendHexMessage(const QString &hexMessage)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        emit errorOccurred("串口未打开，无法发送报文");
        return;
    }
    
    if (!m_requestManager) {
        emit errorOccurred("请求管理器未初始化");
        return;
    }

    QByteArray data = hexStringToByteArray(hexMessage);
    m_lastSentCommand = hexMessage;
    emit lastSentCommandChanged();
    sendInternal(data, hexMessage);
}

/**
 * @brief 直接发送十六进制消息
 * @param hexMessage 十六进制消息字符串，字节之间用空格分隔
 *
 * 直接通过串口发送十六进制消息，不使用请求管理器
 */
void GeneratorTestManager::sendHexMessageDirect(const QString &hexMessage)
{
    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        emit errorOccurred("串口未打开，无法发送报文");
        return;
    }

    QByteArray data = hexStringToByteArray(hexMessage);
    m_lastSentCommand = hexMessage;
    emit lastSentCommandChanged();
    m_receiveBuffer.clear();
    m_serialPortManager->writeBytes(data);
    qDebug() << "[GeneratorTestManager] 直接发送:" << hexMessage;
}

/**
 * @brief 计算校验和
 * @param hexString 十六进制字符串
 * @return 校验和的十六进制字符串
 *
 * 计算所有字节的累加和，取低8位作为校验和
 */
QString GeneratorTestManager::calculateChecksum(const QString &hexString)
{
    QStringList bytes = hexString.trimmed().split(" ", Qt::SkipEmptyParts);
    int sum = 0;
    for (const QString &byteStr : bytes) {
        bool ok;
        sum += byteStr.toInt(&ok, 16);
    }
    int checksum = sum % 256;
    QString hex = QString("%1").arg(checksum, 2, 16, QChar('0')).toUpper();
    return hex;
}

/**
 * @brief 将浮点数转换为IEEE754单精度浮点数的十六进制字符串
 * @param value 要转换的浮点数值
 * @return IEEE754格式的十六进制字符串，字节之间用空格分隔
 *
 * 使用大端序（Big-Endian）格式转换
 */
QString GeneratorTestManager::parseFloatToIEEE754(double value)
{
    QByteArray buffer(4, 0);
    QDataStream stream(&buffer, QIODevice::WriteOnly);
    stream.setFloatingPointPrecision(QDataStream::SinglePrecision);
    stream.setByteOrder(QDataStream::BigEndian);
    stream << static_cast<float>(value);

    QStringList hexBytes;
    for (int i = 0; i < 4; i++) {
        quint8 byte = static_cast<quint8>(buffer[i]);
        hexBytes.append(QString("%1").arg(byte, 2, 16, QChar('0')).toUpper());
    }
    return hexBytes.join(" ");
}

/**
 * @brief 将IEEE754单精度浮点数的十六进制字符串转换为浮点数
 * @param hexString IEEE754格式的十六进制字符串
 * @return 转换后的浮点数值
 *
 * 使用小端序（Little-Endian）格式转换
 */
double GeneratorTestManager::parseIEEE754Float(const QString &hexString)
{
    QStringList bytes = hexString.trimmed().split(" ", Qt::SkipEmptyParts);
    if (bytes.size() != 4) {
        return 0.0;
    }

    QByteArray buffer;
    for (const QString &byteStr : bytes) {
        bool ok;
        buffer.append(static_cast<char>(byteStr.toInt(&ok, 16)));
    }

    QDataStream stream(buffer);
    stream.setFloatingPointPrecision(QDataStream::SinglePrecision);
    stream.setByteOrder(QDataStream::LittleEndian);
    float value;
    stream >> value;

    return static_cast<double>(value);
}

/**
 * @brief 获取接收到的数据
 * @return 接收到的十六进制字符串
 */
QString GeneratorTestManager::receivedData() const
{
    return m_receivedData;
}

/**
 * @brief 获取最后发送的命令
 * @return 最后发送的十六进制命令字符串
 */
QString GeneratorTestManager::lastSentCommand() const
{
    return m_lastSentCommand;
}

/**
 * @brief 请求设备参数
 *
 * 发送命令请求读取设备的基本参数（PT/CT变比、额定电压、额定频率等）
 */
void GeneratorTestManager::requestDeviceParams()
{
    qDebug() << "[GeneratorTestManager] 请求设备参数...";
    sendHexMessage("55 01 4A A0");
}

/**
 * @brief 请求三相参数
 *
 * 发送命令请求读取当前的三相电压、电流和频率
 */
void GeneratorTestManager::requestThreePhaseParams()
{
    sendHexMessage("55 01 39 8F");
}

/**
 * @brief 解析设备参数响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析设备参数响应，包括PT/CT变比、电压/电流/频率稳态值、额定值等
 */
bool GeneratorTestManager::parseDeviceParamsResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    qDebug() << "[GeneratorTestManager] 接收到设备参数响应，总字节数:" << bytes.length();
    qDebug() << "[GeneratorTestManager] 完整数据:" << hexData;
    if (bytes.length() != 36) {
        qDebug() << "[GeneratorTestManager] 设备参数响应长度错误，需要36字节，实际:" << bytes.length();
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "4A") {
        qDebug() << "[GeneratorTestManager] 设备参数响应格式错误，帧头或命令码不正确";
        return false;
    }
    
    int checksum = 0;
    for (int i = 0; i < 35; i++) {
        checksum += bytes[i].toInt(nullptr, 16);
    }
    checksum = checksum % 256;
    int receivedChecksum = bytes[35].toInt(nullptr, 16);
    qDebug() << "[GeneratorTestManager] 校验码计算:" << QString::number(checksum, 16) << "接收:" << QString::number(receivedChecksum, 16);
    if (checksum != receivedChecksum) {
        qDebug() << "[GeneratorTestManager] 设备参数校验码错误 - 计算值:" << QString::number(checksum, 16) << ", 接收值:" << QString::number(receivedChecksum, 16);
        return false;
    }
    
    qDebug() << "[GeneratorTestManager] --- 开始解析各个参数 ---";
    m_devicePtRatio = parseIEEE754Float(bytes[3] + " " + bytes[4] + " " + bytes[5] + " " + bytes[6]);
    m_deviceCtRatio = parseIEEE754Float(bytes[7] + " " + bytes[8] + " " + bytes[9] + " " + bytes[10]);
    m_deviceVoltageSteady = parseIEEE754Float(bytes[11] + " " + bytes[12] + " " + bytes[13] + " " + bytes[14]);
    m_deviceCurrentSteady = parseIEEE754Float(bytes[15] + " " + bytes[16] + " " + bytes[17] + " " + bytes[18]);
    m_deviceFrequencySteady = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22]);
    m_deviceRatedVoltage = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22]);
    m_deviceRatedCurrent = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26]);
    m_deviceRatedFrequency = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26]);
    
    qDebug() << "[GeneratorTestManager] 设备参数读取成功 - 额定电压:" << m_deviceRatedVoltage << ", 额定频率:" << m_deviceRatedFrequency;
    emit deviceParamsUpdated();
    return true;
}

/**
 * @brief 解析三相参数响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析三相参数响应，包括三相电压、三相电流和频率
 */
bool GeneratorTestManager::parseThreePhaseParamsResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() != 32) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "39") {
        return false;
    }
    
    int checksum = 0;
    for (int i = 0; i < 31; i++) {
        checksum += bytes[i].toInt(nullptr, 16);
    }
    checksum = checksum % 256;
    int receivedChecksum = bytes[31].toInt(nullptr, 16);
    if (checksum != receivedChecksum) {
        return false;
    }
    
    m_threePhaseVoltageA = parseIEEE754Float(bytes[3] + " " + bytes[4] + " " + bytes[5] + " " + bytes[6]);
    m_threePhaseVoltageB = parseIEEE754Float(bytes[7] + " " + bytes[8] + " " + bytes[9] + " " + bytes[10]);
    m_threePhaseVoltageC = parseIEEE754Float(bytes[11] + " " + bytes[12] + " " + bytes[13] + " " + bytes[14]);
    m_threePhaseCurrentA = parseIEEE754Float(bytes[15] + " " + bytes[16] + " " + bytes[17] + " " + bytes[18]);
    m_threePhaseCurrentB = parseIEEE754Float(bytes[19] + " " + bytes[20] + " " + bytes[21] + " " + bytes[22]);
    m_threePhaseCurrentC = parseIEEE754Float(bytes[23] + " " + bytes[24] + " " + bytes[25] + " " + bytes[26]);
    m_threePhaseFrequency = parseIEEE754Float(bytes[27] + " " + bytes[28] + " " + bytes[29] + " " + bytes[30]);
    
    emit threePhaseParamsUpdated();
    return true;
}

/**
 * @brief 启动波动测试
 *
 * 发送命令启动电压/频率波动测试
 */
void GeneratorTestManager::startWaveTest()
{
    sendHexMessage("55 01 60 B6");
}

/**
 * @brief 请求波动测试数据
 *
 * 发送命令请求读取波动测试的测试结果数据
 */
void GeneratorTestManager::requestWaveTestData()
{
    sendHexMessage("55 01 61 B7");
}

/**
 * @brief 停止波动测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopWaveTest()
{
}

/**
 * @brief 解析波动测试响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析波动测试响应，包括基准相、电压最大值/最小值、频率最大值/最小值等
 */
bool GeneratorTestManager::parseWaveTestResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() != 21) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "61") {
        return false;
    }
    
    int checksum = 0;
    for (int i = 0; i < 20; i++) {
        checksum += bytes[i].toInt(nullptr, 16);
    }
    checksum = checksum % 256;
    int receivedChecksum = bytes[20].toInt(nullptr, 16);
    if (checksum != receivedChecksum) {
        qDebug() << "[GeneratorTestManager] 校验码错误: 计算值=" << QString::number(checksum, 16) << ", 接收值=" << QString::number(receivedChecksum, 16);
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_waveTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_waveTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_waveTestRefPhase = "C相";
    } else {
        m_waveTestRefPhase = "未知";
    }
    
    m_waveTestVoltageMax = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    m_waveTestVoltageMin = parseIEEE754Float(bytes[8] + " " + bytes[9] + " " + bytes[10] + " " + bytes[11]);
    m_waveTestFrequencyMax = parseIEEE754Float(bytes[12] + " " + bytes[13] + " " + bytes[14] + " " + bytes[15]);
    m_waveTestFrequencyMin = parseIEEE754Float(bytes[16] + " " + bytes[17] + " " + bytes[18] + " " + bytes[19]);
    
    emit waveTestDataUpdated();
    return true;
}

/**
 * @brief 启动突加负载测试
 *
 * 发送命令启动突加负载测试
 */
void GeneratorTestManager::startSuddenAddTest()
{
    sendHexMessage("55 01 62 B8");
}

/**
 * @brief 请求突加测试电压数据
 *
 * 发送命令请求读取突加负载测试的电压测试结果
 */
void GeneratorTestManager::requestSuddenAddTestData()
{
    sendHexMessage("55 01 64 BA");
}

/**
 * @brief 请求突加测试频率数据
 *
 * 发送命令请求读取突加负载测试的频率测试结果
 */
void GeneratorTestManager::requestSuddenAddFrequencyData()
{
    sendHexMessage("55 01 65 BB");
}

/**
 * @brief 请求突加测试电流数据
 *
 * 发送命令请求读取突加负载测试的电流测试结果
 */
void GeneratorTestManager::requestSuddenAddCurrentData()
{
    sendHexMessage("55 01 66 BC");
}

/**
 * @brief 停止突加负载测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopSuddenAddTest()
{
}

/**
 * @brief 解析突加测试电压响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突加负载测试电压响应，包括基准相、电压偏差、稳定时间、极值、倍率等
 */
bool GeneratorTestManager::parseSuddenAddTestResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "64") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenAddTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenAddTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenAddTestRefPhase = "C相";
    } else {
        m_suddenAddTestRefPhase = "未知";
    }
    
    m_suddenAddTestTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenAddTestStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenAddTestExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenAddTestMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenAddTestDataUpdated();
    return true;
}

/**
 * @brief 解析突加测试频率响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突加负载测试频率响应，包括基准相、频率偏差、稳定时间、极值、空载频率等
 */
bool GeneratorTestManager::parseSuddenAddFrequencyResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "65") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenAddTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenAddTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenAddTestRefPhase = "C相";
    } else {
        m_suddenAddTestRefPhase = "未知";
    }
    
    m_suddenAddFrequencyTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenAddFrequencyStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenAddFrequencyExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenAddRatedNoLoadFrequency = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenAddFrequencyDataUpdated();
    return true;
}

/**
 * @brief 解析突加测试电流响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突加负载测试电流响应，包括基准相、电流偏差、稳定时间、极值、倍率等
 */
bool GeneratorTestManager::parseSuddenAddCurrentResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "66") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenAddTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenAddTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenAddTestRefPhase = "C相";
    } else {
        m_suddenAddTestRefPhase = "未知";
    }
    
    m_suddenAddCurrentTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenAddCurrentStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenAddCurrentExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenAddCurrentMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenAddCurrentDataUpdated();
    return true;
}

/**
 * @brief 启动突卸负载测试
 *
 * 发送命令启动突卸负载测试
 */
void GeneratorTestManager::startSuddenLoadTest()
{
    sendHexMessage("55 01 63 B9");
}

/**
 * @brief 请求突卸测试电压数据
 *
 * 发送命令请求读取突卸负载测试的电压测试结果
 */
void GeneratorTestManager::requestSuddenLoadTestData()
{
    sendHexMessage("55 01 67 BD");
}

/**
 * @brief 请求突卸测试频率数据
 *
 * 发送命令请求读取突卸负载测试的频率测试结果
 */
void GeneratorTestManager::requestSuddenLoadFrequencyData()
{
    sendHexMessage("55 01 68 BE");
}

/**
 * @brief 请求突卸测试电流数据
 *
 * 发送命令请求读取突卸负载测试的电流测试结果
 */
void GeneratorTestManager::requestSuddenLoadCurrentData()
{
    sendHexMessage("55 01 69 BF");
}

/**
 * @brief 停止突卸负载测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopSuddenLoadTest()
{
}

/**
 * @brief 解析突卸测试电压响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突卸负载测试电压响应，包括基准相、电压偏差、稳定时间、极值、倍率等
 */
bool GeneratorTestManager::parseSuddenLoadTestResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "67") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenLoadTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenLoadTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenLoadTestRefPhase = "C相";
    } else {
        m_suddenLoadTestRefPhase = "未知";
    }
    
    m_suddenLoadTestTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenLoadTestStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenLoadTestExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenLoadTestMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenLoadTestDataUpdated();
    return true;
}

/**
 * @brief 解析突卸测试频率响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突卸负载测试频率响应，包括基准相、频率偏差、稳定时间、极值、空载频率等
 */
bool GeneratorTestManager::parseSuddenLoadFrequencyResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "68") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenLoadTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenLoadTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenLoadTestRefPhase = "C相";
    } else {
        m_suddenLoadTestRefPhase = "未知";
    }
    
    m_suddenLoadFrequencyTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenLoadFrequencyStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenLoadFrequencyExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenLoadRatedNoLoadFrequency = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenLoadFrequencyDataUpdated();
    return true;
}

/**
 * @brief 解析突卸测试电流响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析突卸负载测试电流响应，包括基准相、电流偏差、稳定时间、极值、倍率等
 */
bool GeneratorTestManager::parseSuddenLoadCurrentResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() < 17) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "69") {
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_suddenLoadTestRefPhase = "A相";
    } else if (refPhaseByte == 1) {
        m_suddenLoadTestRefPhase = "B相";
    } else if (refPhaseByte == 2) {
        m_suddenLoadTestRefPhase = "C相";
    } else {
        m_suddenLoadTestRefPhase = "未知";
    }
    
    m_suddenLoadCurrentTolerance = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    
    if (bytes.length() >= 412) {
        m_suddenLoadCurrentStableTime = (bytes[408].toInt(nullptr, 16) << 8) | bytes[409].toInt(nullptr, 16);
        m_suddenLoadCurrentExtremeValue = (bytes[410].toInt(nullptr, 16) << 8) | bytes[411].toInt(nullptr, 16);
    }
    
    if (bytes.length() >= 417) {
        m_suddenLoadCurrentMultiplier = parseIEEE754Float(bytes[412] + " " + bytes[413] + " " + bytes[414] + " " + bytes[415]);
    }
    
    emit suddenLoadCurrentDataUpdated();
    return true;
}

/**
 * @brief 启动谐波测试
 *
 * 发送命令启动谐波测试
 */
void GeneratorTestManager::startHarmonicTest()
{
    sendHexMessage("55 01 70 C6");
}

/**
 * @brief 请求谐波测试波形数据
 *
 * 发送命令请求读取谐波测试的波形数据
 */
void GeneratorTestManager::requestHarmonicWaveformData()
{
    sendHexMessage("55 01 71 C7");
}

/**
 * @brief 请求谐波测试数据
 *
 * 发送命令请求读取谐波测试的测试结果数据
 */
void GeneratorTestManager::requestHarmonicTestData()
{
    sendHexMessage("55 01 73 C9");
}

/**
 * @brief 请求退出谐波测试
 *
 * 发送命令退出谐波测试模式
 */
void GeneratorTestManager::requestHarmonicExit()
{
    sendHexMessage("55 01 72 C8");
}

/**
 * @brief 停止谐波测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopHarmonicTest()
{
}

/**
 * @brief 解析谐波测试波形响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析谐波测试波形响应，包括基准相、电压波形数据、电流波形数据等
 */
bool GeneratorTestManager::parseHarmonicWaveformResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    qDebug() << "[GeneratorTestManager] 解析波形数据，字节数:" << bytes.length();
    if (bytes.length() < 517) {
        qDebug() << "[GeneratorTestManager] 波形数据长度不足，需要517字节，实际:" << bytes.length();
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "71") {
        qDebug() << "[GeneratorTestManager] 波形数据格式错误，帧头或命令码不正确";
        return false;
    }
    
    int checksum = 0;
    for (int i = 0; i < 516; i++) {
        checksum += bytes[i].toInt(nullptr, 16);
    }
    checksum = checksum % 256;
    int receivedChecksum = bytes[516].toInt(nullptr, 16);
    qDebug() << "[GeneratorTestManager] 波形数据校验码 - 计算值:" << QString::number(checksum, 16) << ", 接收值:" << QString::number(receivedChecksum, 16);
    if (checksum != receivedChecksum) {
        qDebug() << "[GeneratorTestManager] 波形数据校验码错误";
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    if (refPhaseByte == 0) {
        m_harmonicTestRefPhase = "A 相";
    } else if (refPhaseByte == 1) {
        m_harmonicTestRefPhase = "B 相";
    } else if (refPhaseByte == 2) {
        m_harmonicTestRefPhase = "C 相";
    } else {
        m_harmonicTestRefPhase = "未知";
    }
    
    QVariantList voltageData;
    for (int i = 0; i < 128; i++) {
        int offset = 4 + i * 2;
        int value = (bytes[offset].toInt(nullptr, 16) << 8) | bytes[offset + 1].toInt(nullptr, 16);
        if (value > 32767) {
            value -= 65536;
        }
        voltageData.append(value);
    }
    
    QVariantList currentData;
    for (int j = 0; j < 128; j++) {
        int offsetJ = 260 + j * 2;
        int valueJ = (bytes[offsetJ].toInt(nullptr, 16) << 8) | bytes[offsetJ + 1].toInt(nullptr, 16);
        if (valueJ > 32767) {
            valueJ -= 65536;
        }
        currentData.append(valueJ);
    }
    
    m_harmonicTestVoltageWaveform = voltageData;
    m_harmonicTestCurrentWaveform = currentData;
    
    qDebug() << "[GeneratorTestManager] 波形数据解析成功，基准相:" << m_harmonicTestRefPhase;
    qDebug() << "[GeneratorTestManager] 电压波形数据长度:" << m_harmonicTestVoltageWaveform.length();
    qDebug() << "[GeneratorTestManager] 电流波形数据长度:" << m_harmonicTestCurrentWaveform.length();
    
    emit harmonicWaveformDataUpdated();
    return true;
}

/**
 * @brief 启动电压整定测试
 *
 * 发送命令启动电压整定测试
 */
void GeneratorTestManager::startVoltageCalibrationTest()
{
    sendHexMessage("55 01 76 CC");
}

/**
 * @brief 启动频率整定测试
 *
 * 发送命令启动频率整定测试
 */
void GeneratorTestManager::startFrequencyCalibrationTest()
{
    sendHexMessage("55 01 77 CD");
}

/**
 * @brief 请求整定测试数据
 *
 * 发送命令请求读取电压/频率整定测试的测试结果
 */
void GeneratorTestManager::requestCalibrationTestData()
{
    sendHexMessage("55 01 74 CA");
}

/**
 * @brief 停止整定测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopCalibrationTest()
{
}

/**
 * @brief 解析整定测试响应
 * @param hexData 接收到的十六进制数据
 * @return 解析成功返回true，否则返回false
 *
 * 解析整定测试响应，包括基准相、电压最大值/最小值、频率最大值/最小值等
 */
bool GeneratorTestManager::parseCalibrationTestResponse(const QString &hexData)
{
    QStringList bytes = hexData.trimmed().split(" ");
    if (bytes.length() != 21) {
        return false;
    }
    
    if (bytes[0] != "AA" || bytes[1] != "01" || bytes[2] != "74") {
        return false;
    }
    
    int checksum = 0;
    for (int i = 0; i < 20; i++) {
        checksum += bytes[i].toInt(nullptr, 16);
    }
    checksum = checksum % 256;
    int receivedChecksum = bytes[20].toInt(nullptr, 16);
    if (checksum != receivedChecksum) {
        qDebug() << "[GeneratorTestManager] 校验码错误: 计算值=" << QString::number(checksum, 16) << ", 接收值=" << QString::number(receivedChecksum, 16);
        return false;
    }
    
    int refPhaseByte = bytes[3].toInt(nullptr, 16);
    QString refPhaseStr;
    if (refPhaseByte == 0) {
        refPhaseStr = "A相";
    } else if (refPhaseByte == 1) {
        refPhaseStr = "B相";
    } else if (refPhaseByte == 2) {
        refPhaseStr = "C相";
    } else {
        refPhaseStr = "未知";
    }
    
    m_voltageCalibrationRefPhase = refPhaseStr;
    m_frequencyCalibrationRefPhase = refPhaseStr;
    
    m_voltageCalibrationUmax = parseIEEE754Float(bytes[4] + " " + bytes[5] + " " + bytes[6] + " " + bytes[7]);
    m_voltageCalibrationUmin = parseIEEE754Float(bytes[8] + " " + bytes[9] + " " + bytes[10] + " " + bytes[11]);
    m_frequencyCalibrationFmax = parseIEEE754Float(bytes[12] + " " + bytes[13] + " " + bytes[14] + " " + bytes[15]);
    m_frequencyCalibrationFmin = parseIEEE754Float(bytes[16] + " " + bytes[17] + " " + bytes[18] + " " + bytes[19]);
    
    emit calibrationTestDataUpdated();
    return true;
}

/**
 * @brief 启动波形录波测试
 *
 * 发送命令启动波形录波测试
 */
void GeneratorTestManager::startWaveformRecordTest()
{
    sendHexMessage("55 01 78 CE");
}

/**
 * @brief 停止波形录波测试
 *
 * （预留接口，当前实现为空）
 */
void GeneratorTestManager::stopWaveformRecordTest()
{
}

/**
 * @brief 发送参数命令
 * @param commandCode 命令码（十六进制，两位）
 * @param valueHex 参数值（十六进制，可选）
 *
 * 自动计算校验和并发送参数设置命令
 */
void GeneratorTestManager::sendParameterCommand(const QString &commandCode, const QString &valueHex)
{
    QString frame = "55 01 " + commandCode;
    if (!valueHex.isEmpty()) {
        frame += " " + valueHex;
    }
    QString checksum = calculateChecksum(frame);
    frame += " " + checksum;
    sendHexMessage(frame);
}

// =============================================================================
// 设备参数和三相参数Getter函数
// 用于获取设备参数、三相电压、电流、频率等测量值
// =============================================================================

QVariant GeneratorTestManager::getDevicePtRatio() const
{
    return m_devicePtRatio;
}

QVariant GeneratorTestManager::getDeviceCtRatio() const
{
    return m_deviceCtRatio;
}

QVariant GeneratorTestManager::getDeviceVoltageSteady() const
{
    return m_deviceVoltageSteady;
}

QVariant GeneratorTestManager::getDeviceCurrentSteady() const
{
    return m_deviceCurrentSteady;
}

QVariant GeneratorTestManager::getDeviceFrequencySteady() const
{
    return m_deviceFrequencySteady;
}

QVariant GeneratorTestManager::getDeviceRatedVoltage() const
{
    return m_deviceRatedVoltage;
}

QVariant GeneratorTestManager::getDeviceRatedCurrent() const
{
    return m_deviceRatedCurrent;
}

QVariant GeneratorTestManager::getDeviceRatedFrequency() const
{
    return m_deviceRatedFrequency;
}

QVariant GeneratorTestManager::getThreePhaseVoltageA() const
{
    return m_threePhaseVoltageA;
}

QVariant GeneratorTestManager::getThreePhaseVoltageB() const
{
    return m_threePhaseVoltageB;
}

QVariant GeneratorTestManager::getThreePhaseVoltageC() const
{
    return m_threePhaseVoltageC;
}

QVariant GeneratorTestManager::getThreePhaseCurrentA() const
{
    return m_threePhaseCurrentA;
}

QVariant GeneratorTestManager::getThreePhaseCurrentB() const
{
    return m_threePhaseCurrentB;
}

QVariant GeneratorTestManager::getThreePhaseCurrentC() const
{
    return m_threePhaseCurrentC;
}

QVariant GeneratorTestManager::getThreePhaseFrequency() const
{
    return m_threePhaseFrequency;
}

// =============================================================================
// 波动实验Getter函数
// 用于获取波动实验的测试结果（基准相、电压/频率最大值/最小值）
// =============================================================================

QString GeneratorTestManager::getWaveTestRefPhase() const
{
    return m_waveTestRefPhase;
}

QVariant GeneratorTestManager::getWaveTestVoltageMax() const
{
    return m_waveTestVoltageMax;
}

QVariant GeneratorTestManager::getWaveTestVoltageMin() const
{
    return m_waveTestVoltageMin;
}

QVariant GeneratorTestManager::getWaveTestFrequencyMax() const
{
    return m_waveTestFrequencyMax;
}

QVariant GeneratorTestManager::getWaveTestFrequencyMin() const
{
    return m_waveTestFrequencyMin;
}

// =============================================================================
// 突加实验Getter函数
// 用于获取突加负载实验的测试结果（基准相、偏差、稳定时间、极值、倍率等）
// =============================================================================

QString GeneratorTestManager::getSuddenAddTestRefPhase() const
{
    return m_suddenAddTestRefPhase;
}

QVariant GeneratorTestManager::getSuddenAddTestTolerance() const
{
    return m_suddenAddTestTolerance;
}

QVariant GeneratorTestManager::getSuddenAddTestStableTime() const
{
    return m_suddenAddTestStableTime;
}

QVariant GeneratorTestManager::getSuddenAddTestExtremeValue() const
{
    return m_suddenAddTestExtremeValue;
}

QVariant GeneratorTestManager::getSuddenAddTestMultiplier() const
{
    return m_suddenAddTestMultiplier;
}

QVariant GeneratorTestManager::getSuddenAddFrequencyTolerance() const
{
    return m_suddenAddFrequencyTolerance;
}

QVariant GeneratorTestManager::getSuddenAddFrequencyStableTime() const
{
    return m_suddenAddFrequencyStableTime;
}

QVariant GeneratorTestManager::getSuddenAddFrequencyExtremeValue() const
{
    return m_suddenAddFrequencyExtremeValue;
}

QVariant GeneratorTestManager::getSuddenAddRatedNoLoadFrequency() const
{
    return m_suddenAddRatedNoLoadFrequency;
}

QVariant GeneratorTestManager::getSuddenAddCurrentTolerance() const
{
    return m_suddenAddCurrentTolerance;
}

QVariant GeneratorTestManager::getSuddenAddCurrentStableTime() const
{
    return m_suddenAddCurrentStableTime;
}

QVariant GeneratorTestManager::getSuddenAddCurrentExtremeValue() const
{
    return m_suddenAddCurrentExtremeValue;
}

QVariant GeneratorTestManager::getSuddenAddCurrentMultiplier() const
{
    return m_suddenAddCurrentMultiplier;
}

// =============================================================================
// 突卸实验Getter函数
// 用于获取突卸负载实验的测试结果（基准相、偏差、稳定时间、极值、倍率等）
// =============================================================================

QString GeneratorTestManager::getSuddenLoadTestRefPhase() const
{
    return m_suddenLoadTestRefPhase;
}

QVariant GeneratorTestManager::getSuddenLoadTestTolerance() const
{
    return m_suddenLoadTestTolerance;
}

QVariant GeneratorTestManager::getSuddenLoadTestStableTime() const
{
    return m_suddenLoadTestStableTime;
}

QVariant GeneratorTestManager::getSuddenLoadTestExtremeValue() const
{
    return m_suddenLoadTestExtremeValue;
}

QVariant GeneratorTestManager::getSuddenLoadTestMultiplier() const
{
    return m_suddenLoadTestMultiplier;
}

QVariant GeneratorTestManager::getSuddenLoadFrequencyTolerance() const
{
    return m_suddenLoadFrequencyTolerance;
}

QVariant GeneratorTestManager::getSuddenLoadFrequencyStableTime() const
{
    return m_suddenLoadFrequencyStableTime;
}

QVariant GeneratorTestManager::getSuddenLoadFrequencyExtremeValue() const
{
    return m_suddenLoadFrequencyExtremeValue;
}

QVariant GeneratorTestManager::getSuddenLoadRatedNoLoadFrequency() const
{
    return m_suddenLoadRatedNoLoadFrequency;
}

QVariant GeneratorTestManager::getSuddenLoadCurrentTolerance() const
{
    return m_suddenLoadCurrentTolerance;
}

QVariant GeneratorTestManager::getSuddenLoadCurrentStableTime() const
{
    return m_suddenLoadCurrentStableTime;
}

QVariant GeneratorTestManager::getSuddenLoadCurrentExtremeValue() const
{
    return m_suddenLoadCurrentExtremeValue;
}

QVariant GeneratorTestManager::getSuddenLoadCurrentMultiplier() const
{
    return m_suddenLoadCurrentMultiplier;
}

// =============================================================================
// 谐波实验Getter函数
// 用于获取谐波实验的测试结果（基准相、电压/电流波形数据）
// =============================================================================

QString GeneratorTestManager::getHarmonicTestRefPhase() const
{
    return m_harmonicTestRefPhase;
}

QVariantList GeneratorTestManager::getHarmonicTestVoltageWaveform() const
{
    return m_harmonicTestVoltageWaveform;
}

QVariantList GeneratorTestManager::getHarmonicTestCurrentWaveform() const
{
    return m_harmonicTestCurrentWaveform;
}

// =============================================================================
// 整定实验Getter函数
// 用于获取电压/频率整定实验的测试结果（基准相、最大值/最小值）
// =============================================================================

QString GeneratorTestManager::getVoltageCalibrationRefPhase() const
{
    return m_voltageCalibrationRefPhase;
}

QVariant GeneratorTestManager::getVoltageCalibrationUmax() const
{
    return m_voltageCalibrationUmax;
}

QVariant GeneratorTestManager::getVoltageCalibrationUmin() const
{
    return m_voltageCalibrationUmin;
}

QString GeneratorTestManager::getFrequencyCalibrationRefPhase() const
{
    return m_frequencyCalibrationRefPhase;
}

QVariant GeneratorTestManager::getFrequencyCalibrationFmax() const
{
    return m_frequencyCalibrationFmax;
}

QVariant GeneratorTestManager::getFrequencyCalibrationFmin() const
{
    return m_frequencyCalibrationFmin;
}

/**
 * @brief 清空接收缓冲区
 *
 * 清空内部的接收数据缓冲区
 */
void GeneratorTestManager::clearReceiveBuffer()
{
    m_receiveBuffer.clear();
    qDebug() << "[GeneratorTestManager] 清空接收缓冲区";
}

/**
 * @brief 处理来自SerialRequestManager的数据（带超时重传机制）
 * @param data 接收到的数据
 *
 * 处理完整的响应数据，查找帧头、验证校验和、解析数据帧
 */
void GeneratorTestManager::onDataReceived(const QByteArray &data)
{
    qDebug() << "=================================";
    qDebug() << "【GeneratorTestManager::onDataReceived】开始处理";
    qDebug() << "【GeneratorTestManager】接收自SerialRequestManager的数据:" << data.size() << "字节，内容:" << byteArrayToHexString(data);
    qDebug() << "【GeneratorTestManager】注意：不追加，直接使用该数据作为当前缓冲区";
    
    // 重要！不应该再追加，因为SerialRequestManager已经给我们完整的累积缓冲区了
    m_receiveBuffer = data;
    
    qDebug() << "【GeneratorTestManager】当前缓冲区设置为:" << m_receiveBuffer.size() << "字节，内容:" << byteArrayToHexString(m_receiveBuffer);
    qDebug() << "=================================";
    
    int frameStartIndex = -1;
    
    for (int i = 0; i < m_receiveBuffer.size(); i++) {
        quint8 currentByte = static_cast<quint8>(m_receiveBuffer[i]);
        if (currentByte == 0xAA || currentByte == 0x55) {
            frameStartIndex = i;
            qDebug() << "[GeneratorTestManager] 找到帧头，位置:" << i << "字节:" << QString("%1").arg(currentByte, 2, 16, QChar('0')).toUpper();
            break;
        }
    }
    
    if (frameStartIndex == -1) {
        qDebug() << "[GeneratorTestManager] 未找到有效帧头，清空缓冲区";
        m_receiveBuffer.clear();
        return;
    }
    
    if (frameStartIndex > 0) {
        qDebug() << "[GeneratorTestManager] 跳过" << frameStartIndex << "字节无效数据";
        m_receiveBuffer = m_receiveBuffer.mid(frameStartIndex);
    }
    
    if (m_receiveBuffer.size() < 4) {
        qDebug() << "[GeneratorTestManager] 数据不足4字节，等待更多数据";
        return;
    }
    
    int expectedLength = getExpectedResponseLength(m_lastSentCommand);
    qDebug() << "[GeneratorTestManager] 最后发送的命令:" << m_lastSentCommand << "预期响应长度:" << expectedLength;
    if (expectedLength > 0) {
        qDebug() << "[GeneratorTestManager] 预期响应长度:" << expectedLength << "字节，当前长度:" << m_receiveBuffer.size() << "字节";
        if (m_receiveBuffer.size() < expectedLength) {
            qDebug() << "[GeneratorTestManager] 数据长度不足，等待更多数据";
            return;
        }
    }
    
    QByteArray frameData;
    
    if (expectedLength > 0) {
        // 所有有预期长度的命令都做校验码检查
        int frameStart = 0;
        
        while (frameStart + expectedLength <= m_receiveBuffer.size()) {
            QByteArray candidateFrame = m_receiveBuffer.mid(frameStart, expectedLength);
            
            // 计算校验码
            int checksum = 0;
            for (int i = 0; i < expectedLength - 1; i++) {
                checksum += static_cast<quint8>(candidateFrame[i]);
            }
            checksum = checksum % 256;
            quint8 receivedChecksum = static_cast<quint8>(candidateFrame[expectedLength - 1]);
            
            qDebug() << "[GeneratorTestManager] 检查帧，起始位置:" << frameStart 
                     << "计算校验码:" << QString("%1").arg(checksum, 2, 16, QChar('0')).toUpper()
                     << "接收校验码:" << QString("%1").arg(receivedChecksum, 2, 16, QChar('0')).toUpper();
            
            if (checksum == receivedChecksum) {
                qDebug() << "[GeneratorTestManager] 找到校验码正确的帧！";
                frameData = candidateFrame;
                break;
            }
            
            // 校验码不对，寻找下一个帧头
            frameStart++;
            while (frameStart + expectedLength <= m_receiveBuffer.size()) {
                quint8 currentByte = static_cast<quint8>(m_receiveBuffer[frameStart]);
                if (currentByte == 0xAA || currentByte == 0x55) {
                    qDebug() << "[GeneratorTestManager] 找到下一个帧头，位置:" << frameStart;
                    break;
                }
                frameStart++;
            }
        }
        
        if (frameData.isEmpty()) {
            qDebug() << "[GeneratorTestManager] 未找到校验码正确的帧，等待更多数据";
            return;
        }
    } else {
        // 没有预期长度的命令使用原来的逻辑
        frameData = m_receiveBuffer;
    }
    
    // 打印完整的原始缓冲区数据
    qDebug() << "=================================";
    qDebug() << "【GeneratorTestManager】处理完成，完整原始缓冲区总大小:" << m_receiveBuffer.size() << "字节";
    qDebug() << "【GeneratorTestManager】完整原始缓冲区内容（十六进制）:" << byteArrayToHexString(m_receiveBuffer);
    qDebug() << "【GeneratorTestManager】发出的完整帧数据:" << byteArrayToHexString(frameData);
    qDebug() << "=================================";
    
    QString hexString = byteArrayToHexString(frameData);
    m_receivedData = hexString;
    emit receivedDataChanged();
    emit dataReceived(hexString);
    qDebug() << "[GeneratorTestManager] 发出完整数据帧，大小:" << frameData.size() << "字节";
    m_receiveBuffer.clear();
}

/**
 * @brief 处理直接来自串口的数据（不带超时重传机制）
 * @param data 接收到的数据
 *
 * 追加接收数据，查找帧头、验证校验和、解析数据帧
 */
void GeneratorTestManager::onDirectDataReceived(const QByteArray &data)
{
    qDebug() << "=================================";
    qDebug() << "【GeneratorTestManager::onDirectDataReceived】开始处理";
    qDebug() << "【GeneratorTestManager】本次接收新数据块:" << data.size() << "字节，新数据内容:" << byteArrayToHexString(data);
    qDebug() << "【GeneratorTestManager】追加前总缓冲区:" << m_receiveBuffer.size() << "字节，缓冲区内容:" << byteArrayToHexString(m_receiveBuffer);
    
    m_receiveBuffer.append(data);
    
    qDebug() << "【GeneratorTestManager】追加后总缓冲区:" << m_receiveBuffer.size() << "字节，完整缓冲区内容:" << byteArrayToHexString(m_receiveBuffer);
    qDebug() << "=================================";
    
    while (m_receiveBuffer.size() > 0) {
        int frameStartIndex = -1;
        
        for (int i = 0; i < m_receiveBuffer.size(); i++) {
            quint8 currentByte = static_cast<quint8>(m_receiveBuffer[i]);
            if (currentByte == 0xAA || currentByte == 0x55) {
                frameStartIndex = i;
                qDebug() << "[GeneratorTestManager] 找到帧头，位置:" << i << "字节:" << QString("%1").arg(currentByte, 2, 16, QChar('0')).toUpper();
                break;
            }
        }
        
        if (frameStartIndex == -1) {
            qDebug() << "[GeneratorTestManager] 未找到有效帧头，清空缓冲区";
            m_receiveBuffer.clear();
            break;
        }
        
        if (frameStartIndex > 0) {
            qDebug() << "[GeneratorTestManager] 跳过" << frameStartIndex << "字节无效数据";
            m_receiveBuffer = m_receiveBuffer.mid(frameStartIndex);
        }
        
        if (m_receiveBuffer.size() < 4) {
            qDebug() << "[GeneratorTestManager] 数据不足4字节，等待更多数据";
            break;
        }
        
        int expectedLength = getExpectedResponseLength(m_lastSentCommand);
        qDebug() << "[GeneratorTestManager] onDirectDataReceived - 最后发送的命令:" << m_lastSentCommand << "预期响应长度:" << expectedLength;
        if (expectedLength > 0) {
            qDebug() << "[GeneratorTestManager] 预期响应长度:" << expectedLength << "字节，当前长度:" << m_receiveBuffer.size() << "字节";
            if (m_receiveBuffer.size() < expectedLength) {
                qDebug() << "[GeneratorTestManager] 数据长度不足，等待更多数据";
                break;
            }
        }
        
        QByteArray frameData;
        
        if (expectedLength > 0) {
            // 所有有预期长度的命令都做校验码检查
            int frameStart = 0;
            
            while (frameStart + expectedLength <= m_receiveBuffer.size()) {
                QByteArray candidateFrame = m_receiveBuffer.mid(frameStart, expectedLength);
                
                // 计算校验码
                int checksum = 0;
                for (int i = 0; i < expectedLength - 1; i++) {
                    checksum += static_cast<quint8>(candidateFrame[i]);
                }
                checksum = checksum % 256;
                quint8 receivedChecksum = static_cast<quint8>(candidateFrame[expectedLength - 1]);
                
                qDebug() << "[GeneratorTestManager] 检查帧，起始位置:" << frameStart 
                         << "计算校验码:" << QString("%1").arg(checksum, 2, 16, QChar('0')).toUpper()
                         << "接收校验码:" << QString("%1").arg(receivedChecksum, 2, 16, QChar('0')).toUpper();
                
                if (checksum == receivedChecksum) {
                    qDebug() << "[GeneratorTestManager] 找到校验码正确的帧！";
                    frameData = candidateFrame;
                    break;
                }
                
                // 校验码不对，寻找下一个帧头
                frameStart++;
                while (frameStart + expectedLength <= m_receiveBuffer.size()) {
                    quint8 currentByte = static_cast<quint8>(m_receiveBuffer[frameStart]);
                    if (currentByte == 0xAA || currentByte == 0x55) {
                        qDebug() << "[GeneratorTestManager] 找到下一个帧头，位置:" << frameStart;
                        break;
                    }
                    frameStart++;
                }
            }
            
            if (frameData.isEmpty()) {
                qDebug() << "[GeneratorTestManager] 未找到校验码正确的帧，等待更多数据";
                break;
            }
        } else {
            // 没有预期长度的命令使用原来的逻辑
            frameData = m_receiveBuffer;
        }
        
        // 打印完整的原始缓冲区数据
        qDebug() << "=================================";
        qDebug() << "【GeneratorTestManager】处理完成，完整原始缓冲区总大小:" << m_receiveBuffer.size() << "字节";
        qDebug() << "【GeneratorTestManager】完整原始缓冲区内容（十六进制）:" << byteArrayToHexString(m_receiveBuffer);
        qDebug() << "【GeneratorTestManager】发出的完整帧数据:" << byteArrayToHexString(frameData);
        qDebug() << "=================================";
        
        QString hexString = byteArrayToHexString(frameData);
        m_receivedData = hexString;
        emit receivedDataChanged();
        emit dataReceived(hexString);
        qDebug() << "[GeneratorTestManager] 发出完整数据帧，大小:" << frameData.size() << "字节";
        m_receiveBuffer.clear();
        break;
    }
}

/**
 * @brief 处理串口错误
 * @param error 错误信息
 *
 * 将串口错误转发给上层，发出errorOccurred信号
 */
void GeneratorTestManager::onSerialPortError(const QString &error)
{
    emit errorOccurred(error);
}

/**
 * @brief 将十六进制字符串转换为字节数组
 * @param hexString 十六进制字符串，字节之间用空格分隔
 * @return 转换后的字节数组
 *
 * 将类似"55 01 4A A0"的字符串转换为QByteArray
 */
QByteArray GeneratorTestManager::hexStringToByteArray(const QString &hexString)
{
    QByteArray result;
    QStringList hexList = hexString.split(" ", Qt::SkipEmptyParts);
    for (const QString &hexStr : hexList) {
        bool ok;
        quint8 byte = hexStr.toUInt(&ok, 16);
        if (ok) {
            result.append(static_cast<char>(byte));
        }
    }
    return result;
}

/**
 * @brief 将字节数组转换为十六进制字符串
 * @param data 要转换的字节数组
 * @return 转换后的十六进制字符串，字节之间用空格分隔
 *
 * 将QByteArray转换为类似"55 01 4A A0"的字符串
 */
QString GeneratorTestManager::byteArrayToHexString(const QByteArray &data)
{
    QString hexString;
    for (int i = 0; i < data.size(); ++i) {
        if (i > 0) {
            hexString += " ";
        }
        hexString += QString("%1").arg(static_cast<quint8>(data[i]), 2, 16, QChar('0')).toUpper();
    }
    return hexString;
}

/**
 * @brief 根据命令获取预期的响应长度
 * @param command 最后发送的命令字符串
 * @return 预期的响应字节数，0表示未知长度
 *
 * 根据命令码返回对应响应的预期长度，用于数据帧完整性检查
 */
int GeneratorTestManager::getExpectedResponseLength(const QString &command)
{
    QStringList parts = command.trimmed().split(" ", Qt::SkipEmptyParts);
    if (parts.size() < 3) {
        return 0;
    }
    
    QString cmdCode = parts[2];
    
    if (cmdCode == "4A") return 36;    // 设备参数响应
    if (cmdCode == "39") return 32;    // 三相参数响应
    if (cmdCode == "34") return 44;    // 静态三相参数响应
    if (cmdCode == "61") return 21;    // 波形测试响应
    if (cmdCode == "64") return 417;   // 突加测试响应
    if (cmdCode == "65") return 417;   // 突加频率响应
    if (cmdCode == "66") return 417;   // 突加电流响应
    if (cmdCode == "67") return 417;   // 突卸测试响应
    if (cmdCode == "68") return 417;   // 突卸频率响应
    if (cmdCode == "69") return 417;   // 突卸电流响应
    if (cmdCode == "71") return 517;   // 谐波波形响应
    if (cmdCode == "73") return 485;   // 谐波数据响应
    if (cmdCode == "74") return 21;    // 校准测试响应
    
    return 0;
}

/**
 * @brief 内部发送函数
 * @param data 要发送的数据
 * @param description 发送描述，用于调试日志
 *
 * 通过SerialRequestManager发送数据，使用正常优先级
 */
void GeneratorTestManager::sendInternal(const QByteArray &data, const QString &description)
{
    if (!m_requestManager) {
        return;
    }
    
    m_requestManager->addRequest(RequestPriority::Normal, data, this, SLOT(onDataReceived(QByteArray)));
    qDebug() << "[GeneratorTestManager] 发送:" << description;
}
