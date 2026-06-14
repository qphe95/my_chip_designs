# Install script for directory: /home/qingping/my_chip_designs/ALIGN-public/_build/_deps/ilpsolverif-src/ILPSolverIf

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Install shared libraries without execute permission?
if(NOT DEFINED CMAKE_INSTALL_SO_NO_EXE)
  set(CMAKE_INSTALL_SO_NO_EXE "1")
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/lib/libOsiCbc.a;/usr/local/lib/libCbcSolver.a;/usr/local/lib/libCbc.a;/usr/local/lib/libCgl.a;/usr/local/lib/libOsiClp.a;/usr/local/lib/libClpSolver.a;/usr/local/lib/libClp.a;/usr/local/lib/libOsi.a;/usr/local/lib/libCoinUtils.a;/usr/local/lib/libOsiCbc.so;/usr/local/lib/libCbcSolver.so;/usr/local/lib/libCbc.so;/usr/local/lib/libCgl.so;/usr/local/lib/libOsiClp.so;/usr/local/lib/libClpSolver.so;/usr/local/lib/libClp.so;/usr/local/lib/libOsi.so;/usr/local/lib/libCoinUtils.so;/usr/local/lib/libOsiCbc.so.3.10.5;/usr/local/lib/libCbcSolver.so.3.10.5;/usr/local/lib/libCbc.so.3.10.5;/usr/local/lib/libCgl.so.1.10.3;/usr/local/lib/libOsiClp.so.1.14.5;/usr/local/lib/libClpSolver.so.1.14.5;/usr/local/lib/libClp.so.1.14.5;/usr/local/lib/libOsi.so.1.13.6;/usr/local/lib/libCoinUtils.so.3.11.4;/usr/local/lib/libOsiCbc.so.3;/usr/local/lib/libCbcSolver.so.3;/usr/local/lib/libCbc.so.3;/usr/local/lib/libCgl.so.1;/usr/local/lib/libOsiClp.so.1;/usr/local/lib/libClpSolver.so.1;/usr/local/lib/libClp.so.1;/usr/local/lib/libOsi.so.1;/usr/local/lib/libCoinUtils.so.3")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/lib" TYPE FILE FILES
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiCbc.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbcSolver.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbc.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCgl.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiClp.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClpSolver.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClp.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsi.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCoinUtils.a"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiCbc.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbcSolver.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbc.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCgl.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiClp.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClpSolver.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClp.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsi.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCoinUtils.so"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiCbc.so.3.10.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbcSolver.so.3.10.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbc.so.3.10.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCgl.so.1.10.3"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiClp.so.1.14.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClpSolver.so.1.14.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClp.so.1.14.5"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsi.so.1.13.6"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCoinUtils.so.3.11.4"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiCbc.so.3"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbcSolver.so.3"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCbc.so.3"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCgl.so.1"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsiClp.so.1"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClpSolver.so.1"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libClp.so.1"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libOsi.so.1"
    "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/cbc-build/lib/libCoinUtils.so.3"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/home/qingping/my_chip_designs/ALIGN-public/_build/_deps/ilpsolverif-build/ILPSolverIf/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
