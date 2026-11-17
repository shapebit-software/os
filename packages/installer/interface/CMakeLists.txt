# The D-Bus proxy generated from installer.xml, shared by the UI and installerctl.
set_source_files_properties(installer.xml PROPERTIES INCLUDE names.h)
qt_add_dbus_interface(client_sources installer.xml installerinterface)

add_library(client STATIC ${client_sources} names.h)
target_include_directories(client PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(client PUBLIC Qt6::Core Qt6::DBus)

# The D-Bus interface, exercised by installerctl against the simulated backend.
add_test(NAME interface COMMAND dbus-run-session -- ${CMAKE_CURRENT_SOURCE_DIR}/test_interface.sh
         $<TARGET_FILE:installer-backend> $<TARGET_FILE:installerctl>)
