// ============================================================================//
// 数据记录器实现文件 (DataRecorder.cpp)
// 功能：记录和管理电气参数数据，支持定时记录、数据导出等功能
// 版本：1.0.0
// 作者：skf
// 日期：2026-02-26
// ============================================================================//

#include "DataRecorder.h"
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QPageLayout>
#include <QTextDocument>
#include <QTextTable>
#include <QTextCursor>

/**
 * @brief 构造函数
 * @param parent 父对象指针
 */
DataRecorder::DataRecorder(QObject *parent)
    : QObject(parent)
    , m_timer(nullptr)
    , m_recording(false)
    , m_interval(3)
    , m_lastVoltage(0.0)
    , m_lastCurrent(0.0)
    , m_lastPower(0.0)
{
    m_timer = new QTimer(this);
    connect(m_timer, &QTimer::timeout, this, &DataRecorder::onTimerTimeout);
}

/**
 * @brief 析构函数
 */
DataRecorder::~DataRecorder()
{
    if (m_timer) {
        m_timer->stop();
    }
}

/**
 * @brief 设置记录间隔
 * @param seconds 记录间隔（秒）
 */
void DataRecorder::setInterval(int seconds)
{
    if (m_interval != seconds && seconds > 0) {
        m_interval = seconds;
        emit intervalChanged();
        if (m_recording && m_timer) {
            m_timer->setInterval(m_interval * 1000);
        }
    }
}

/**
 * @brief 开始记录
 * @details 启动定时记录功能
 */
void DataRecorder::startRecording()
{
    if (m_recording) {
        return;
    }
    
    m_recording = true;
    m_timer->setInterval(m_interval * 1000);
    m_timer->start();
    
    qDebug() << "开始记录数据，间隔:" << m_interval << "秒";
    emit recordingChanged();
}

/**
 * @brief 停止记录
 * @details 停止定时记录功能
 */
void DataRecorder::stopRecording()
{
    if (!m_recording) {
        return;
    }
    
    m_recording = false;
    m_timer->stop();
    
    qDebug() << "停止记录数据，共记录" << m_records.size() << "条";
    emit recordingChanged();
}

/**
 * @brief 添加数据记录
 * @param voltage 电压值
 * @param current 电流值
 * @param power 功率值
 */
void DataRecorder::addData(double voltage, double current, double power)
{
    m_lastVoltage = voltage;
    m_lastCurrent = current;
    m_lastPower = power;
}

/**
 * @brief 定时器超时槽函数
 * @details 定时记录数据
 */
void DataRecorder::onTimerTimeout()
{
    DataRecord record;
    record.timestamp = QDateTime::currentDateTime();
    record.voltage = m_lastVoltage;
    record.current = m_lastCurrent;
    record.power = m_lastPower;
    
    m_records.append(record);
    
    QString timeStr = record.timestamp.toString("yyyy-MM-dd HH:mm:ss");
    qDebug() << QString("记录数据 [%1] 电压: %2 V, 电流: %3 A, 功率: %4 kW")
                    .arg(timeStr)
                    .arg(record.voltage, 0, 'f', 2)
                    .arg(record.current, 0, 'f', 2)
                    .arg(record.power, 0, 'f', 3);
    
    emit dataAdded(timeStr, record.voltage, record.current, record.power);
    emit recordCountChanged();
}

/**
 * @brief 导出测试报表到文本文件
 * @param filePath 文件路径
 * @param reportContent 报表内容
 */
void DataRecorder::exportTestReport(const QString &filePath, const QString &reportContent)
{
    QString actualPath = filePath;
    if (actualPath.isEmpty()) {
        QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        QString fileName = QString("机组稳态性能测试报告_%1.txt")
                               .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
        actualPath = QDir(desktopPath).filePath(fileName);
    }
    
    QFile file(actualPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "无法打开文件:" << actualPath;
        emit exportFinished(false, actualPath);
        return;
    }
    
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    
    QByteArray bom = "\xEF\xBB\xBF";
    file.write(bom);
    
    out << reportContent;
    
    file.close();
    
    qDebug() << "测试报表已导出到:" << actualPath;
    emit exportFinished(true, actualPath);
}

