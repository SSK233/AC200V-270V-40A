// ============================================================================//
// 串口请求管理器实现文件 (SerialRequestManager.cpp)
// 功能：统一管理Modbus和发电机测试的串口请求，实现优先级队列和请求间隔控制
// 版本：1.0.0
// 作者：skf
// 日期：2026-03-17
// ============================================================================//

#include "SerialRequestManager.h"
#include "SerialPortManager.h"
#include <QDebug>
#include <algorithm>

/**
 * @brief 构造函数
 * @param parent 父对象指针
 *
 * 初始化所有定时器和成员变量，设置默认请求间隔为100ms
 */
SerialRequestManager::SerialRequestManager(QObject *parent)
    : QObject(parent)
    , m_serialPortManager(nullptr)
    , m_hasCurrentRequest(false)
    , m_nextRequestId(1)
    , m_requestInterval(100)
{
    // 请求间隔定时器：控制请求发送间隔
    m_intervalTimer = new QTimer(this);
    m_intervalTimer->setSingleShot(true);
    connect(m_intervalTimer, &QTimer::timeout, this, &SerialRequestManager::processQueue);

    // 响应超时定时器：默认1秒超时
    m_responseTimer = new QTimer(this);
    m_responseTimer->setSingleShot(true);
    m_responseTimer->setInterval(1000);
    connect(m_responseTimer, &QTimer::timeout, this, &SerialRequestManager::onTimeout);
    
    // 数据收集定时器：收集完整响应数据，默认100ms
    m_dataCollectTimer = new QTimer(this);
    m_dataCollectTimer->setSingleShot(true);
    m_dataCollectTimer->setInterval(100);
    connect(m_dataCollectTimer, &QTimer::timeout, this, &SerialRequestManager::onDataCollectTimeout);

    // 启动上次请求时间计时器
    m_lastRequestTimer.start();
}

/**
 * @brief 析构函数
 */
SerialRequestManager::~SerialRequestManager()
{
}

/**
 * @brief 设置串口管理器
 * @param manager 串口管理器指针
 *
 * 连接串口管理器的bytesReceived信号，用于接收数据
 */
void SerialRequestManager::setSerialPortManager(SerialPortManager *manager)
{
    if (m_serialPortManager) {
        disconnect(m_serialPortManager, &SerialPortManager::bytesReceived,
                   this, &SerialRequestManager::onBytesReceived);
    }

    m_serialPortManager = manager;

    if (m_serialPortManager) {
        connect(m_serialPortManager, &SerialPortManager::bytesReceived,
                this, &SerialRequestManager::onBytesReceived);
    }
}

/**
 * @brief 打印队列内容（调试函数）
 * @param title 标题
 * @param queue 请求队列
 *
 * 用于调试，打印队列中的所有请求信息
 */
void printQueueContent(const QString &title, const QList<SerialRequest> &queue)
{
    qDebug() << "===  \"" << title << "\"  ===";
    qDebug() << "队列长度:" << queue.size();
    for (int i = 0; i < queue.size(); ++i) {
        const SerialRequest &req = queue[i];
        QString priorityStr;
        switch (req.priority) {
            case RequestPriority::Critical: priorityStr = "Critical"; break;
            case RequestPriority::High: priorityStr = "High"; break;
            case RequestPriority::Normal: priorityStr = "Normal"; break;
            case RequestPriority::Low: priorityStr = "Low"; break;
        }
        qDebug() << "  [ " << i << " ] ID:" << req.id 
                 << "优先级: \"" << priorityStr << "\"" 
                 << "数据: \"" << req.data.toHex(' ') << "\" (" << req.data.size() << "字节)";
    }
    qDebug() << "=========================";
}

/**
 * @brief 添加请求到队列
 * @param priority 请求优先级
 * @param data 要发送的数据
 * @param receiver 回调接收者（可选）
 * @param slotName 回调槽函数名称（可选）
 * @return 请求ID，失败返回-1（重复请求）
 *
 * 检测重复请求：如果数据与当前请求或队列中的请求重复，返回-1
 * 添加后自动按优先级排序队列
 * 如果当前没有正在执行的请求且间隔定时器未运行，立即处理队列
 */
