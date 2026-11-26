# Everything but main() is a library, so that tests can link it.
qt_add_dbus_adaptor(adaptor_sources ../interface/installer.xml installer.h Installer installeradaptor Installer1Adaptor)

add_library(backend STATIC
    command.cpp command.h
    disks.cpp disks.h
    engine.h
    installer.cpp installer.h
    simulation.cpp simulation.h
    system.cpp system.h
    ${adaptor_sources})
target_include_directories(backend PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR} ../interface)
target_link_libraries(backend PUBLIC Qt6::Core Qt6::DBus)

add_executable(installer-backend main.cpp)
target_link_libraries(installer-backend PRIVATE backend)
install(TARGETS installer-backend DESTINATION ${CMAKE_INSTALL_LIBEXECDIR})
install(FILES ${PROJECT_SOURCE_DIR}/system/installer-backend.service DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/system)
# Who may call the backend on the system bus: only the UI's user.
install(FILES ${PROJECT_SOURCE_DIR}/system/dbus-policy.conf DESTINATION ${CMAKE_INSTALL_DATADIR}/dbus-1/system.d RENAME installer.conf)
