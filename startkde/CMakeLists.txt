add_subdirectory(kcminit)
add_subdirectory(kstartupconfig)
add_subdirectory(ksyncdbusenv)
add_subdirectory(waitforname)

configure_file(startkde.cmake ${CMAKE_CURRENT_BINARY_DIR}/startkde  @ONLY)
configure_file(startplasmacompositor.cmake ${CMAKE_CURRENT_BINARY_DIR}/startplasmacompositor  @ONLY)
configure_file(startplasma.cmake ${CMAKE_CURRENT_BINARY_DIR}/startplasma  @ONLY)

if(NOT WIN32)
  install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/startkde DESTINATION ${KDE_INSTALL_BINDIR})
  install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/startplasmacompositor DESTINATION ${KDE_INSTALL_BINDIR})
  install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/startplasma DESTINATION ${KDE_INSTALL_LIBEXECDIR})
endif()
