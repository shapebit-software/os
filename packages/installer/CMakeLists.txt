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
set(COLORS_IMPORT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../colors"
    CACHE PATH "The folder that holds the Colors QML module, if not Qt's own")
if(NOT EXISTS "${COLORS_IMPORT_PATH}/Colors/qmldir")
    set(COLORS_IMPORT_PATH "")
endif()

add_subdirectory(interface)
add_subdirectory(backend)
add_subdirectory(ctl)
add_subdirectory(ui)

# Both programs' units are enabled by the preset; each program installs its own.
install(FILES units.preset
        DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/system-preset RENAME 50-installer.preset)
