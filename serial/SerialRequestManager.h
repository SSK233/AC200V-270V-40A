// ============================================================================//
// 串口请求管理器头文件 (SerialRequestManager.h)
// 功能：统一管理Modbus和发电机测试的串口请求，实现优先级队列和请求间隔控制
// 版本：1.0.0
// 作者：skf
// 日期：2026-03-17
// ============================================================================//

#ifndef SERIALREQUESTMANAGER_H
#define SERIALREQUESTMANAGER_H

#include <QObject>
#include <QQueue>
#include <QTimer>
#include <QElapsedTimer>
#include <QMap>

class SerialPortManager;

/**
 * @brief 请求优先级枚举
 *
 * 用于控制请求队列的执行顺序，数值越小优先级越高
 */
enum class RequestPriority {
    Critical = 0,   ///< 紧急优先级（最高）
    High = 1,       ///< 高优先级
    Normal = 2,     ///< 正常优先级
    Low = 3         ///< 低优先级（最低）
};

/**
 * @brief 串口请求结构体
 *
 * 存储单个串口请求的完整信息，包括ID、优先级、数据和回调信息
 */
struct SerialRequest {
    int id;                         ///< 请求ID（唯一标识）
    RequestPriority priority;       ///< 请求优先级
    QByteArray data;                ///< 要发送的数据
    QObject *callbackReceiver;      ///< 回调接收者
    QByteArray callbackSlotName;    ///< 回调槽函数名称
};

/**
 * @brief 串口请求管理器类
 *
 * 该类负责统一管理Modbus和发电机测试的串口请求，主要功能包括：
 * - 优先级队列管理（Critical > High > Normal > Low）
 * - 请求间隔控制（防止发送过快）
 * - 响应超时机制
 * - 重复请求检测
 * - 数据收集定时器（收集完整响应）
 */
class SerialRequestManager : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param parent 父对象指针
     */
    explicit SerialRequestManager(QObject *parent = nullptr);
    
    /**
     * @brief 析构函数
     */
    ~SerialRequestManager();

    /**
     * @brief 设置串口管理器
     * @param manager 串口管理器指针
     */
    void setSerialPortManager(SerialPortManager *manager);

    /**
     * @brief 添加请求到队列
     * @param priority 请求优先级
     * @param data 要发送的数据
     * @param receiver 回调接收者（可选）
     * @param slotName 回调槽函数名称（可选，使用SLOT()宏）
     * @return 请求ID，失败返回-1（重复请求）
     *
     * 注意：如果数据与当前正在执行的请求或队列中的请求重复，会被拒绝
     */
    int addRequest(RequestPriority priority, const QByteArray &data,
                   QObject *receiver = nullptr, const char *slotName = nullptr);

    /**
     * @brief 取消指定ID的请求
     * @param requestId 要取消的请求ID
     */
    void cancelRequest(int requestId);
    
    /**
     * @brief 清除所有请求
     *
     * 清空请求队列，停止当前请求和所有定时器
     */
    void clearAllRequests();

    /**
     * @brief 设置请求间隔
     * @param ms 请求间隔（毫秒）
     */
    void setRequestInterval(int ms);
    
    /**
     * @brief 获取请求间隔
     * @return 请求间隔（毫秒）
     */
    int requestInterval() const;

    /**
     * @brief 检查管理器是否忙碌
     * @return 忙碌返回true，否则返回false
     *
     * 忙碌的条件：有当前正在执行的请求 或 请求队列不为空
     */
    bool isBusy() const;
    
    /**
     * @brief 手动完成当前请求
     *
     * 在某些特殊情况下可以手动调用此方法来完成当前请求
     */
    Q_INVOKABLE void completeCurrentRequestManually();

signals:
    /**
     * @brief 请求完成信号
     * @param requestId 完成的请求ID
     */
    void requestCompleted(int requestId);
    
    /**
     * @brief 请求失败信号
     * @param requestId 失败的请求ID
     * @param error 错误信息
     */
    void requestFailed(int requestId, const QString &error);

private slots:
    /**
     * @brief 处理请求队列
     *
     * 检查是否可以发送下一个请求，考虑请求间隔
     */
    void processQueue();
    
    /**
     * @brief 处理接收到的数据
     * @param data 接收到的数据
     *
     * 接收到数据后会追加到内部缓冲区，并通过回调通知接收者
     */
    void onBytesReceived(const QByteArray &data);
    
    /**
     * @brief 响应超时处理
     *
     * 如果在超时时间内没有完成请求，会调用失败处理
     */
    void onTimeout();
    
    /**
     * @brief 数据收集超时处理
     *
     * 数据收集定时器超时后，认为响应数据已完整收集
     */
    void onDataCollectTimeout();

private:
    /**
     * @brief 发送下一个请求
     *
     * 从队列中取出优先级最高的请求并发送
     */
    void sendNextRequest();
    
    /**
     * @brief 完成当前请求
     *
     * 标记当前请求完成，清理状态，发送完成信号，处理队列中的下一个请求
     */
    void completeCurrentRequest();
    
    /**
     * @brief 失败当前请求
     * @param error 错误信息
     *
     * 标记当前请求失败，清理状态，发送失败信号，处理队列中的下一个请求
     */
    void failCurrentRequest(const QString &error);

    SerialPortManager *m_serialPortManager;       ///< 串口管理器指针
    QList<SerialRequest> m_requestQueue;           ///< 请求队列（已按优先级排序）
    SerialRequest m_currentRequest;                ///< 当前正在执行的请求
    bool m_hasCurrentRequest;                       ///< 是否有当前正在执行的请求
    int m_nextRequestId;                            ///< 下一个请求ID
    int m_requestInterval;                          ///< 请求间隔（毫秒）
    QTimer *m_intervalTimer;                        ///< 请求间隔定时器
    QTimer *m_responseTimer;                        ///< 响应超时定时器
    QTimer *m_dataCollectTimer;                     ///< 数据收集定时器
    QElapsedTimer m_lastRequestTimer;               ///< 上次请求时间计时器
    QByteArray m_receiveBuffer;                     ///< 接收数据缓冲区

    /**
     * @brief 请求比较函数（用于队列排序）
     * @param a 请求A
     * @param b 请求B
     * @return 如果a的优先级高于b，返回true
     *
     * 按优先级从小到大排序（Critical < High < Normal < Low）
     */
    static bool compareRequests(const SerialRequest &a, const SerialRequest &b);
};

#endif // SERIALREQUESTMANAGER_H