int SerialRequestManager::addRequest(RequestPriority priority, const QByteArray &data,
                                      QObject *receiver, const char *slotName)
{
    // 检查是否与当前正在执行的请求重复
    if (m_hasCurrentRequest && m_currentRequest.data == data) {
        return -1;
    }
    
    // 检查是否与队列中的请求重复
    for (const SerialRequest &req : m_requestQueue) {
        if (req.data == data) {
            return -1;
        }
    }
    
    // 创建新请求
    SerialRequest request;
    request.id = m_nextRequestId++;
    request.priority = priority;
    request.data = data;
    request.callbackReceiver = receiver;
    
    // 处理槽函数名称（去掉SLOT宏的前缀和参数）
    if (slotName) {
        QByteArray slot = slotName;
        if (slot.startsWith("1") || slot.startsWith("2")) {
            slot = slot.mid(1);
        }
        int parenthesisPos = slot.indexOf('(');
        if (parenthesisPos != -1) {
            slot = slot.left(parenthesisPos);
        }
        request.callbackSlotName = slot;
    } else {
        request.callbackSlotName.clear();
    }

    // 添加到队列并按优先级排序
    m_requestQueue.append(request);
    std::sort(m_requestQueue.begin(), m_requestQueue.end(), compareRequests);

    // 打印调试信息
    QString priorityStr;
    switch (priority) {
        case RequestPriority::Critical: priorityStr = "Critical"; break;
        case RequestPriority::High: priorityStr = "High"; break;
        case RequestPriority::Normal: priorityStr = "Normal"; break;
        case RequestPriority::Low: priorityStr = "Low"; break;
    }
    
    qDebug() << "[SerialRequestManager] 添加请求 ID:" << request.id
             << "优先级: \"" << priorityStr << "\""
             << "数据: \"" << data.toHex(' ') << "\" (" << data.size() << "字节)";
    
    printQueueContent("当前队列状态", m_requestQueue);

    // 如果当前没有请求且间隔定时器未运行，立即处理队列
    if (!m_hasCurrentRequest && !m_intervalTimer->isActive()) {
        processQueue();
    }

    return request.id;
}

/**
 * @brief 取消指定ID的请求
 * @param requestId 要取消的请求ID
 *
 * 从队列中移除指定ID的请求
 */
void SerialRequestManager::cancelRequest(int requestId)
{
    for (int i = 0; i < m_requestQueue.size(); ++i) {
        if (m_requestQueue[i].id == requestId) {
            m_requestQueue.removeAt(i);
            break;
        }
    }
}

/**
 * @brief 清除所有请求
 *
 * 清空请求队列，停止所有定时器，重置当前请求状态
 */
void SerialRequestManager::clearAllRequests()
{
    m_requestQueue.clear();
    m_hasCurrentRequest = false;
    m_responseTimer->stop();
    m_intervalTimer->stop();
}

/**
 * @brief 设置请求间隔
 * @param ms 请求间隔（毫秒）
 */
void SerialRequestManager::setRequestInterval(int ms)
{
    m_requestInterval = ms;
}

/**
 * @brief 获取请求间隔
 * @return 请求间隔（毫秒）
 */
int SerialRequestManager::requestInterval() const
{
    return m_requestInterval;
}

/**
 * @brief 检查管理器是否忙碌
 * @return 忙碌返回true，否则返回false
 *
 * 忙碌的条件：有当前正在执行的请求 或 请求队列不为空
 */
bool SerialRequestManager::isBusy() const
{
    return m_hasCurrentRequest || !m_requestQueue.isEmpty();
}

/**
 * @brief 手动完成当前请求
 *
 * 在某些特殊情况下可以手动调用此方法来完成当前请求
 */
void SerialRequestManager::completeCurrentRequestManually()
{
    completeCurrentRequest();
}

/**
 * @brief 处理请求队列
 *
 * 检查是否可以发送下一个请求：
 * 1. 如果有当前正在执行的请求，返回
 * 2. 如果队列为空，返回
 * 3. 检查上次请求到现在的时间是否超过请求间隔
 * 4. 如果未超过，启动间隔定时器等待
 * 5. 如果已超过，发送下一个请求
 */
void SerialRequestManager::processQueue()
{
    if (m_hasCurrentRequest) {
        return;
    }

    if (m_requestQueue.isEmpty()) {
        return;
    }

    // 检查请求间隔
    qint64 elapsed = m_lastRequestTimer.elapsed();
    if (elapsed < m_requestInterval) {
        int remaining = m_requestInterval - static_cast<int>(elapsed);
        m_intervalTimer->start(remaining);
        return;
    }

    // 发送下一个请求
    sendNextRequest();
}

/**
 * @brief 发送下一个请求
 *
 * 从队列中取出优先级最高的请求：
 * 1. 从队列中取出第一个请求
 * 2. 设置为当前请求
 * 3. 清空接收缓冲区
 * 4. 停止数据收集定时器
 * 5. 通过串口发送数据
 * 6. 如果发送成功，启动超时定时器
 * 7. 如果发送失败，标记请求失败
 */
void SerialRequestManager::sendNextRequest()
{
    if (m_requestQueue.isEmpty() || !m_serialPortManager) {
        return;
    }

    m_currentRequest = m_requestQueue.takeFirst();
    m_hasCurrentRequest = true;
    m_receiveBuffer.clear();
    m_dataCollectTimer->stop();

    qDebug() << "[SerialRequestManager] 发送请求 ID:" << m_currentRequest.id;

    bool success = m_serialPortManager->writeBytes(m_currentRequest.data);
    if (success) {
        m_lastRequestTimer.restart();
        m_responseTimer->start();
    } else {
        failCurrentRequest("写入串口失败");
    }
}

