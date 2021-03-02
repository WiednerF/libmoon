#!/bin/bash

#FLAGS is filled with arguments for bind-interfaces.sh
FLAGS=""

#OPTIONS is filled with options for cmake
OPTIONS=''
MLX5=false
MLX4=false
MOON=false

while :; do
	case $1 in
		-h|--help)
			echo "Usage: <no option> compile without Mellanox drivers; <-m|--mlx5> compile mlx5; <-n|--mlx4> compile mlx4; <-h|--help> help;"
			exit
			;;
		-m|--mlx5)
			echo "Build with mlx5 driver selected"
			OPTIONS="$OPTIONS""-DUSE_MLX5=ON "
			MLX5=true
			FLAGS="$FLAGS""--mlx5 "
			;;
		-n|--mlx4)
			echo "Build with mlx4 driver selected"
			OPTIONS="$OPTIONS""-DUSE_MLX4=ON "
			MLX4=true
			FLAGS="$FLAGS""--mlx4 "
			;;
		--moongen) #For internal use only
			echo "Build libmoon with MoonGen"
			MOON=true
			;;
		-?*)
			printf 'WARN: Unknown option (abort): %s\n' "$1" >&2
			exit
			;;
		*)
			break
	esac
	shift
done


# TODO: this should probably be a makefile
(
cd $(dirname "${BASH_SOURCE[0]}")
git submodule update --init --recursive

NUM_CPUS=$(cat /proc/cpuinfo  | grep "processor\\s: " | wc -l)

(
cd deps/luajit
make -j $NUM_CPUS BUILDMODE=static 'CFLAGS=-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'
make install DESTDIR=$(pwd)
)

(
# Build the DPDK dependencies for igb_uio driver module
cd deps/dpdk-kmods/linux/igb_uio
make -j $NUM_CPUS
)

export PKG_CONFIG_PATH=$(pwd)/deps/dpdk/x86_64-native-linux-gcc/lib/x86_64-linux-gnu/pkgconfig/:$PKG_CONFIG_PATH

(
cd deps/dpdk
#build DPDK with the right configuration
sed -ri 's,(CONFIG_RTE_LIBRTE_IEEE1588=).*,\1y,' config/common_base
if ${MLX5} ; then
	sed -ri 's,(MLX5_PMD=).*,\1y,' config/common_base
fi
if ${MLX4} ; then
	sed -ri 's,(MLX4_PMD=).*,\1y,' config/common_base
fi
CC=gcc meson -Dexamples=false -Ddisable_drivers=event/*,net/dpaa,net/dpaa2 --prefix=$(pwd)/x86_64-native-linux-gcc x86_64-native-linux-gcc
echo "#define RTE_LIBRTE_IEEE1588 1" >> ./x86_64-native-linux-gcc/rte_build_config.h
ninja -C x86_64-native-linux-gcc
ninja -C x86_64-native-linux-gcc install
)

(
cd lua/lib/turbo
make 2> /dev/null
if [[ $? > 0 ]]
then
	echo "Could not compile Turbo with TLS support, disabling TLS"
	echo "Install libssl-dev and OpenSSL to enable TLS support"
	make SSL=none
fi
)

(
cd deps/highwayhash
make
)

(
if ! ${MOON}
then
	cd build
else	
	cd ../build
fi
PKG_CONFIG_PATH=$PKG_CONFIG_PATH cmake ${OPTIONS}..
PKG_CONFIG_PATH=$PKG_CONFIG_PATH make -j $NUM_CPUS
)

echo Trying to bind interfaces, this will fail if you are not root
echo Try "sudo ./bind-interfaces.sh" if this step fails
./bind-interfaces.sh ${FLAGS}
)

