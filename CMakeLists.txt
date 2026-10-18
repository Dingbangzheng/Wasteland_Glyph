cmake_minimum_required(VERSION 3.16)

# ---------------------------------------------------------------------------
# Wasteland Glyph
#   Language standard, terminal backend, endianness and dependency pinning all
#   follow GDD 2.1. The PROTO_VER.SAVE_VER.GEN_ALGO triple is separate from the
#   GDD version; GEN_ALGO lives in src/core/rng.h.
# ---------------------------------------------------------------------------
project(wasteland_glyph
    VERSION 0.1.0
    DESCRIPTION "Terminal, cross-platform, LAN-capable post-apocalyptic survival roguelike"
    LANGUAGES CXX C)   # C is required: PDCursesMod is a C library

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)          # GDD 2.1: no compiler extensions

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

option(WG_BUILD_TESTS "Build unit tests" ON)
option(WG_FETCH_DEPENDENCIES "Fetch third-party dependencies (PDCursesMod, ENet) at configure time" ON)

# GDD 2.1: little-endian hosts only, checked at compile time.
include(cmake/endian_check.cmake)

# ---------------------------------------------------------------------------
# Networking (GDD 2.1: ENet, standalone, UDP reliability built in)
#   M3 needs it for the client/server split; the M1/M2 single-process path
#   builds without it.
# ---------------------------------------------------------------------------
option(WG_BUILD_NET "Build the ENet transport (client/server split)" ON)

if(WG_BUILD_NET)
    if(WG_FETCH_DEPENDENCIES)
        include(FetchContent)
        FetchContent_Declare(
            enet
            GIT_REPOSITORY https://github.com/lsalzman/enet.git
            GIT_TAG        v1.3.9        # GDD 2.1: pinned tag
            GIT_SHALLOW    TRUE
        )
        # ENet has no CMakeLists.txt, so the source list is vendored in
        # cmake/enet.cmake and the upstream tree is only fetched.
        FetchContent_GetProperties(enet)
        if(NOT enet_POPULATED)
            FetchContent_Populate(enet)
        endif()
        include(cmake/enet.cmake)
        wg_add_enet_static("${enet_SOURCE_DIR}" wg_enet)
        set(WG_ENET_TARGET wg_enet)
    else()
        if(NOT DEFINED enet_SOURCE_DIR)
            message(FATAL_ERROR
                "WG_FETCH_DEPENDENCIES=OFF requires -Denet_SOURCE_DIR=<ENet source root>")
        endif()
        include(cmake/enet.cmake)
        wg_add_enet_static("${enet_SOURCE_DIR}" wg_enet)
        set(WG_ENET_TARGET wg_enet)
    endif()
endif()

# ---------------------------------------------------------------------------
# Cryptography (GDD 2.1, 12.4, 12.5)
#   libsodium supplies X25519 for the key exchange, ChaCha20-Poly1305 for the
#   AEAD and Argon2id for password hashing. It has no CMakeLists.txt, so the
#   source list is vendored in cmake/libsodium.cmake.
# ---------------------------------------------------------------------------
option(WG_BUILD_CRYPTO "Build the encrypted transport and account store" ON)

if(WG_BUILD_NET AND WG_BUILD_CRYPTO)
    if(WG_FETCH_DEPENDENCIES)
        include(FetchContent)
        # libsodium has no CMakeLists.txt, so there is no target for
        # MakeAvailable to add; it is populated and then compiled by
        # cmake/libsodium.cmake. CMP0169 keeps the direct populate call legal.
        if(POLICY CMP0169)
            cmake_policy(SET CMP0169 OLD)
        endif()
        FetchContent_Declare(
            libsodium
            GIT_REPOSITORY https://github.com/jedisct1/libsodium.git
            GIT_TAG        1.0.22       # GDD 2.1: pinned tag
            GIT_SHALLOW    TRUE
        )
        FetchContent_GetProperties(libsodium)
        if(NOT libsodium_POPULATED)
            FetchContent_Populate(libsodium)
        endif()
    else()
        if(NOT DEFINED libsodium_SOURCE_DIR)
            message(FATAL_ERROR
                "WG_FETCH_DEPENDENCIES=OFF with WG_BUILD_CRYPTO=ON requires "
                "-Dlibsodium_SOURCE_DIR=<libsodium source root>")
        endif()
    endif()
    include(cmake/libsodium.cmake)
    wg_add_libsodium_static("${libsodium_SOURCE_DIR}" wg_libsodium)
    set(WG_SODIUM_TARGET wg_libsodium)
