cmake_minimum_required(VERSION 3.0)

project(mmc)

find_package(PERL REQUIRED)

set(HEADERS src/timeout.h src/socket.h src/Char.h src/window.h src/output.h src/cmalloc.h src/misc.h config.h)
set(SOURCES src/main.c src/socket.c src/timeout.c src/window.c src/misc.c src/cmalloc.c src/win32.c src/version.c xsinit.c perlmodules.c CL.c)

if (WIN32)
	add_custom_command(OUTPUT config.h
		MAIN_DEPENDENCY src/config_h.win32
		COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/src/config_h.win32 config.h
		COMMENT "Generating file config.h")

	enable_language(RC)
	set(HEADERS src/window_priv.h ${HEADERS})
	set(SOURCES src/mmc.rc ${SOURCES})
endif ()

execute_process(COMMAND ${PERL_EXECUTABLE} -MConfig -e "print \"\$Config{archlib}/CORE\";" OUTPUT_VARIABLE PERL_INCLUDE)
message(STATUS "Perl include directory: ${PERL_INCLUDE}")

execute_process(COMMAND ${PERL_EXECUTABLE} -MConfig -e "print \$Config{libperl};" OUTPUT_VARIABLE PERL_LIB)
find_library(PERL_SHARED_LIBRARY "${PERL_LIB}" ${PERL_INCLUDE} NO_DEFAULT_PATH)
message(STATUS "Perl library: ${PERL_SHARED_LIBRARY}")

get_filename_component(PERL_LIBRARY_DIRECTORY ${PERL_SHARED_LIBRARY} DIRECTORY)
get_filename_component(PERL_STATIC_LIBRARY ${PERL_SHARED_LIBRARY} NAME_WE)
get_filename_component(PERL_LIBRARY_EXTENSION ${PERL_SHARED_LIBRARY} EXT)
set(PERL_STATIC_LIBRARY "${PERL_LIBRARY_DIRECTORY}/${PERL_STATIC_LIBRARY}s${PERL_LIBRARY_EXTENSION}")
message(STATUS "Perl static library: ${PERL_STATIC_LIBRARY}")

option(PERL_STATIC "Whether to use satatic or shared library." NO)
if (PERL_STATIC)
	set(PERL_LIBRARY "${PERL_STATIC_LIBRARY}")
else ()
	set(PERL_LIBRARY "${PERL_SHARED_LIBRARY}")
endif ()

execute_process(COMMAND ${PERL_EXECUTABLE} -MConfig -e "print \$Config{privlibexp};" OUTPUT_VARIABLE PERL_MODULES_DIRECTORY)
message(STATUS "Perl modules folder: ${PERL_MODULES_DIRECTORY}")

execute_process(COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e ccopts OUTPUT_VARIABLE PERL_CCOPTS OUTPUT_STRIP_TRAILING_WHITESPACE)
message(STATUS "Perl CCOPTS: ${PERL_CCOPTS}")

execute_process(COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e ldopts OUTPUT_VARIABLE PERL_LDOPTS OUTPUT_STRIP_TRAILING_WHITESPACE)
message(STATUS "Perl LDOPTS: ${PERL_LDOPTS}")

include_directories(${PERL_INCLUDE})

add_custom_command(OUTPUT CL.c MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/src/CL.xs
	COMMAND ${PERL_EXECUTABLE} ${PERL_MODULES_DIRECTORY}/ExtUtils/xsubpp -typemap ${PERL_MODULES_DIRECTORY}/ExtUtils/typemap ${PROJECT_SOURCE_DIR}/src/CL.xs > CL.c
	COMMENT "Generating file CL.c")
include_directories(${PROJECT_SOURCE_DIR}/src)	# Because CL.c will contain references to header files

add_custom_command(OUTPUT xsinit.c COMMAND ${PERL_EXECUTABLE} -MExtUtils::Embed -e xsinit -- -o xsinit.c CL DynaLoader)

