cmake_minimum_required(VERSION 3.16)

# Load configuration from config file
include(config/cmake.conf OPTIONAL)

# Project declaration
project(pogocache
    VERSION 1.0.0
    DESCRIPTION "High-performance caching system"
    HOMEPAGE_URL "https://github.com/tidwall/pogocache"
    LANGUAGES C
)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Build type handling
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Include modern CMake modules
include(GNUInstallDirs)
include(CheckIncludeFile)
include(CheckFunctionExists)
include(CheckLibraryExists)

# === Feature Detection ===

# Check for io_uring support (Linux only)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_path(URING_INCLUDE_DIR liburing.h)
    find_library(URING_LIBRARY uring)
    
    if(URING_INCLUDE_DIR AND URING_LIBRARY AND NOT DISABLE_URING)
        set(HAVE_URING TRUE)
        message(STATUS "io_uring support: enabled")
    else()
        set(HAVE_URING FALSE)
        add_compile_definitions(NOURING)
        message(STATUS "io_uring support: disabled")
    endif()
endif()

# Check for OpenSSL support
find_package(OpenSSL)
if(OpenSSL_FOUND AND NOT DISABLE_OPENSSL)
    set(HAVE_OPENSSL TRUE)
    message(STATUS "OpenSSL support: enabled")
else()
    set(HAVE_OPENSSL FALSE)
    add_compile_definitions(NOOPENSSL)
    message(STATUS "OpenSSL support: disabled")
endif()

# Check for required system libraries
find_library(MATH_LIBRARY m)
if(NOT MATH_LIBRARY)
    set(MATH_LIBRARY "")
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_library(RT_LIBRARY rt)
    find_package(Threads REQUIRED)
endif()

# === Compiler Configuration ===

# Common compiler flags
add_compile_options(
    -Wall
    -Wextra
    -Werror
)

# Platform-specific definitions
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_compile_definitions(_GNU_SOURCE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    add_compile_definitions(_DARWIN_C_SOURCE)
endif()

# Build type specific flags
if(CMAKE_BUILD_TYPE MATCHES "Debug")
    add_compile_definitions(DEBUG)
    add_compile_options(-g3 -O0 -fno-omit-frame-pointer)
elseif(CMAKE_BUILD_TYPE MATCHES "Release")
    add_compile_definitions(NDEBUG)
    add_compile_options(-O3)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
        add_compile_options(-flto=auto)
        add_link_options(-flto=auto)
    endif()
endif()

# Sanitizer support
option(ENABLE_SANITIZERS "Enable address and undefined behavior sanitizers" OFF)
if(ENABLE_SANITIZERS)
    add_compile_options(-fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address -fsanitize=undefined)
    add_compile_definitions(CCSANI)
endif()

# === Source Files ===

set(POGOCACHE_SOURCES
    src/main.c
    src/pogocache.c
    src/sys.c
    src/cmds.c
    src/util.c
    src/buf.c
    src/stats.c
    src/conn.c
    src/args.c
    src/uring.c
    src/memcache.c
    src/postgres.c
    src/tls.c
    src/save.c
    src/parse.c
    src/lz4.c
    src/net.c
    src/xmalloc.c
    src/resp.c
    src/http.c
    src/hashmap.c
)

# === Git Information ===
find_package(Git QUIET)
if(Git_FOUND)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    
    execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    
    if(GIT_VERSION)
        string(REGEX REPLACE "^v" "" GIT_VERSION "${GIT_VERSION}")
    endif()
else()
    set(GIT_HASH "unknown")
    set(GIT_VERSION "unknown")
endif()

# Generate git info header
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/src/gitinfo.h.in
    ${CMAKE_CURRENT_BINARY_DIR}/src/gitinfo.h
    @ONLY
)

# Create gitinfo.h.in if it doesn't exist
if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/src/gitinfo.h.in)
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/src/gitinfo.h.in
        "char GITHASH[] = \"@GIT_HASH@\";\nchar GITVERS[] = \"@GIT_VERSION@\";\n"
    )
endif()

# === Main Executable ===

add_executable(pogocache ${POGOCACHE_SOURCES})

# Include directories
target_include_directories(pogocache PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_BINARY_DIR}/src
)

# Link libraries
target_link_libraries(pogocache PRIVATE ${MATH_LIBRARY})

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_link_libraries(pogocache PRIVATE ${RT_LIBRARY})
    target_link_libraries(pogocache PRIVATE Threads::Threads)
endif()

if(HAVE_URING)
    target_link_libraries(pogocache PRIVATE ${URING_LIBRARY})
    target_include_directories(pogocache PRIVATE ${URING_INCLUDE_DIR})
endif()

if(HAVE_OPENSSL)
    target_link_libraries(pogocache PRIVATE OpenSSL::SSL OpenSSL::Crypto)
endif()

# === Installation ===

# Install binary
install(TARGETS pogocache
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install headers
install(DIRECTORY include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.h"
)

# Install examples
install(DIRECTORY examples/
    DESTINATION ${CMAKE_INSTALL_DATADIR}/pogocache/examples
    PATTERN "*.out" EXCLUDE
    PATTERN "*.o" EXCLUDE
)

# Install scripts
install(PROGRAMS 
    scripts/build.sh
    scripts/install.sh  
    scripts/test.sh
    DESTINATION ${CMAKE_INSTALL_DATADIR}/pogocache/scripts
)

# Install configuration files
install(DIRECTORY config/
    DESTINATION ${CMAKE_INSTALL_DATADIR}/pogocache/config
)

# === pkg-config file ===
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/pogocache.pc.in
    ${CMAKE_CURRENT_BINARY_DIR}/pogocache.pc
    @ONLY
)

if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/pogocache.pc.in)
    file(WRITE ${CMAKE_CURRENT_SOURCE_DIR}/pogocache.pc.in
"prefix=@CMAKE_INSTALL_PREFIX@
exec_prefix=\${prefix}
libdir=\${exec_prefix}/@CMAKE_INSTALL_LIBDIR@
includedir=\${prefix}/@CMAKE_INSTALL_INCLUDEDIR@

Name: pogocache
Description: @PROJECT_DESCRIPTION@
Version: @PROJECT_VERSION@
Cflags: -I\${includedir}
Libs: -L\${libdir} -lpogocache
"
    )
endif()

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pogocache.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

# === Testing ===
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    
    # Add tests if test directory exists
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/tests)
        add_subdirectory(tests OPTIONAL)
    endif()
endif()

# === Examples ===
option(BUILD_EXAMPLES "Build examples" OFF)
if(BUILD_EXAMPLES)
    add_subdirectory(examples OPTIONAL)
endif()

# === Summary ===
message(STATUS "")
message(STATUS "=== Pogocache Build Configuration ===")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C Compiler: ${CMAKE_C_COMPILER_ID} ${CMAKE_C_COMPILER_VERSION}")
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "Features:")
message(STATUS "  io_uring support: ${HAVE_URING}")
message(STATUS "  OpenSSL support: ${HAVE_OPENSSL}")
message(STATUS "  Sanitizers: ${ENABLE_SANITIZERS}")
message(STATUS "  Testing: ${BUILD_TESTING}")
message(STATUS "  Examples: ${BUILD_EXAMPLES}")
message(STATUS "")
message(STATUS "Git information:")
message(STATUS "  Hash: ${GIT_HASH}")
message(STATUS "  Version: ${GIT_VERSION}")
message(STATUS "")