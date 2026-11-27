# The installer's tests, run by CTest: those labelled unit with make test-unit,
# those labelled integration with make test-integration.

# Backend logic, without D-Bus or a real disk.
qt_add_executable(tst_backend unit/tst_backend.cpp)
target_link_libraries(tst_backend PRIVATE backend Qt6::Test)
add_test(NAME backend COMMAND tst_backend)
set_tests_properties(backend PROPERTIES LABELS unit)

# The pages, clicked through against the simulated backend on a private bus.
qt_add_executable(tst_ui integration/tst_ui.cpp)
target_link_libraries(tst_ui PRIVATE ui uiplugin Qt6::Test)
target_compile_definitions(tst_ui PRIVATE INSTALLER_BACKEND="$<TARGET_FILE:installer-backend>")
add_test(NAME ui COMMAND dbus-run-session -- $<TARGET_FILE:tst_ui>)
set_tests_properties(ui PROPERTIES LABELS integration
                     ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QML_IMPORT_PATH=${COLORS_IMPORT_PATH}")

# The D-Bus interface, exercised by installerctl against the simulated backend.
add_test(NAME interface COMMAND dbus-run-session -- python3 ${CMAKE_CURRENT_SOURCE_DIR}/integration/tst_interface.py
         $<TARGET_FILE:installer-backend> $<TARGET_FILE:installerctl>)
set_tests_properties(interface PROPERTIES LABELS integration)
