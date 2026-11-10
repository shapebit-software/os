cmake_minimum_required(VERSION 3.25)
project(installer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core DBus Quick QuickControls2 Test)
qt_standard_project_setup(REQUIRES 6.8)
find_package(PkgConfig REQUIRED)
pkg_check_modules(xkbcommon REQUIRED IMPORTED_TARGET xkbcommon)
include(GNUInstallDirs)
enable_testing()

# Colors, the system's colors, is a QML module of the image, which the
# installer medium carries in Qt's own folder. Built from the repository, the
# installer takes it from the image's source instead, for tooling and tests.
set(COLORS_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../image/rootfs/usr/lib64/qt6/qml"
    CACHE PATH "The folder that holds the Colors QML module, if not Qt's own")
if(NOT EXISTS "${COLORS_IMPORT_PATH}/Colors/qmldir")
    set(COLORS_IMPORT_PATH "")
endif()

add_subdirectory(interface)
add_subdirectory(backend)
add_subdirectory(ctl)
add_subdirectory(ui)
add_subdirectory(tests)

install(FILES data/installer-backend.service data/installer.service
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/system)
install(FILES data/units.preset
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/system-preset RENAME 50-installer.preset)
install(FILES data/sysusers.conf
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/sysusers.d RENAME installer.conf)
install(FILES data/dbus-policy.conf
        DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/system.d RENAME installer.conf)