endif()

# ---------------------------------------------------------------------------
# Terminal backend
#   PDCursesMod v4.5.4 (pinned tag) on Windows; ncursesw elsewhere.
# ---------------------------------------------------------------------------
if(WIN32)
    if(WG_FETCH_DEPENDENCIES)
        include(FetchContent)
        FetchContent_Declare(
            pdcursesmod
            GIT_REPOSITORY https://github.com/Bill-Gray/PDCursesMod.git
            GIT_TAG        v4.5.4        # GDD 2.1: pinned tag
            GIT_SHALLOW    TRUE
        )
        FetchContent_GetProperties(pdcursesmod)
        if(NOT pdcursesmod_POPULATED)
            FetchContent_Populate(pdcursesmod)
        endif()

        # PDCursesMod's own CMakeLists cannot run as a subproject, so the
        # source list is vendored in cmake/pdcursesmod.cmake instead.
        include(cmake/pdcursesmod.cmake)
        wg_add_pdcursesmod_static("${pdcursesmod_SOURCE_DIR}" wg_pdcursesmod)
        set(WG_TERMINAL_TARGET wg_pdcursesmod)
    else()
        if(NOT DEFINED pdcursesmod_SOURCE_DIR)
            message(FATAL_ERROR
                "WG_FETCH_DEPENDENCIES=OFF requires -Dpdcursesmod_SOURCE_DIR=<PDCursesMod source root>")
        endif()
        include(cmake/pdcursesmod.cmake)
        wg_add_pdcursesmod_static("${pdcursesmod_SOURCE_DIR}" wg_pdcursesmod)
        set(WG_TERMINAL_TARGET wg_pdcursesmod)
    endif()
endif()

# ---------------------------------------------------------------------------
# JSON (GDD 2.1: nlohmann/json). Vendored as the single header at
# src/third_party/nlohmann/json.hpp (v3.11.3, MIT), because that header IS the
# whole library and fetching a ~100 MB repository to obtain one 900 KB file made
# every fresh configure depend on GitHub being reachable -- which failed once in
# practice. Chapter 20's data files and the account store of 12.5 are the
# consumers.
#
# Upstream: https://github.com/nlohmann/json, tag v3.11.3.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Core library: pure logic, no terminal or socket dependency.
# ---------------------------------------------------------------------------
add_library(wg_core STATIC
    src/core/i18n.cpp
    src/core/seed.cpp
    src/data/itemdb.cpp
    src/data/modman.cpp
    src/world/chunk.cpp
    src/world/dungeon.cpp
    src/world/fov.cpp
    src/world/localmap.cpp
    src/world/overmap.cpp
    src/world/worldgen.cpp
    src/game/animal.cpp
    src/game/build.cpp
    src/game/chat.cpp
    src/game/combat.cpp
    src/game/corpse.cpp
    src/game/crafting.cpp
    src/game/game.cpp
    src/game/game_data.cpp
    src/game/ground_items.cpp
    src/game/health.cpp
    src/game/inventory.cpp
    src/game/item.cpp
    src/game/loot.cpp
    src/game/medical.cpp
    src/game/skill.cpp
    src/game/spawn_rule.cpp
    src/game/farming.cpp
    src/game/fire.cpp
    src/game/keymap.cpp
    src/game/power.cpp
    src/game/survival.cpp
    src/game/tailoring.cpp
    src/game/trap.cpp
    src/game/temperature.cpp
    src/game/weather.cpp
    src/game/zombie.cpp
    src/game/zombie_ai.cpp
    src/persist/log.cpp
    src/persist/chat_log.cpp
    src/persist/save.cpp
    src/net/protocol.cpp
    src/net/delta.cpp
    src/net/session.cpp
)

