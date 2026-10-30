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