/**
 * @brief 导出数据到Excel文件
 * @param filePath 文件路径
 */
void DataRecorder::exportToExcel(const QString &filePath)
{
    QString actualPath = filePath;
    if (actualPath.isEmpty()) {
        QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        QString fileName = QString("数据报表_%1.csv")
                               .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
        actualPath = QDir(desktopPath).filePath(fileName);
    }
    
    QFile file(actualPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "无法打开文件:" << actualPath;
        emit exportFinished(false, actualPath);
        return;
    }
    
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    
    QByteArray bom = "\xEF\xBB\xBF";
    file.write(bom);
    
    out << "时间,电压(V),电流(A),功率(kW)\n";
    
    for (const DataRecord &record : m_records) {
        out << "'" << record.timestamp.toString("yyyy-MM-dd HH:mm:ss") << ","
            << QString::number(record.voltage, 'f', 2) << ","
            << QString::number(record.current, 'f', 2) << ","
            << QString::number(record.power, 'f', 3) << "\n";
    }
    
    file.close();
    
    qDebug() << "数据已导出到:" << actualPath;
    qDebug() << "共导出" << m_records.size() << "条记录";
    emit exportFinished(true, actualPath);
}

/**
 * @brief 清空数据
 * @details 清除所有记录的数据
 */
void DataRecorder::clearData()
{
    m_records.clear();
    qDebug() << "已清除所有记录数据";
    emit recordCountChanged();
}

/**
 * @brief 获取记录数量
 * @return 记录数量
 */
int DataRecorder::recordCount() const
{
    return m_records.size();
}

/**
 * @brief 导出测试报表到PDF文件
 * @param filePath 文件路径
 * @param reportContent 报表内容（CSV格式）
 */