if(WG_BUILD_NET)
    target_sources(wg_core PRIVATE
        src/net/client.cpp
        src/net/server.cpp
    )
    target_link_libraries(wg_core PUBLIC ${WG_ENET_TARGET})
    target_compile_definitions(wg_core PUBLIC WG_HAS_NET=1)

    if(WG_BUILD_CRYPTO)
        target_sources(wg_core PRIVATE
            src/net/crypto.cpp
            src/net/account.cpp
        )
        target_link_libraries(wg_core PUBLIC ${WG_SODIUM_TARGET})
        target_compile_definitions(wg_core PUBLIC WG_HAS_CRYPTO=1)
    else()
        target_compile_definitions(wg_core PUBLIC WG_HAS_CRYPTO=0)
    endif()
else()
    target_compile_definitions(wg_core PUBLIC WG_HAS_NET=0 WG_HAS_CRYPTO=0)
endif()

target_include_directories(wg_core PUBLIC src src/third_party)
target_compile_definitions(wg_core PUBLIC _CRT_SECURE_NO_WARNINGS NOMINMAX)
set_property(TARGET wg_core PROPERTY CXX_STANDARD 17)

if(MSVC)
    target_compile_options(wg_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(wg_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ---------------------------------------------------------------------------
# Terminal client
# ---------------------------------------------------------------------------
add_executable(wasteland_glyph
    src/main.cpp
    src/game/render.cpp
)
target_link_libraries(wasteland_glyph PRIVATE wg_core)
target_compile_definitions(wasteland_glyph PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX)
set_property(TARGET wasteland_glyph PROPERTY CXX_STANDARD 17)

if(WIN32)
    target_link_libraries(wasteland_glyph PRIVATE ${WG_TERMINAL_TARGET})
else()
    find_package(Curses REQUIRED)
    target_include_directories(wasteland_glyph PRIVATE ${CURSES_INCLUDE_DIRS})
    target_link_libraries(wasteland_glyph PRIVATE ${CURSES_LIBRARIES})
endif()

if(MSVC)
    target_compile_options(wasteland_glyph PRIVATE /W4 /permissive-)
else()
    target_compile_options(wasteland_glyph PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ---------------------------------------------------------------------------
# Dedicated server (GDD 4.4): no terminal dependency at all, so it runs on a
# headless box and in CI without a TTY.
# ---------------------------------------------------------------------------
if(WG_BUILD_NET)
    add_executable(wasteland_glyph_server src/main_server.cpp)
    target_link_libraries(wasteland_glyph_server PRIVATE wg_core)
    target_compile_definitions(wasteland_glyph_server PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX)
    set_property(TARGET wasteland_glyph_server PROPERTY CXX_STANDARD 17)
    if(MSVC)
        target_compile_options(wasteland_glyph_server PRIVATE /W4 /permissive-)
    else()
        target_compile_options(wasteland_glyph_server PRIVATE -Wall -Wextra -Wpedantic)
    endif()
endif()

# ---------------------------------------------------------------------------
# Headless digest tool: the M2 acceptance check of GDD 18 made observable.
# ---------------------------------------------------------------------------
add_executable(wasteland_glyph_digest tools/digest.cpp)
target_link_libraries(wasteland_glyph_digest PRIVATE wg_core)
target_compile_definitions(wasteland_glyph_digest PRIVATE _CRT_SECURE_NO_WARNINGS NOMINMAX)
set_property(TARGET wasteland_glyph_digest PROPERTY CXX_STANDARD 17)
if(MSVC)
    target_compile_options(wasteland_glyph_digest PRIVATE /W4 /permissive-)
else()
    target_compile_options(wasteland_glyph_digest PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ---------------------------------------------------------------------------
# GDD 20.1: data/ is resolved relative to the working directory, so the binaries
# need a copy beside them to run from build/bin. Copied after every build rather
# than at configure time so editing a data file does not need a reconfigure.
# ---------------------------------------------------------------------------
add_custom_target(wg_copy_data ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_SOURCE_DIR}/data" "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/data"
    COMMENT "Copying data/ next to the binaries (GDD 20.1)"
    VERBATIM
)

# ---------------------------------------------------------------------------
# Tests (headless: wg_core only, no terminal dependency)
# ---------------------------------------------------------------------------
if(WG_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
