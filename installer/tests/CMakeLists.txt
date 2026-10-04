# Backend logic, without D-Bus or a real disk.
qt_add_executable(tst_backend tst_backend.cpp)
target_link_libraries(tst_backend PRIVATE backend Qt6::Test)
add_test(NAME backend COMMAND tst_backend)

# The pages, clicked through against the simulated backend on a private bus.
qt_add_executable(tst_ui tst_ui.cpp)
target_link_libraries(tst_ui PRIVATE ui uiplugin Qt6::Test)
target_compile_definitions(tst_ui PRIVATE INSTALLER_BACKEND="$<TARGET_FILE:installer-backend>")
add_test(NAME ui COMMAND dbus-run-session -- $<TARGET_FILE:tst_ui>)
set_tests_properties(ui PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

# The D-Bus interface, exercised by installerctl against the simulated backend.
add_test(NAME interface COMMAND dbus-run-session -- ${CMAKE_CURRENT_SOURCE_DIR}/interface.sh
         $<TARGET_FILE:installer-backend> $<TARGET_FILE:installerctl>)
