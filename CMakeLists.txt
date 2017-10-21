cmake_minimum_required(VERSION 3.0)

project(mmc)

find_package(PERL REQUIRED)

set(HEADERS src/timeout.h src/socket.h src/Char.h src/window.h src/output.h src/cmalloc.h src/misc.h config.h)
set(SOURCES src/main.c src/socket.c src/timeout.c src/window.c src/misc.c src/cmalloc.c src/win32.c src/version.c xsinit.c perlmodules.c CL.c)

if (WIN32)
	add_custom_target(config.h
		SOURCES src/config_h.win32
		COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/src/config_h.win32 config.h
		COMMENT "Generating file config.h")

	enable_language(RC)
	set(HEADERS src/window_priv.h ${HEADERS})
	set(SOURCES src/mmc.rc ${SOURCES})
endif ()

execute_process(COMMAND ${PERL_EXECUTABLE} -MConfig -e "print \$Config{privlibexp};" OUTPUT_VARIABLE PERL_LIBS_DIRECTORY)
message(STATUS "Perl libraries folder: ${PERL_LIBS_DIRECTORY}")

execute_process(COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e ccopts OUTPUT_VARIABLE PERL_CCOPTS)
execute_process(COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e ldopts OUTPUT_VARIABLE PERL_LDOPTS)

add_custom_target(CL.c SOURCES src/CL.xs
	COMMAND ${PERL_EXECUTABLE} ${PERL_LIBS_DIRECTORY}/ExtUtils/xsubpp -typemap ${PERL_LIBS_DIRECTORY}/ExtUtils/typemap ${PROJECT_SOURCE_DIR}/src/CL.xs > CL.c
	COMMENT "Generating file CL.c")
include_directories(${PROJECT_SOURCE_DIR}/src)	# Because CL.c will contain references to header files

add_custom_target(xsinit.c COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e xsinit -- -o xsinit.c CL DynaLoader)

add_custom_target(perlmodules.c SOURCES src/packmod.pl
	COMMAND ${PERL_EXECUTABLE} -I${PROJECT_SOURCE_DIR}/src/ ${PROJECT_SOURCE_DIR}/src/packmod.pl --b2c $<TARGET_FILE:b2c> AutoLoader DynaLoader=${PROJECT_SOURCE_DIR}/src/DLWin32.pm Carp Carp::Heavy warnings::register warnings strict integer vars fields base locale Exporter Exporter::Heavy Symbol Text::ParseWords Ex CL Conf CMD LE Parser MUD Keymap Main RStream DCommand Ticker Status UAPI > perlmodules.c
	COMMENT "Packing perl modules into perlmodules.c")

add_executable(b2c src/b2c.c)
add_executable(mmc ${SOURCES} ${HEADERS})

set_target_properties(mmc PROPERTIES LINK_FLAGS "/SUBSYSTEM:WINDOWS ${PERL_LDOPTS}")
set_target_properties(mmc PROPERTIES COMPILE_FLAGS "${PERL_CCOPTS}")

find_package(ZLIB REQUIRED)
include_directories(${ZLIB_INCLUDE_DIRS})
target_link_libraries(b2c ${ZLIB_LIBRARIES})
target_link_libraries(mmc ${ZLIB_LIBRARIES})

# vim: set ts=4 sw=4 tw=0 noet syntax=cmake :
