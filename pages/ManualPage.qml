import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    padding: 20
    background: Rectangle {
        color: "transparent"
    }

    ColumnLayout {
        spacing: 20
        anchors.fill: parent
        anchors.margins: 20

        Label {
            text: "操作说明"
            font.pixelSize: 30
            color: theme.textColor
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ECard {
                Layout.fillWidth: true
                padding: 20

                ColumnLayout {
                    spacing: 20

                    Text {
                        text: "一、首页操作说明"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "1. 串口控制区域："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 刷新串口：刷新可用串口列表\n   • 选择串口：从下拉列表中选择要使用的串口\n   • 波特率：选择串口通信波特率（默认9600）\n   • 校验位：选择校验方式（无校验/奇校验/偶校验）\n   • 串口开关：打开或关闭串口连接"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "2. 风机控制区域："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 风机开关1：控制从站1的风机运行状态\n   • 三相电气参数：显示/隐藏A、B、C三相的电压、电流、频率参数\n   • 急停：紧急停止设备，需重新开启风机开关1恢复"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "3. 电压和电流设置区域："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 电压输入：输入电压值，范围200~270V，步进1V\n   • 电流输入：输入1路电流值，范围0.1~40A，步进0.1A"
                        color: theme.textColor
                        font.pixelSize: 16
                    }



                    Text {
                        text: "三、发电机测试操作说明"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "1. 设置按钮（一键测试前必须配置）："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 设置参数（黄色按钮）：\n     功能：设置发电机的基本参数，这些参数会用于测试计算和报表生成\n     内容：包括额定电压、额定频率、机组容量、功率因数等\n     注意：带 * 号的为必填项，必须填写完整才能进行测试\n\n   • 报表设置（黄色按钮）：\n     功能：配置测试完成后导出的报表中包含哪些内容\n     内容：可以选择显示/隐藏技术规格、试验项目、稳态参数、测试结果、瞬态测试、实验结论等章节\n     用途：根据需要定制报表内容，只显示关心的数据\n\n   • 一键测试设置项（紫色按钮）：\n     功能：设置一键测试时要执行哪些测试项目、调整执行顺序，以及设置功率标签切换等待时间\n     内容：\n       - 测试项目选择：包括静态三相参数、波动实验、突加实验、突卸实验、谐波测试、电压校准、频率校准等\n       - 测试项目排序：使用↑↓按钮调整测试项目的执行顺序\n       - 功率标签切换等待时间：设置一键测试在不同功率标签之间切换时的等待时间（单位：分钟，范围0-60分钟，默认3分钟）\n     用途：可以根据实际需求，只执行需要的测试项目，节省测试时间，并根据设备响应速度调整标签切换等待时间"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "2. 测试功能按钮："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 当前功率一键测试：执行当前功率下的自动化测试\n   • 召测静态三相参数：读取并显示静态三相电参数\n   • 波动实验：进行功率波动测试\n   • 突加实验：进行突加负载测试\n   • 突卸实验：进行突卸负载测试\n   • 谐波测试：进行谐波测试\n   • 电压校准：执行电压校准\n   • 频率校准：执行频率校准\n   • 取消一键测试（红色按钮）：停止正在进行的一键测试\n   • 取消当前实验（红色按钮）：停止正在进行的单个实验（波动实验、突加实验、突卸实验、谐波测试、校准等）"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "3. 数据管理："
                        color: theme.textColor
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: "   • 测试数据记录：记录测试过程数据\n   • 清除数据：清除已记录的测试数据"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "四、发电机一键测试详细步骤"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "第1步：打开软件\n   • 双击桌面上的软件图标，启动本程序\n\n第2步：连接串口\n   • 在首页右上角，点击\"刷新串口\"按钮\n   • 点击\"选择串口\"下拉框，选择您的设备连接的串口\n   • 确认波特率设置为9600（默认即可）\n   • 确认校验位设置为\"无校验\"（默认即可）\n   • 点击\"串口开关\"，将其打开（开关变绿色表示已打开）\n\n第3步：启动风机\n   • 等待几秒钟，让串口连接稳定\n   • 点击\"风机开关1\"，将其打开（开关变绿色）\n   • 观察\"风机1状态\"指示灯，当显示\"风机1状态：运行\"时，表示风机已启动\n\n\n第4步：检查设备状态\n   • 确认\"温度1状态\"显示为\"正常\"\n   • 确保没有任何报警提示\n\n第5步：进入发电机测试页面\n   • 点击左侧导航栏的\"发电机测试\"图标（闪电图标）\n   • 进入发电机测试页面\n\n第6步：设置发电机参数\n   • 点击页面顶部的\"设置参数\"按钮（黄色按钮）\n   • 在弹出的对话框中，填写发电机的各项参数\n   • 带 * 号的为必填项，请确保填写完整\n   • 填写完成后点击确认保存\n\n第7步：设置报表参数\n   • 点击页面顶部的\"报表设置\"按钮（黄色按钮）\n   • 在弹出的对话框中，选择需要在报表中显示的内容\n   • 可以根据需要勾选或取消勾选各个选项\n   • 设置完成后点击确认\n\n第8步：设置测试项目和等待时间\n   • 点击页面顶部的\"一键测试设置项\"按钮（紫色按钮）\n   • 在弹出的对话框中，选择需要执行的测试项目\n   • 可以使用↑↓按钮调整测试项目的执行顺序\n   • 在\"功率标签切换等待时间（分钟）\"输入框中，输入切换标签时的等待时间（范围0-60分钟，默认3分钟）\n   • 设置完成后点击\"确定\"\n\n第9步：执行一键测试\n   • 确认以上三个设置都已完成\n   • 在发电机测试页面中，找到\"一键测试并导出报表\"按钮\n   • 点击该按钮开始自动化测试\n   • 等待测试完成，系统会自动执行所有测试项目\n   • 测试过程中请勿进行其他操作\n   • 如需要中途停止测试，可点击红色的\"取消一键测试\"按钮\n\n第10步：查看和导出测试结果\n   • 测试完成后，可以查看各项测试数据\n   • 如需保存测试报告，可使用导出功能\n\n第11步：测试结束后\n   • 测试完成后，如需停止设备\n   • 返回首页\n   • 关闭\"风机开关1\"\n   • 关闭\"串口开关\"\n   • 关闭软件"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "五、设置页面操作说明"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "   • 浅色/深色：切换界面主题（浅色模式/深色模式）\n\n   • 调试模式（重要警告）：\n     功能：开启后可无视风机状态打开负载设备，用于软件调试\n     ⚠️ 警告：除非您是软件开发人员，否则请勿随意开启此模式！\n         - 可能破坏设备的正常工作逻辑\n     - 可能引发安全隐患\n     建议：非本软件开发人员请勿点击，否则可能导致设备损坏"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "六、注意事项"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "1. 使用前请确保：\n   • 串口已正确连接并打开\n   • 风机开关1已打开且风机状态显示为运行\n   • 设备无高温报警\n\n2. 电压和电流输入限制：\n   • 电压输入：范围200~270V，步进1V\n   • 电流输入：范围0.1~40A，步进0.1A\n\n3. 紧急情况：\n   • 遇到紧急情况请立即点击\"急停\"按钮\n   • 急停后需重新开启风机开关1恢复操作\n\n4. 测试过程中：\n   • 一键测试进行时请勿操作其他按钮\n   • 保持串口连接稳定\n   • 确保风机持续运行\n\n5. 调试模式警告（非常重要）：\n   • 调试模式仅供软件开发人员使用\n   • 非开发人员请勿点击\"调试模式\"按钮\n   • 调试模式下可能绕过设备的安全保护机制\n   • 错误操作可能导致设备损坏或安全事故\n   • 如不小心开启了调试模式，请立即点击\"退出调试\"关闭"
                        color: theme.textColor
                        font.pixelSize: 16
                    }

                    Text {
                        text: "七、报表参数说明"
                        color: theme.textColor
                        font.pixelSize: 22
                        font.bold: true
                        Layout.topMargin: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.textColor
                        opacity: 0.3
                    }

                    Text {
                        text: "1. 技术规格：\n   • 包含发电机的基本参数信息，如额定电压、额定频率、机组容量等\n   • 默认为启用状态\n\n2. 测量电压和额定频率的稳态参数：\n   • 负载：负载百分比\n   • 功率：实际功率值\n   • UA、UB、UC：三相电压值\n   • IA、IB、IC：三相电流值\n   • 稳态功率因数：功率因数\n   • 频率F1：实际频率值\n   • 默认为启用状态\n\n3. 测试结果：\n   • 电压整定范围：电压整定的上下限范围\n   • 电压波形畸变率：电压波形的畸变程度\n   • 稳态电压偏差：稳态运行时的电压偏差\n   • 稳态频率带：稳态运行时的频率波动范围\n   • 频率降：负载变化时的频率下降值\n   • 默认为只启用电压整定范围\n\n4. 瞬态测试：\n   • 突加电压瞬态电压偏差：突加负载时的电压瞬态偏差（取所有测试中的最大值）\n   • 突加电压稳定时间：突加负载后电压稳定所需时间（取所有测试中的最大值）\n   • 突加频率瞬态频率偏差：突加负载时的频率瞬态偏差（取所有测试中的最大值）\n   • 突加频率稳定时间：突加负载后频率稳定所需时间（取所有测试中的最大值）\n   • 突卸电压瞬态电压偏差：突卸负载时的电压瞬态偏差（取所有测试中的最大值）\n   • 突卸电压稳定时间：突卸负载后电压稳定所需时间（取所有测试中的最大值）\n   • 突卸频率瞬态频率偏差：突卸负载时的频率瞬态偏差（取所有测试中的最大值）\n   • 突卸频率稳定时间：突卸负载后频率稳定所需时间（取所有测试中的最大值）\n   • 默认为全部启用状态\n\n5. 实验结论：\n   • 测试完成后的实验结论和评价\n   • 默认为启用状态"
                        color: theme.textColor
                        font.pixelSize: 16
                    }
                }
            }
        }
    }

}
