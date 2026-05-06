// Qt Quick 核心渲染模块 - 提供QML的基础渲染能力
import QtQuick

// Qt Quick 标准控件模块 - 提供窗口、按钮等UI组件
import QtQuick.Controls

// Qt Quick 布局管理模块 - 提供锚点、线性布局等布局能力
import QtQuick.Layouts

// 自定义 EvolveUI 组件库 - 提供主题、自定义列表等自定义组件
import EvolveUI

// 主应用程序窗口 - 作为整个应用的根容器，包含所有UI元素
ApplicationWindow {
    // 窗口初始宽度：
    width: 1070

    // 窗口最小宽度：
    minimumWidth: 1070

    // 窗口初始高度：
    height: 650

    // 窗口启动时立即显示
    visible: true

    // 窗口标题栏显示的文本内容
    title: "AC200V-270V-40A"

    // 窗口背景色使用主题定义的主色调
    color: theme.primaryColor

    // 分步运行模式状态 - 与首页功率设置互斥
    property bool stepRunActive: false

    // 字体加载器 - 用于加载Font Awesome图标字体
    FontLoader {
        id: iconFont  // 字体加载器的唯一标识符
        // 字体文件路径（从资源文件中加载）
        source: "qrc:/new/prefix1/fonts/fontawesome-free-6.7.2-desktop/otfs/Font Awesome 6 Free-Solid-900.otf"
    }

    // 主题组件 - 提供应用程序的主题配置（如颜色、字体等）
    ETheme { id: theme }

    // 波形数据管理器 - 全局共享，用于存储电压/电流/功率历史数据（已注释）
    // WaveformDataManager { id: waveformDataManager }

    // 分割视图 - 将窗口分为多个可调整大小的区域
    SplitView {
        // 填充整个父容器（即ApplicationWindow）
        anchors.fill: parent
        
        // 分割手柄样式 - 设置为透明且宽度为0，实现无分割线效果
        handle: Rectangle {
            implicitWidth: 0  // 手柄隐式宽度为0
            color: "transparent"  // 手柄颜色为透明
        }

        // 侧边栏面板 - 包含导航菜单
        Pane {
            id: sidebar  // 侧边栏的唯一标识符
            
            // 侧边栏展开状态 - 默认为展开
            property bool expanded: true
            
            // 侧边栏折叠时的宽度
            property int collapsedWidth: 85
            
            // 侧边栏展开时的宽度
            property int expandedWidth: 150
            
            // 侧边栏内边距设置为0
            padding: 0
            
            // 侧边栏背景 - 使用主题定义的次色调
            background: Rectangle {
                color: theme.secondaryColor
            }
            
            // 侧边栏隐式宽度 - 根据展开状态动态调整
            implicitWidth: expanded ? expandedWidth : collapsedWidth
            
            // 禁用裁剪 - 允许内容超出边界
            clip: false
            
            // 分割视图中侧边栏的最小宽度
            SplitView.minimumWidth: collapsedWidth
            
            // 分割视图中侧边栏的最大宽度
            SplitView.maximumWidth: expandedWidth
            
            // 分割视图中侧边栏的首选宽度
            SplitView.preferredWidth: implicitWidth

            // 宽度变化动画 - 当侧边栏宽度改变时应用动画效果
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 240  // 动画持续时间：240毫秒
                    easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                }
            }

            // 悬停处理器已移除 - 侧边栏保持固定展开状态

            // 导航列表模型 - 定义导航菜单项数据
            ListModel {
                id: navModel  // 列表模型的唯一标识符

                // 导航菜单项：首页
                ListElement {
                    display: "首页"  // 显示文本
                    iconChar: "\uf015"  // Font Awesome图标字符（home图标）
                }

                // 导航菜单项：分步运行（已隐藏）
                // ListElement {
                //     display: "分步"  // 显示文本
                //     iconChar: "\uf017"  // Font Awesome图标字符（clock图标）
                // }

                // 导航菜单项：发电机测试（已隐藏）
                // ListElement {
                //     display: "发电机测试"  // 显示文本
                //     iconChar: "\uf0e7"  // Font Awesome图标字符（flash图标）
                // }

                // 导航菜单项：波形图（已注释）
                // ListElement {
                //     display: "波形图"  // 显示文本
                //     iconChar: "\uf201"  // Font Awesome图标字符（波形图图标）
                // }

                // 导航菜单项：设置
                ListElement {
                    display: "设置"  // 显示文本
                    iconChar: "\uf013"  // Font Awesome图标字符（cog图标）
                }
                // 导航菜单项：操作说明
                ListElement {
                    display: "操作说明"  // 显示文本
                    iconChar: "\uf05a"  // Font Awesome图标字符（info-circle图标）
                }
            }

            // 垂直布局 - 用于组织侧边栏内容
            ColumnLayout {
                // 填充整个父容器（即侧边栏）
                anchors.fill: parent
                
                // 子项间距设置为10像素
                spacing: 10

                // 自定义列表组件 - 显示导航菜单
                EList {
                    // 隐藏列表背景
                    backgroundVisible: false
                    
                    // 使用导航列表模型作为数据源
                    model: navModel
                    
                    // 根据侧边栏展开状态决定是否显示文本
                    textShown: sidebar.expanded
                    
                    // 水平方向填充布局
                    Layout.fillWidth: true
                    
                    // 垂直方向填充布局
                    Layout.fillHeight: true
                    
                    // 列表项点击事件处理 - 根据点击的索引切换内容页面
                    onItemClicked: function(index, data) { 
                        contentStack.currentIndex = index 
                    }
                }

                // 占位项 - 用于将导航列表推到顶部
                Item { 
                    Layout.fillHeight: true 
                }
            }
        }

        // 内容堆栈布局 - 用于管理不同页面的切换
        StackLayout {
            id: contentStack  // 堆栈布局的唯一标识符
            
            // 当前显示的页面索引 - 默认为首页（索引0）
            currentIndex: 0
            
            // 当页面切换时，关闭首页的三相电参数卡片
            onCurrentIndexChanged: {
                if (homePage && currentIndex !== 0) {
                    homePage.showThreePhaseParams = false
                }
                // 发电机测试页面已隐藏，注释掉相关代码
                // if (generatorTestPage && currentIndex !== 1) {
                //     generatorTestPage.showThreePhaseParams = false
                // }
            }
            
            // 启用裁剪 - 防止内容超出边界
            clip: true
            
            // 水平方向填充布局
            Layout.fillWidth: true

            // 首页容器 - 包含HomePage组件
            Item {
                // 水平方向填充布局
                Layout.fillWidth: true
                
                // 垂直方向填充布局
                Layout.fillHeight: true
                
                // 透明度 - 根据可见性动态调整（用于页面切换动画）
                opacity: visible ? 1 : 0
                
                // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
                y: visible ? 0 : 12
                
                // 透明度变化动画
                Behavior on opacity {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // Y轴位置变化动画
                Behavior on y {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // 首页组件 - 填充整个容器
                HomePage { id: homePage; anchors.fill: parent; stepRunPage: stepRunPage; stepRunActive: stepRunActive }
            }

            // 分步运行页容器 - 包含StepRunPage组件（已隐藏）
            // Item {
            //     // 水平方向填充布局
            //     Layout.fillWidth: true
            //
            //     // 垂直方向填充布局
            //     Layout.fillHeight: true
            //
            //     // 透明度 - 根据可见性动态调整（用于页面切换动画）
            //     opacity: visible ? 1 : 0
            //
            //     // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
            //     y: visible ? 0 : 12
            //
            //     // 透明度变化动画
            //     Behavior on opacity {
            //         NumberAnimation {
            //             duration: 240
            //             easing.type: Easing.OutCubic
            //         }
            //     }
            //
            //     // Y轴位置变化动画
            //     Behavior on y {
            //         NumberAnimation {
            //             duration: 240
            //             easing.type: Easing.OutCubic
            //         }
            //     }
            //
            //     // 分步运行页组件 - 填充整个容器
            //     StepRunPage {
            //         id: stepRunPage
            //         anchors.fill: parent
            //         homePage: homePage
            //     }
            // }

            // 发电机测试页容器 - 包含GeneratorTestPage组件（已隐藏）
            // Item {
            //     // 水平方向填充布局
            //     Layout.fillWidth: true

            //     // 垂直方向填充布局
            //     Layout.fillHeight: true

            //     // 透明度 - 根据可见性动态调整（用于页面切换动画）
            //     opacity: visible ? 1 : 0

            //     // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
            //     y: visible ? 0 : 12

            //     // 透明度变化动画
            //     Behavior on opacity {
            //         NumberAnimation {
            //             duration: 240
            //             easing.type: Easing.OutCubic
            //         }
            //     }

            //     // Y轴位置变化动画
            //     Behavior on y {
            //         NumberAnimation {
            //             duration: 240
            //             easing.type: Easing.OutCubic
            //         }
            //     }

            //     // 发电机测试页组件 - 填充整个容器
            //     GeneratorTestPage {
            //         id: generatorTestPage
            //         anchors.fill: parent
            //         homePage: homePage
            //     }
            // }

            // 波形图页容器 - 包含WaveformPage组件（已注释）
            // Item {
            //     // 水平方向填充布局
            //     Layout.fillWidth: true

            //     // 垂直方向填充布局
            //     Layout.fillHeight: true

            //     // 透明度 - 根据可见性动态调整（用于页面切换动画）
            //     opacity: visible ? 1 : 0

            //     // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
            //     y: visible ? 0 : 12

            //     // 透明度变化动画
            //     Behavior on opacity {
            //         NumberAnimation {
            //             duration: 240  // 动画持续时间：240毫秒
            //             easing.type: Easing.OutCubic  // 动画缓动类型：立方出
            //         }
            //     }

            //     // Y轴位置变化动画
            //     Behavior on y {
            //         NumberAnimation {
            //             duration: 240  // 动画持续时间：240毫秒
            //             easing.type: Easing.OutCubic  // 动画缓动类型：立方出
            //         }
            //     }

            //     // 波形图页组件 - 填充整个容器
            //     WaveformPage { anchors.fill: parent }
            // }

            // 设置页容器 - 包含SettingsPage组件
            Item {
                // 水平方向填充布局
                Layout.fillWidth: true
                
                // 垂直方向填充布局
                Layout.fillHeight: true
                
                // 透明度 - 根据可见性动态调整（用于页面切换动画）
                opacity: visible ? 1 : 0
                
                // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
                y: visible ? 0 : 12
                
                // 透明度变化动画
                Behavior on opacity {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // Y轴位置变化动画
                Behavior on y {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // 设置页组件 - 填充整个容器，并传递homePage引用
                SettingsPage { 
                    anchors.fill: parent 
                    homePage: homePage 
                }
            }

            // 操作说明页容器 - 包含ManualPage组件
            Item {
                // 水平方向填充布局
                Layout.fillWidth: true
                
                // 垂直方向填充布局
                Layout.fillHeight: true
                
                // 透明度 - 根据可见性动态调整（用于页面切换动画）
                opacity: visible ? 1 : 0
                
                // Y轴位置 - 根据可见性动态调整（用于页面切换动画）
                y: visible ? 0 : 12
                
                // 透明度变化动画
                Behavior on opacity {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // Y轴位置变化动画
                Behavior on y {
                    NumberAnimation {
                        duration: 240  // 动画持续时间：240毫秒
                        easing.type: Easing.OutCubic  // 动画缓动类型：立方出
                    }
                }
                
                // 操作说明页组件 - 填充整个容器
                ManualPage { anchors.fill: parent }
            }
        }
    }
}
