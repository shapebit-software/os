add_executable(installerctl main.cpp)
target_link_libraries(installerctl PRIVATE client)
install(TARGETS installerctl)
