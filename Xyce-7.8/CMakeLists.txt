cmake_minimum_required(VERSION 3.22 FATAL_ERROR)
cmake_policy(SET CMP0075 NEW)
cmake_policy(SET CMP0076 NEW)

option(Xyce_USE_SUPERBUILD "Use superbuild to install Trilinos?" OFF)
if(Xyce_USE_SUPERBUILD)
  include("XyceSuperBuild.cmake")
  return()
endif()

# Xyce should use the same compilers as Trilinos.  To ensure this, Trilinos
# should be loaded before "project" is called.  However, "project" probes the
# system and sets up some critical variables.  Therefore, make an initial call
# to "project" with "NONE" as the compiler set, then find Trilinos, then set up
# the compilers and call project again.
project(Xyce NONE)

# A TriBITS project that performs a coupled build with Trilinos, like Charon,
# changes the names of all the Trilinos variables.  Therefore, we have to jump
# through a bunch of hoops to take that use case into account.  Here we set a
# cache variable to handle that name "mangling."
set(TriBITS_prefix "Trilinos" CACHE STRING "Prefix of the Trilinos/TriBITS project")

# Charon can use a specific part of Xyce as a TPL.  However, that use case
# results in a build of Xyce that is unusable for any other purpose.
# "Xyce_AS_SPECIAL_CHARON_TPL" is a "hidden" variable that must be set at the
# initial CMake invocation with the "-D" flag.  If set, CMake looks only for
# the Trilinos packages supplied by Charon. The variable also forces CMake to
# skip some checks in "tps.cmake" that are required for a fully-functional Xyce
# build.
if(Xyce_AS_SPECIAL_CHARON_TPL)
  find_package(${TriBITS_prefix} CONFIG
    REQUIRED Amesos Epetra EpetraExt Ifpack NOX Teuchos Sacado Triutils
         AztecOO Belos TrilinosCouplings Isorropia Zoltan)
else()
  message(STATUS "Looking for Trilinos\n"
    "   Required packages:\n"
    "        Amesos Epetra EpetraExt Ifpack NOX Teuchos Sacado\n"
    "        Triutils AztecOO Belos TrilinosCouplings\n"
    "   Optional packages:\n"
    "        Isorropia Zoltan ShyLU ShyLU_DDCore Amesos2 Stokhos ROL MKL")
  find_package(${TriBITS_prefix} CONFIG
    REQUIRED Amesos Epetra EpetraExt Ifpack NOX Teuchos Sacado Triutils
         AztecOO Belos TrilinosCouplings
    OPTIONAL_COMPONENTS Isorropia Zoltan ShyLU ShyLU_DDCore
         Amesos2 Stokhos ROL MKL)
  message(STATUS "Looking for Trilinos - found")
endif()

# This is behind an if() statement due to the TriBITS name "mangling" issue.
# From what I tell, there is no way to probe the version of Trilinos when it
# is built as part of a different Tribits project.
if(${TriBITS_prefix} STREQUAL "Trilinos" )
  if(Trilinos_VERSION VERSION_LESS "13.5")
    message(FATAL_ERROR
      "ERROR: Trilinos version ${Trilinos_VERSION} is less than the required minimum of 13.5. Install a version of Trilinos of 13.5 or greater.")
  endif()
else()
  # This is where we mitigate the TriBITS name mangling.  We change the
  # variable names to the "correct" names so we minimize pollution of the
  # rest of the configure process.
  set( Trilinos_CXX_COMPILER_FLAGS ${${TriBITS_prefix}_CXX_COMPILER_FLAGS} )
  set( Trilinos_PACKAGE_LIST ${${TriBITS_prefix}_PACKAGE_LIST} )
  set( Trilinos_TPL_LIST ${${TriBITS_prefix}_TPL_LIST} )
  set( Trilinos_TPL_LIBRARIES ${${TriBITS_prefix}_TPL_LIBRARIES} )
endif()

# If the user explicitly set the compilers, use those; otherwise use the same
# compilers as Trilinos.
if( DEFINED CMAKE_C_COMPILER )
  message( "Using the user-defined C compiler: ${CMAKE_C_COMPILER}" )
else()
  message( STATUS "Using the ${TriBITS_prefix} C compiler: ${${TriBITS_prefix}_C_COMPILER}" )
  set( CMAKE_C_COMPILER ${${TriBITS_prefix}_C_COMPILER} )
endif()

if( DEFINED CMAKE_CXX_COMPILER )
  message( "Using the user-defined C++ compiler: ${CMAKE_CXX_COMPILER}" )
