add_definitions(-DTRANSLATION_DOMAIN=\"plasma_runner_shell\")

set(krunner_shell_SRCS
    shellrunner.cpp
    shell_config.cpp
)

ki18n_wrap_ui(krunner_shell_SRCS shellOptions.ui)
add_library(krunner_shell MODULE ${krunner_shell_SRCS})
target_link_libraries(krunner_shell
    KF5::KIOCore
    KF5::KIOWidgets
    KF5::I18n
    KF5::Plasma
    KF5::Runner
    KF5::Completion
    Qt5::Widgets
)

install(TARGETS krunner_shell DESTINATION ${KDE_INSTALL_PLUGINDIR})
install(FILES plasma-runner-shell.desktop DESTINATION ${KDE_INSTALL_KSERVICES5DIR})

