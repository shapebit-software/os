# The QML module is a library, so that the UI test can link the same pages.
qt_add_library(ui STATIC)
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(ui
    URI Installer
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Installer
    SOURCES backend.cpp backend.h keyboard.cpp keyboard.h timezones.cpp timezones.h
    QML_FILES
        qml/Main.qml
        # Shared parts.
        qml/Theme.qml
        qml/Step.qml
        qml/Panel.qml
        qml/Mono.qml
        qml/Btn.qml
        qml/LinkButton.qml
        qml/Field.qml
        qml/Check.qml
        qml/Bar.qml
        qml/ListRow.qml
        qml/Logo.qml
        # Pages, in the order they are shown.
        qml/WelcomePage.qml
        qml/KeyboardPage.qml
        qml/NetworkPage.qml
        qml/TimeZonePage.qml
        qml/AccountPage.qml
        qml/DiskPage.qml
        qml/ProgressPage.qml
        qml/RecoveryKeyPage.qml
        qml/DonePage.qml
        qml/ErrorPage.qml)
target_include_directories(ui PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
# libxkbcommon translates key codes for the chosen keyboard layout (see keyboard.h).
target_link_libraries(ui PUBLIC client Qt6::Quick Qt6::QuickControls2 PkgConfig::xkbcommon)

qt_add_executable(installer main.cpp)
target_link_libraries(installer PRIVATE ui uiplugin)
install(TARGETS installer)