void DataRecorder::exportTestReportToPdf(const QString &filePath, const QString &reportContent)
{
    QString actualPath = filePath;
    if (actualPath.isEmpty()) {
        QString desktopPath = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        QString fileName = QString("机组稳态性能测试报告_%1.pdf")
                               .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
        actualPath = QDir(desktopPath).filePath(fileName);
    }
    
    if (!actualPath.endsWith(".pdf", Qt::CaseInsensitive)) {
        actualPath += ".pdf";
    }
    
    QPdfWriter pdfWriter(actualPath);
    pdfWriter.setPageSize(QPageSize(QPageSize::A4));
    pdfWriter.setPageOrientation(QPageLayout::Landscape);
    pdfWriter.setPageMargins(QMarginsF(15, 15, 15, 15));
    pdfWriter.setResolution(600);
    pdfWriter.setTitle("机组稳态性能测试报告");
    pdfWriter.setCreator("AC200V-270V-40A");
    
    QPainter painter(&pdfWriter);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::TextAntialiasing);
    
    qreal pageWidth = pdfWriter.width();
    qreal pageHeight = pdfWriter.height();
    qreal margin = 40;
    qreal contentWidth = pageWidth - margin * 2;
    qreal yPos = margin;
    
    QFont titleFont("SimSun", 24, QFont::Bold);
    QFont sectionFont("SimSun", 16, QFont::Bold);
    QFont contentFont("SimSun", 10);
    QFont headerFont("SimSun", 11, QFont::Bold);
    
    QStringList lines = reportContent.split("\n");
    
    int maxCols = 0;
    QList<QStringList> allCells;
    for (const QString &line : lines) {
        QStringList cells = line.split(",");
        allCells.append(cells);
        maxCols = qMax(maxCols, cells.size());
    }
    
    QList<int> techSpecLineIndices;
    for (int i = 0; i < allCells.size(); ++i) {
        const QStringList &cells = allCells[i];
        if (!cells.isEmpty()) {
            QString firstCell = cells[0].trimmed();
            if (firstCell.startsWith("1、机组型号") || firstCell.startsWith("2、额定频率") || 
                firstCell.startsWith("3、引擎型号") || firstCell.startsWith("4、电机型号")) {
                techSpecLineIndices.append(i);
            }
        }
    }
    
    QList<qreal> techSpecColMaxWidths;
    if (!techSpecLineIndices.isEmpty()) {
        int maxTechCols = 0;
        for (int idx : techSpecLineIndices) {
            maxTechCols = qMax(maxTechCols, allCells[idx].size());
        }
        techSpecColMaxWidths.resize(maxTechCols, 0);
        
        painter.setFont(contentFont);
        for (int idx : techSpecLineIndices) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < techSpecColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    techSpecColMaxWidths[i] = qMax(techSpecColMaxWidths[i], minWidth);
                } else {
                    techSpecColMaxWidths[i] = qMax(techSpecColMaxWidths[i], 20.0);
                }
            }
        }
        
        qreal totalTechWidth = 0;
        for (qreal w : techSpecColMaxWidths) {
            totalTechWidth += w;
        }
        
        if (totalTechWidth > 0 && totalTechWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalTechWidth;
            qreal extraPerCol = extraWidth / techSpecColMaxWidths.size();
            for (int i = 0; i < techSpecColMaxWidths.size(); ++i) {
                techSpecColMaxWidths[i] += extraPerCol;
            }
        } else if (totalTechWidth > contentWidth) {
            qreal scale = contentWidth / totalTechWidth;
            for (int i = 0; i < techSpecColMaxWidths.size(); ++i) {
                techSpecColMaxWidths[i] *= scale;
            }
        }
    }
    
    QList<int> steadyParamLineIndices;
    QList<int> testResultLineIndices;
    bool inSteadyParamSection = false;
    for (int i = 0; i < allCells.size(); ++i) {
        const QStringList &cells = allCells[i];
        if (!cells.isEmpty()) {
            QString firstCell = cells[0].trimmed();
            QString fullCellText = firstCell;
            for (int j = 1; j < cells.size(); ++j) {
                fullCellText += cells[j].trimmed();
            }
            
            // 检查是否是章节标题（包含中文数字前缀）
            bool isSectionTitle = firstCell.contains("（") && firstCell.contains("）");
            
            if (isSectionTitle && fullCellText.contains("测量电压和额定频率的稳态参数")) {
                inSteadyParamSection = true;
            } else if (firstCell.startsWith("测试结果") && inSteadyParamSection) {
                inSteadyParamSection = false;
                testResultLineIndices.append(i);
                // 如果下一行是测试结果的第二行，也记录下来
                if (i + 1 < allCells.size()) {
                    const QStringList &nextCells = allCells[i + 1];
                    if (!nextCells.isEmpty() && nextCells[0].trimmed().isEmpty()) {
                        testResultLineIndices.append(i + 1);
                    }
                }
            } else if (inSteadyParamSection && !firstCell.isEmpty()) {
                steadyParamLineIndices.append(i);
            }
        }
    }
    
    QList<qreal> testResultColMaxWidths;
    if (!testResultLineIndices.isEmpty()) {
        int maxTestResultCols = 0;
        for (int idx : testResultLineIndices) {
            maxTestResultCols = qMax(maxTestResultCols, allCells[idx].size());
        }
        testResultColMaxWidths.resize(maxTestResultCols, 0);
        
        painter.setFont(headerFont);
        for (int idx : testResultLineIndices) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < testResultColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    testResultColMaxWidths[i] = qMax(testResultColMaxWidths[i], minWidth);
                } else {
                    testResultColMaxWidths[i] = qMax(testResultColMaxWidths[i], 20.0);
                }
            }
        }
        painter.setFont(contentFont);
        
        qreal totalTestResultWidth = 0;
        for (qreal w : testResultColMaxWidths) {
            totalTestResultWidth += w;
        }
        
        if (totalTestResultWidth > 0 && totalTestResultWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalTestResultWidth;
            qreal extraPerCol = extraWidth / testResultColMaxWidths.size();
            for (int i = 0; i < testResultColMaxWidths.size(); ++i) {
                testResultColMaxWidths[i] += extraPerCol;
            }
        } else if (totalTestResultWidth > contentWidth) {
            qreal scale = contentWidth / totalTestResultWidth;
            for (int i = 0; i < testResultColMaxWidths.size(); ++i) {
                testResultColMaxWidths[i] *= scale;
            }
        }
    }
    
    QList<qreal> steadyParamColMaxWidths;
    if (!steadyParamLineIndices.isEmpty()) {
        int maxSteadyCols = 0;
        for (int idx : steadyParamLineIndices) {
            maxSteadyCols = qMax(maxSteadyCols, allCells[idx].size());
        }
        steadyParamColMaxWidths.resize(maxSteadyCols, 0);
        
        painter.setFont(contentFont);
        for (int idx : steadyParamLineIndices) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < steadyParamColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    steadyParamColMaxWidths[i] = qMax(steadyParamColMaxWidths[i], minWidth);
                } else {
                    steadyParamColMaxWidths[i] = qMax(steadyParamColMaxWidths[i], 20.0);
                }
            }
        }
        
        for (int i = 0; i < steadyParamColMaxWidths.size(); ++i) {
            if (i > 7) {
                steadyParamColMaxWidths[i] = steadyParamColMaxWidths[i] * 0.4;
            }
        }
        
        qreal totalSteadyWidth = 0;
        for (qreal w : steadyParamColMaxWidths) {
            totalSteadyWidth += w;
        }
        
        if (totalSteadyWidth > 0 && totalSteadyWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalSteadyWidth;
            qreal extraPerCol = extraWidth / steadyParamColMaxWidths.size();
            for (int i = 0; i < steadyParamColMaxWidths.size(); ++i) {
                steadyParamColMaxWidths[i] += extraPerCol;
            }
        } else if (totalSteadyWidth > contentWidth) {
            qreal scale = contentWidth / totalSteadyWidth;
            for (int i = 0; i < steadyParamColMaxWidths.size(); ++i) {
                steadyParamColMaxWidths[i] *= scale;
            }
        }
    }
    
    QList<int> testItemLineIndicesGroup1;
    QList<int> testItemLineIndicesGroup2;
    QList<int> titleAndStandardLineIndices;
    QList<int> transientTestLineIndices;
    bool inTestItemSection = false;
    bool inTransientTestSection = false;
    int testItemLineCount = 0;
    for (int i = 0; i < allCells.size(); ++i) {
        const QStringList &cells = allCells[i];
        if (!cells.isEmpty()) {
            QString firstCell = cells[0].trimmed();
            QString fullLine = cells.join("").trimmed();
            QString fullCellText = firstCell;
            for (int j = 1; j < cells.size(); ++j) {
                fullCellText += cells[j].trimmed();
            }
            
            // 检查是否是章节标题（包含中文数字前缀）
            bool isSectionTitle = firstCell.contains("（") && firstCell.contains("）");
            
            if (fullLine.contains("机组稳态性能测试报告") || fullLine.contains("标准：GB/T")) {
                titleAndStandardLineIndices.append(i);
            } else if (isSectionTitle && fullCellText.contains("试验项目")) {
                inTestItemSection = true;
                testItemLineCount = 0;
            } else if (isSectionTitle && fullCellText.contains("测量电压和额定频率的稳态参数") && inTestItemSection) {
                inTestItemSection = false;
            } else if (inTestItemSection && !firstCell.isEmpty()) {
                testItemLineCount++;
                if (testItemLineCount <= 3) {
                    testItemLineIndicesGroup1.append(i);
                } else {
                    testItemLineIndicesGroup2.append(i);
                }
            } else if (isSectionTitle && fullCellText.contains("瞬态测试")) {
                inTransientTestSection = true;
            } else if (inTransientTestSection && firstCell.startsWith("实验结论")) {
                inTransientTestSection = false;
            } else if (inTransientTestSection && !firstCell.isEmpty()) {
                transientTestLineIndices.append(i);
            }
        }
    }
    
    QList<qreal> transientTestColMaxWidths;
    if (!transientTestLineIndices.isEmpty()) {
        int maxTransientTestCols = 0;
        for (int idx : transientTestLineIndices) {
            maxTransientTestCols = qMax(maxTransientTestCols, allCells[idx].size());
        }
        transientTestColMaxWidths.resize(maxTransientTestCols, 0);
        
        painter.setFont(headerFont);
        for (int idx : transientTestLineIndices) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < transientTestColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    transientTestColMaxWidths[i] = qMax(transientTestColMaxWidths[i], minWidth);
                } else {
                    transientTestColMaxWidths[i] = qMax(transientTestColMaxWidths[i], 20.0);
                }
            }
        }
        painter.setFont(contentFont);
        
        qreal totalTransientTestWidth = 0;
        for (qreal w : transientTestColMaxWidths) {
            totalTransientTestWidth += w;
        }
        
        if (totalTransientTestWidth > 0 && totalTransientTestWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalTransientTestWidth;
            qreal extraPerCol = extraWidth / transientTestColMaxWidths.size();
            for (int i = 0; i < transientTestColMaxWidths.size(); ++i) {
                transientTestColMaxWidths[i] += extraPerCol;
            }
        } else if (totalTransientTestWidth > contentWidth) {
            qreal scale = contentWidth / totalTransientTestWidth;
            for (int i = 0; i < transientTestColMaxWidths.size(); ++i) {
                transientTestColMaxWidths[i] *= scale;
            }
        }
    }
    
    QList<qreal> testItemGroup1ColMaxWidths;
    if (!testItemLineIndicesGroup1.isEmpty()) {
        int maxCols = 0;
        for (int idx : testItemLineIndicesGroup1) {
            maxCols = qMax(maxCols, allCells[idx].size());
        }
        testItemGroup1ColMaxWidths.resize(maxCols, 0);
        
        painter.setFont(contentFont);
        for (int idx : testItemLineIndicesGroup1) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < testItemGroup1ColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    testItemGroup1ColMaxWidths[i] = qMax(testItemGroup1ColMaxWidths[i], minWidth);
                } else {
                    testItemGroup1ColMaxWidths[i] = qMax(testItemGroup1ColMaxWidths[i], 20.0);
                }
            }
        }
        
        qreal totalWidth = 0;
        for (qreal w : testItemGroup1ColMaxWidths) {
            totalWidth += w;
        }
        
        if (totalWidth > 0 && totalWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalWidth;
            qreal extraPerCol = extraWidth / testItemGroup1ColMaxWidths.size();
            for (int i = 0; i < testItemGroup1ColMaxWidths.size(); ++i) {
                testItemGroup1ColMaxWidths[i] += extraPerCol;
            }
        } else if (totalWidth > contentWidth) {
            qreal scale = contentWidth / totalWidth;
            for (int i = 0; i < testItemGroup1ColMaxWidths.size(); ++i) {
                testItemGroup1ColMaxWidths[i] *= scale;
            }
        }
    }
    
    QList<qreal> testItemGroup2ColMaxWidths;
    if (!testItemLineIndicesGroup2.isEmpty()) {
        int maxCols = 0;
        for (int idx : testItemLineIndicesGroup2) {
            maxCols = qMax(maxCols, allCells[idx].size());
        }
        testItemGroup2ColMaxWidths.resize(maxCols, 0);
        
        painter.setFont(contentFont);
        for (int idx : testItemLineIndicesGroup2) {
            const QStringList &cells = allCells[idx];
            for (int i = 0; i < cells.size() && i < testItemGroup2ColMaxWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    testItemGroup2ColMaxWidths[i] = qMax(testItemGroup2ColMaxWidths[i], minWidth);
                } else {
                    testItemGroup2ColMaxWidths[i] = qMax(testItemGroup2ColMaxWidths[i], 20.0);
                }
            }
        }
        
        qreal totalWidth = 0;
        for (qreal w : testItemGroup2ColMaxWidths) {
            totalWidth += w;
        }
        
        if (totalWidth > 0 && totalWidth < contentWidth) {
            qreal extraWidth = contentWidth - totalWidth;
            qreal extraPerCol = extraWidth / testItemGroup2ColMaxWidths.size();
            for (int i = 0; i < testItemGroup2ColMaxWidths.size(); ++i) {
                testItemGroup2ColMaxWidths[i] += extraPerCol;
            }
        } else if (totalWidth > contentWidth) {
            qreal scale = contentWidth / totalWidth;
            for (int i = 0; i < testItemGroup2ColMaxWidths.size(); ++i) {
                testItemGroup2ColMaxWidths[i] *= scale;
            }
        }
    }
    
    for (int lineIdx = 0; lineIdx < allCells.size(); ++lineIdx) {
        const QStringList &cells = allCells[lineIdx];
        
        if (cells.size() == 1 && cells[0].trimmed().isEmpty()) {
            yPos += 12;
            continue;
        }
        
        bool isTitle = false;
        bool isSection = false;
        bool isHeader = false;
        QString firstCell = cells.isEmpty() ? "" : cells[0].trimmed();
        
        if (firstCell.contains("机组稳态性能测试报告")) {
            isTitle = true;
        } else if ((firstCell.contains("（") && firstCell.contains("）")) || firstCell.startsWith("实验结论")) {
            isSection = true;
        } else if (firstCell == "项目" || firstCell == "负载" || firstCell == "测试结果" || 
                   firstCell.startsWith("1、") || firstCell.startsWith("2、") || firstCell.startsWith("3、") || firstCell.startsWith("4、")) {
            isHeader = true;
        }
        
        if (isTitle) {
            painter.setFont(titleFont);
            QString titleText = "";
            for (const QString &cell : cells) {
                if (!cell.trimmed().isEmpty()) {
                    titleText = cell.trimmed();
                    break;
                }
            }
            painter.drawText(QRectF(margin, yPos, contentWidth, 50), Qt::AlignCenter, titleText);
            yPos += 60;
            painter.setFont(contentFont);
            continue;
        }
        
        if (isSection) {
            painter.setFont(sectionFont);
            painter.setPen(QPen(Qt::black, 2));
            painter.drawLine(QPointF(margin, yPos), QPointF(margin + 300, yPos));
            painter.drawText(QPointF(margin, yPos + painter.fontMetrics().ascent() + 5), firstCell);
            yPos += painter.fontMetrics().height() + 15;
            painter.setPen(QPen(Qt::black, 1));
            painter.setFont(contentFont);
            continue;
        }
        
        bool isTechSpecLine = techSpecLineIndices.contains(lineIdx);
        bool isSteadyParamLine = steadyParamLineIndices.contains(lineIdx);
        bool isTestResultLine = testResultLineIndices.contains(lineIdx);
        int numCols = cells.size();
        QList<qreal> currentRowColWidths(numCols, 0);
        
        bool isUAUBUCLine = false;
        if (!cells.isEmpty()) {
            QString lineText = cells.join("");
            if (lineText.contains("UA") && lineText.contains("UB") && lineText.contains("UC") &&
                lineText.contains("IA") && lineText.contains("IB") && lineText.contains("IC")) {
                isUAUBUCLine = true;
            }
        }
        
        qreal maxCellHeight = painter.fontMetrics().height() + 10;
        if (isUAUBUCLine) {
            maxCellHeight = painter.fontMetrics().height() * 4 + 15;
        }
        qreal xPos = margin;
        
        if (isTechSpecLine) {
            for (int i = 0; i < cells.size() && i < techSpecColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = techSpecColMaxWidths[i];
            }
        } else if (isSteadyParamLine) {
            for (int i = 0; i < cells.size() && i < steadyParamColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = steadyParamColMaxWidths[i];
            }
        } else if (isTestResultLine) {
            for (int i = 0; i < cells.size() && i < testResultColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = testResultColMaxWidths[i];
            }
        } else if (transientTestLineIndices.contains(lineIdx)) {
            for (int i = 0; i < cells.size() && i < transientTestColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = transientTestColMaxWidths[i];
            }
        } else if (testItemLineIndicesGroup1.contains(lineIdx)) {
            for (int i = 0; i < cells.size() && i < testItemGroup1ColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = testItemGroup1ColMaxWidths[i];
            }
        } else if (testItemLineIndicesGroup2.contains(lineIdx)) {
            for (int i = 0; i < cells.size() && i < testItemGroup2ColMaxWidths.size(); ++i) {
                currentRowColWidths[i] = testItemGroup2ColMaxWidths[i];
            }
        } else {
            // 对于header行，使用headerFont计算宽度
            if (isHeader) {
                painter.setFont(headerFont);
            }
            for (int i = 0; i < cells.size(); ++i) {
                QString cellText = cells[i].trimmed();
                if (!cellText.isEmpty()) {
                    qreal minWidth = painter.fontMetrics().horizontalAdvance(cellText) + 20;
                    currentRowColWidths[i] = minWidth;
                } else {
                    currentRowColWidths[i] = 20;
                }
            }
            // 恢复contentFont
            if (isHeader) {
                painter.setFont(contentFont);
            }
            
            qreal totalMinWidth = 0;
            for (qreal w : currentRowColWidths) {
                totalMinWidth += w;
            }
            
            if (totalMinWidth > 0 && totalMinWidth < contentWidth) {
                qreal extraWidth = contentWidth - totalMinWidth;
                qreal extraPerCol = extraWidth / numCols;
                for (int i = 0; i < numCols; ++i) {
                    currentRowColWidths[i] += extraPerCol;
                }
            } else if (totalMinWidth > contentWidth) {
                qreal scale = contentWidth / totalMinWidth;
                for (int i = 0; i < numCols; ++i) {
                    currentRowColWidths[i] *= scale;
                }
            }
        }
        
        for (int i = 0; i < cells.size(); ++i) {
            QString cellText = cells[i].trimmed();
            if (!cellText.isEmpty() && i < currentRowColWidths.size()) {
                qreal cw = currentRowColWidths[i];
                qreal textRectHeight = isUAUBUCLine ? painter.fontMetrics().height() * 10 : maxCellHeight * 3;
                QRectF textRect(xPos, yPos, cw, textRectHeight);
                QRectF boundingRect = painter.boundingRect(textRect, Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop, cellText);
                maxCellHeight = qMax(maxCellHeight, boundingRect.height() + 10);
            }
            if (i < currentRowColWidths.size()) {
                xPos += currentRowColWidths[i];
            }
        }
        
        xPos = margin;
        bool hasContent = false;
        for (const QString &cell : cells) {
            if (!cell.trimmed().isEmpty()) {
                hasContent = true;
                break;
            }
        }
        
        if (hasContent) {
            for (int i = 0; i < cells.size() && i < currentRowColWidths.size(); ++i) {
                QString cellText = cells[i].trimmed();
                qreal cw = currentRowColWidths[i];
                
                painter.drawRect(QRectF(xPos, yPos, cw, maxCellHeight));
                
                if (!cellText.isEmpty()) {
                    QRectF textRect(xPos + 6, yPos + 5, cw - 12, maxCellHeight - 10);
                    bool shouldCenter = isHeader || testItemLineIndicesGroup1.contains(lineIdx) || 
                                        testItemLineIndicesGroup2.contains(lineIdx) || 
                                        titleAndStandardLineIndices.contains(lineIdx) ||
                                        transientTestLineIndices.contains(lineIdx) ||
                                        isSteadyParamLine ||
                                        isTestResultLine;
                    if (shouldCenter) {
                        painter.setFont(headerFont);
                        painter.drawText(textRect, Qt::TextWordWrap | Qt::AlignCenter | Qt::AlignVCenter, cellText);
                        painter.setFont(contentFont);
                    } else {
                        painter.drawText(textRect, Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignVCenter, cellText);
                    }
                }
                
                xPos += cw;
            }
            
            yPos += maxCellHeight + 3;
        } else {
            yPos += painter.fontMetrics().height() + 6;
        }
        
        if (yPos > pageHeight - margin - 50) {
            pdfWriter.newPage();
            yPos = margin;
        }
    }
    
    painter.end();
    
    qDebug() << "测试报表PDF已导出到:" << actualPath;
    emit exportFinished(true, actualPath);
}
