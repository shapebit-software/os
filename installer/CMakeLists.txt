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