set(PERL_MODULES_SOURCES
	src/CL.pm
	src/CMD.pm
	src/Conf.pm
	src/Config.pm
	src/DCommand.pm
	src/DLWin32.pm
	src/Ex.pm
	src/fields_without_hash_util.pm
	src/Keymap.pm
	src/LE.pm
	src/Main.pm
	src/Mapper.pm
	src/MSDP.pm
	src/MUD.pm
	src/Parser.pm
	src/RStream.pm
	src/Status.pm
	src/Ticker.pm
	src/UAPI.pm)

add_custom_command(OUTPUT perlmodules.c
	MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/src/Main.pm
	DEPENDS ${PROJECT_SOURCE_DIR}/src/Config.pm ${PROJECT_SOURCE_DIR}/src/DLWin32.pm ${PROJECT_SOURCE_DIR}/src/DCommand.pm
		${PROJECT_SOURCE_DIR}/src/Ex.pm ${PROJECT_SOURCE_DIR}/src/Keymap.pm ${PROJECT_SOURCE_DIR}/src/LE.pm
		${PROJECT_SOURCE_DIR}/src/Mapper.pm ${PROJECT_SOURCE_DIR}/src/Parser.pm ${PROJECT_SOURCE_DIR}/src/Status.pm
		${PROJECT_SOURCE_DIR}/src/UAPI.pm ${PROJECT_SOURCE_DIR}/src/RStream.pm ${PROJECT_SOURCE_DIR}/src/CL.pm
		${PROJECT_SOURCE_DIR}/src/MUD.pm ${PROJECT_SOURCE_DIR}/src/CMD.pm ${PROJECT_SOURCE_DIR}/src/Conf.pm
		${PROJECT_SOURCE_DIR}/src/Ticker.pm ${PROJECT_SOURCE_DIR}/src/MSDP.pm ${PROJECT_SOURCE_DIR}/src/Mapper.pm
	COMMAND ${PERL_EXECUTABLE} -I${PROJECT_SOURCE_DIR}/src/ ${PROJECT_SOURCE_DIR}/src/packmod.pl --b2c $<TARGET_FILE:b2c>
		AutoLoader DynaLoader=${PROJECT_SOURCE_DIR}/src/DLWin32.pm Config=${PROJECT_SOURCE_DIR}/src/Config.pm
#		fields=${PROJECT_SOURCE_DIR}/src/fields_without_hash_util.pm
		Carp Carp::Heavy warnings::register warnings
		strict integer vars base locale Exporter Exporter::Heavy Symbol Text::ParseWords Ex CL Conf CMD
		LE Parser MUD Keymap Main RStream DCommand Ticker Status UAPI bytes MIME::Base64
		Hash::Util Scalar::Util List::Util fields MSDP Mapper Data::Dumper constant
		XSLoader > perlmodules.c
	COMMENT "Packing perl modules into perlmodules.c")

add_executable(b2c src/b2c.c)
add_executable(mmc ${SOURCES} ${HEADERS} ${PERL_MODULES_SOURCES})
source_group("Perl modules" FILES ${PERL_MODULES_SOURCES})

set_target_properties(mmc PROPERTIES LINK_FLAGS "/subsystem:windows /opt:ref /opt:icf /DEBUG")
set_target_properties(mmc PROPERTIES COMPILE_FLAGS "${PERL_CCOPTS} /Od")

find_package(ZLIB REQUIRED)
include_directories(${ZLIB_INCLUDE_DIRS})
target_link_libraries(b2c ${ZLIB_LIBRARIES})
target_link_libraries(mmc ${ZLIB_LIBRARIES} ${PERL_LIBRARY})
if (WIN32)
	target_link_libraries(mmc ws2_32.lib winmm.lib version.lib comctl32.lib)
endif()

install(TARGETS mmc DESTINATION .)

# vim: set ts=4 sw=4 tw=0 noet syntax=cmake :