/**
 * @brief 处理接收到的数据
 * @param data 接收到的数据
 *
 * 接收到数据后的处理流程：
 * 1. 如果没有当前请求，忽略数据
 * 2. 将数据追加到内部缓冲区
 * 3. 如果有回调接收者和槽函数，通过回调通知接收者
 * 4. 启动数据收集定时器（等待更多数据）
 */
void SerialRequestManager::onBytesReceived(const QByteArray &data)
{
    qDebug() << "=================================";
    qDebug() << "【SerialRequestManager::onBytesReceived】开始处理";
    qDebug() << "【SerialRequestManager】本次接收新数据:" << data.size() << "字节，内容:" << data.toHex(' ');
    qDebug() << "【SerialRequestManager】追加前内部缓冲区:" << m_receiveBuffer.size() << "字节，内容:" << m_receiveBuffer.toHex(' ');
    
    // 如果没有当前请求，忽略数据
    if (!m_hasCurrentRequest) {
        qDebug() << "【SerialRequestManager】没有当前请求，忽略数据";
        qDebug() << "=================================";
        return;
    }

    // 追加数据到缓冲区
    m_receiveBuffer.append(data);
    
    qDebug() << "【SerialRequestManager】追加后内部缓冲区:" << m_receiveBuffer.size() << "字节，完整内容:" << m_receiveBuffer.toHex(' ');
    qDebug() << "【SerialRequestManager】将调用回调函数，传递内部缓冲区内容";

    // 调用回调
    if (m_currentRequest.callbackReceiver && !m_currentRequest.callbackSlotName.isEmpty()) {
        QMetaObject::invokeMethod(m_currentRequest.callbackReceiver,
                                   m_currentRequest.callbackSlotName.constData(),
                                   Qt::DirectConnection,
                                   Q_ARG(QByteArray, m_receiveBuffer));
    }
    
    qDebug() << "【SerialRequestManager】回调调用完成，启动数据收集定时器";
    qDebug() << "=================================";
    
    // 启动数据收集定时器（等待更多数据）
    m_dataCollectTimer->start();
}

/**
 * @brief 数据收集超时处理
 *
 * 数据收集定时器超时后，认为响应数据已完整收集，完成当前请求
 */
void SerialRequestManager::onDataCollectTimeout()
{
    completeCurrentRequest();
}

/**
 * @brief 响应超时处理
 *
 * 响应超时定时器超时后，标记当前请求失败
 */
void SerialRequestManager::onTimeout()
{
    if (m_hasCurrentRequest) {
        failCurrentRequest("响应超时");
    }
}

/**
 * @brief 完成当前请求
 *
 * 完成当前请求的处理流程：
 * 1. 如果没有当前请求，返回
 * 2. 保存请求ID
 * 3. 标记为无当前请求
 * 4. 停止响应超时定时器
 * 5. 停止数据收集定时器
 * 6. 发送请求完成信号
 * 7. 如果队列不为空，启动间隔定时器处理下一个请求
 */
void SerialRequestManager::completeCurrentRequest()
{
    if (!m_hasCurrentRequest) {
        return;
    }

    int requestId = m_currentRequest.id;
    m_hasCurrentRequest = false;
    m_responseTimer->stop();
    m_dataCollectTimer->stop();

    qDebug() << "[SerialRequestManager] 请求完成 ID:" << requestId;
    emit requestCompleted(requestId);

    // 如果队列不为空，启动间隔定时器
    if (!m_requestQueue.isEmpty()) {
        m_intervalTimer->start(m_requestInterval);
    }
}

/**
 * @brief 失败当前请求
 * @param error 错误信息
 *
 * 失败当前请求的处理流程：
 * 1. 如果没有当前请求，返回
 * 2. 保存请求ID
 * 3. 标记为无当前请求
 * 4. 停止响应超时定时器
 * 5. 停止数据收集定时器
 * 6. 发送请求失败信号
 * 7. 如果队列不为空，启动间隔定时器处理下一个请求
 */
void SerialRequestManager::failCurrentRequest(const QString &error)
{
    if (!m_hasCurrentRequest) {
        return;
    }

    int requestId = m_currentRequest.id;
    m_hasCurrentRequest = false;
    m_responseTimer->stop();
    m_dataCollectTimer->stop();

    qDebug() << "[SerialRequestManager] 请求失败 ID:" << requestId << "错误:" << error;
    emit requestFailed(requestId, error);

    // 如果队列不为空，启动间隔定时器
    if (!m_requestQueue.isEmpty()) {
        m_intervalTimer->start(m_requestInterval);
    }
}

/**
 * @brief 请求比较函数（用于队列排序）
 * @param a 请求A
 * @param b 请求B
 * @return 如果a的优先级高于b，返回true
 *
 * 按优先级从小到大排序（Critical < High < Normal < Low）
 */
bool SerialRequestManager::compareRequests(const SerialRequest &a, const SerialRequest &b)
{
    return static_cast<int>(a.priority) < static_cast<int>(b.priority);
}
