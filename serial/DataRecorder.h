// ============================================================================//
// 数据记录器头文件 (DataRecorder.h)
// 功能：记录和管理电气参数数据，支持定时记录、数据导出等功能
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

#ifndef DATARECORDER_H
#define DATARECORDER_H

#include <QObject>
#include <QTimer>
#include <QDateTime>
#include <QVector>
#include <QFile>
#include <QTextStream>
#include <QPdfWriter>
#include <QPainter>

/**
 * @struct DataRecord
 * @brief 数据记录结构体
 * @details 存储单条电气参数记录，包含时间戳和各项电气参数
 */
struct DataRecord {
    QDateTime timestamp;  // 记录时间戳
    double voltage;       // 电压值
    double current;       // 电流值
    double power;         // 功率值
};

/**
 * @class DataRecorder
 * @brief 数据记录器类
 * @details 负责电气参数数据的记录、管理和导出功能
 * @inherits QObject
 */
class DataRecorder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(int recordCount READ recordCount NOTIFY recordCountChanged)

public:
    /**
     * @brief 构造函数
     * @param parent 父对象指针
     */
    explicit DataRecorder(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~DataRecorder();

    /**
     * @brief 获取当前记录状态
     * @return 是否正在记录
     */
    bool recording() const { return m_recording; }
    
    /**
     * @brief 获取记录间隔
     * @return 记录间隔（秒）
     */
    int interval() const { return m_interval; }
    
    /**
     * @brief 设置记录间隔
     * @param seconds 记录间隔（秒）
     */
    void setInterval(int seconds);

    /**
     * @brief 开始记录
     * @details 启动定时记录功能
     */
    Q_INVOKABLE void startRecording();
    
    /**
     * @brief 停止记录
     * @details 停止定时记录功能
     */
    Q_INVOKABLE void stopRecording();
    
    /**
     * @brief 导出数据到Excel文件
     * @param filePath 文件路径
     */
    Q_INVOKABLE void exportToExcel(const QString &filePath);
    
    /**
     * @brief 导出测试报表到文本文件
     * @param filePath 文件路径
     * @param reportContent 报表内容
     */
    Q_INVOKABLE void exportTestReport(const QString &filePath, const QString &reportContent);
    
    /**
     * @brief 导出测试报表到PDF文件
     * @param filePath 文件路径
     * @param reportContent 报表内容（CSV格式）
     */
    Q_INVOKABLE void exportTestReportToPdf(const QString &filePath, const QString &reportContent);
    
    /**
     * @brief 添加数据记录
     * @param voltage 电压值
     * @param current 电流值
     * @param power 功率值
     */
    Q_INVOKABLE void addData(double voltage, double current, double power);
    
    /**
     * @brief 清空数据
     * @details 清除所有记录的数据
     */
    Q_INVOKABLE void clearData();
    
    /**
     * @brief 获取记录数量
     * @return 记录数量
     */
    Q_INVOKABLE int recordCount() const;

signals:
    /**
     * @brief 记录状态变化信号
     */
    void recordingChanged();
    
    /**
     * @brief 记录间隔变化信号
     */
    void intervalChanged();
    
    /**
     * @brief 记录数量变化信号
     */
    void recordCountChanged();
    
    /**
     * @brief 数据添加信号
     * @param timestamp 时间戳
     * @param voltage 电压值
     * @param current 电流值
     * @param power 功率值
     */
    void dataAdded(const QString &timestamp, double voltage, double current, double power);
    
    /**
     * @brief 导出完成信号
     * @param success 是否成功
     * @param filePath 文件路径
     */
    void exportFinished(bool success, const QString &filePath);

private slots:
    /**
     * @brief 定时器超时槽函数
     * @details 定时记录数据
     */
    void onTimerTimeout();

private:
    QTimer *m_timer;         // 定时器，用于定时记录数据
    QVector<DataRecord> m_records;  // 数据记录列表
    bool m_recording;        // 记录状态
    int m_interval;          // 记录间隔（秒）
    double m_lastVoltage;    // 上次记录的电压值
    double m_lastCurrent;    // 上次记录的电流值
    double m_lastPower;      // 上次记录的功率值
};

#endif
