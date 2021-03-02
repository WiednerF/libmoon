CMAKE_MINIMUM_REQUIRED(VERSION 2.8)
PROJECT(libmoon C CXX)

option(USE_MLX5 "Compile with mlx5 driver" OFF)
option(USE_MLX4 "Compile with mlx4 driver" OFF)

SET(CMAKE_CXX_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu++11 -march=native -msse4.2")
SET(CMAKE_C_FLAGS "-fno-stack-protector -Wall -Wextra -Wno-unused-parameter -g -O3 -std=gnu11 -march=native -msse4.2")
SET(CMAKE_EXE_LINKER_FLAGS "-rdynamic") # to access functions from luajit

SET(FILES
	src/main
	src/memory
	src/task
	src/device
	src/i40e
	src/util
	src/lifecycle
	src/barrier
	src/task-results
	src/pipe
	src/lock
	src/namespaces
	src/ring
	src/filter
	src/pcap
	src/timestamping
	src/timestamping_i40e
	src/timestamping_ixgbe
	src/timestamping_igb
	src/bytesizedring
	src/pktsizedring
)

SET(LUAJIT_LIBS
	luajit-5.1
)

SET(HIGHWAYHASH_LIBS
	highwayhash
)

find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  pkg_check_modules(dpdk IMPORTED_TARGET libdpdk)
endif()

# add tbb
include(${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb/cmake/TBBBuild.cmake)
tbb_build(TBB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb CONFIG_DIR TBB_DIR)
# find the cmake configuration file
find_package(TBB)


SET(ALL_LIBS
    ${dpdk_STATIC_LDFLAGS}
	-Wl,--whole-archive
	${LUAJIT_LIBS}
	${HIGHWAYHASH_LIBS}
	${TBB_IMPORTED_TARGETS}
	pthread dl rt
	-Wl,--no-whole-archive
)

INCLUDE_DIRECTORIES(
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/x86_64-native-linux-gcc/include
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/bnxt
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/ixgbe/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/ixgbe
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/i40e/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/i40e
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/e1000
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/drivers/net/e1000/base
	${CMAKE_CURRENT_SOURCE_DIR}/deps/luajit/src
	${CMAKE_CURRENT_SOURCE_DIR}/deps/highwayhash/highwayhash
	${CMAKE_CURRENT_SOURCE_DIR}/deps/tbb/include
	${CMAKE_CURRENT_SOURCE_DIR}/lib
	${CMAKE_CURRENT_SOURCE_DIR}/src
)

LINK_DIRECTORIES(
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/x86_64-native-linux-gcc/lib
	${CMAKE_CURRENT_SOURCE_DIR}/deps/dpdk/x86_64-native-linux-gcc/drivers
	${CMAKE_CURRENT_SOURCE_DIR}/deps/luajit/usr/local/lib
	${CMAKE_CURRENT_SOURCE_DIR}/deps/highwayhash/lib
	${CMAKE_CURRENT_SOURCE_DIR}/build/tbb_cmake_build/tbb_cmake_build_subdir_release
)

IF(LIBMOON_BUILD_LIBRARY)
	ADD_DEFINITIONS(-DLIBMOON_BUILD_LIB)
	# we want libmoon.a, not liblibmoon.a
	ADD_LIBRARY(moon STATIC ${FILES})
	TARGET_LINK_LIBRARIES(moon PUBLIC ${ALL_LIBS})
ELSE()
	ADD_EXECUTABLE(libmoon ${FILES})
	TARGET_LINK_LIBRARIES(libmoon PUBLIC ${ALL_LIBS})
ENDIF()

