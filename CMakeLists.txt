cmake_minimum_required(VERSION 3.16)
project(AC200V-270V-40A VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Network SerialPort SerialBus Pdf)

qt_standard_project_setup(REQUIRES 6.8)

if(MINGW)
    set(CMAKE_RC_COMPILER windres)
    set(CMAKE_RC_FLAGS "${CMAKE_RC_FLAGS} --use-temp-file")
endif()

qt_add_executable(AC200V-270V-40A
    main.cpp
    serial/SerialPortManager.h
    serial/SerialPortManager.cpp
    serial/ModbusManager.h
    serial/ModbusManager.cpp
    serial/GeneratorTestManager.h
    serial/GeneratorTestManager.cpp
    serial/SerialRequestManager.h
    serial/SerialRequestManager.cpp
    serial/DataRecorder.h
    serial/DataRecorder.cpp
    app.rc
)
file(GLOB_RECURSE QML_COMPONENTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "components/*.qml")
qt_add_qml_module(AC200V-270V-40A
    URI EvolveUI
    VERSION 1.0
    QML_FILES
                Main.qml
                pages/HomePage.qml
                # pages/WaveformPage.qml
                pages/SettingsPage.qml
                pages/StepRunPage.qml
                pages/GeneratorTestPage.qml
                pages/ManualPage.qml
                ${QML_COMPONENTS}
)

qt_add_resources(APP_RESOURCES
    src.qrc
)
target_sources(AC200V-270V-40A PRIVATE ${APP_RESOURCES})
target_link_libraries(AC200V-270V-40A PRIVATE Qt6::Quick Qt6::Multimedia Qt6::Network Qt6::SerialPort Qt6::SerialBus Qt6::Pdf)
set_target_properties(AC200V-270V-40A PROPERTIES WIN32_EXECUTABLE TRUE)