else()
  message( STATUS "Using the ${TriBITS_prefix} C++ compiler: ${${TriBITS_prefix}_CXX_COMPILER}" )
  set( CMAKE_CXX_COMPILER ${${TriBITS_prefix}_CXX_COMPILER} )
endif()

enable_language(C)
enable_language(CXX)

# Set a default build type if none was specified (using the fact that
# CMAKE_CONFIGURATION_TYPES is non-zero for mutli-configuration generators).
#
# This has to be before "project" is called, because, for compilers targeting
# the MSVC ABI on Windows, "project" sets the build type.  This behavior was
# changed in CMake version 3.15, but was not made the *default* behavior.
# Since we're compatible with CMake 3.13, we can't use the new behavior. When
# the minimum CMake version requirement is increased, see CMake policy CMP0091:
#    <https://cmake.org/cmake/help/latest/policy/CMP0091.html>
# (Originally, this block was placed right before the
# "include(cmake/config.cmake)" call, below.)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  message("Setting the build type to \"Release\", since it was not explicitly set.")
  # Set the possible values of build type for ccmake and cmake-gui.
  # If a new build type is ever added to Xyce, then this list should be updated.
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "None" "Debug" "Release"
     "RelWithDebInfo" "MinSizeRel")
endif()

project(Xyce VERSION 7.8.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(APPLE)
  list(APPEND CMAKE_INSTALL_RPATH "@loader_path/../lib")
else()
  list(APPEND CMAKE_INSTALL_RPATH "$ORIGIN/../lib")
endif()
if(NOT DEFINED CMAKE_INSTALL_RPATH_USE_LINK_PATH)
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()

option(BUILD_SHARED_LIBS "Build shared libraries?" OFF)

include(cmake/config.cmake)

if(Xyce_PLUGIN_SUPPORT AND (NOT BUILD_SHARED_LIBS))
  message(WARNING "Forcing BUILD_SHARED_LIBS to ON for plugin support.")
  set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries?" FORCE)
endif()

if(BUILD_SHARED_LIBS AND CMAKE_HOST_WIN32 )
  # if building a shared library under windows automatically export all 
  # symbols in the resulting "dll"  This is not optimal but will work 
  # until a detailed code markup is done.
  set( CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON )
endif()
  
add_subdirectory(src)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()
if(Xyce_TEST_BINARIES)
  add_subdirectory(src/test)
endif()

add_subdirectory(utils)

# add in unit tests subdirectory if it exists
if ( EXISTS ${Xyce_SOURCE_DIR}/Xyce_UnitTests)
  add_subdirectory (Xyce_UnitTests)
endif ( EXISTS ${Xyce_SOURCE_DIR}/Xyce_UnitTests)

# Enable Xyce plugin capability
if(Xyce_PLUGIN_SUPPORT)
  find_program(ADMS_XML admsXml)

  if(ADMS_XML)
    configure_file(
      utils/buildxyceplugin.cmake.in
      buildxyceplugin.sh
      @ONLY)
    configure_file(
      utils/XycePluginProject.cmake.in
      XycePluginProject.cmake
      @ONLY)

    install(
      PROGRAMS
        ${ADMS_XML}
        ${CMAKE_BINARY_DIR}/buildxyceplugin.sh
      DESTINATION bin)

    install(
      FILES
        utils/ADMS/adms.implicit.xml
        utils/ADMS/xyceVersion_nosac.xml
        utils/ADMS/xyceBasicTemplates_nosac.xml
        utils/ADMS/xyceAnalogFunction_nosac.xml
        utils/ADMS/xyceHeaderFile_nosac.xml
        utils/ADMS/xyceImplementationFile_nosac.xml
        ${CMAKE_BINARY_DIR}/XycePluginProject.cmake
      DESTINATION share)

    install(
      DIRECTORY utils/ADMS/examples/toys
      DESTINATION share/examples)

    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/utils/ADMS)
    configure_file(${CMAKE_SOURCE_DIR}/utils/ADMS/CMakeLists.txt ${CMAKE_BINARY_DIR}/utils/ADMS/CMakeLists.txt @ONLY ) 
    install(
      FILES
        ${CMAKE_BINARY_DIR}/utils/ADMS/CMakeLists.txt
      DESTINATION share)

    message(STATUS "Plugin compatibility enabled")
  else()
    message(WARNING "ADMS not found.  Disabling the plugin capability.")
    set(Xyce_PLUGIN_SUPPORT OFF CACHE BOOL "Install Xyce with plugin compatibility" FORCE)
  endif()
else()
  message(STATUS "Plugin compatibility not enabled")
endif()

# if no generator type is specified, use RPM
set(GEN_TYPE "RPM" CACHE STRING "What generator to use.")

include(CPack)
#See the CPackConfig.cmake in Xyce/cmake for settings
