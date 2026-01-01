export ROOT_DIR := $(realpath $(CURDIR))
export PATH := $(ROOT_DIR)/gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu/bin:$(PATH)

minos_deps:
	sudo apt-get update
	sudo apt-get install abootimg device-tree-compiler

minos_tools:
	@if [ ! -f gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu.tar.xz ]; then \
		wget https://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/aarch64-linux-gnu/gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu.tar.xz && \
		tar -xJvf gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu.tar.xz; \
	fi

minos_src_dl:
	@if [ ! -d minos ]; then \
		git clone https://github.com/zhugengyu/minos.git; \
	fi
	@if [ ! -d u-boot ]; then \
		git clone https://github.com/zhugengyu/u-boot.git; \
	fi
	@if [ ! -f linux-4.19.238.tar.gz ]; then \
		wget https://mirrors.edge.kernel.org/pub/linux/kernel/v4.x/linux-4.19.238.tar.gz && \
		tar xvzf linux-4.19.238.tar.gz && \
		echo "obj-y += minos/" >> linux-4.19.238/drivers/Makefile && \
		cp -r minos/generic/minos-linux-driver linux-4.19.238/drivers/minos; \
	fi
	@if [ ! -f virtio-sd.img.tar.xz ]; then \
		wget https://github.com/zhugengyu/minos-workspace/releases/download/0.1/virtio-sd.img.tar.xz && \
		tar -xJvf virtio-sd.img.tar.xz;\
	fi
# 	@if [ ! -f ramdisk.bin ]; then \
# 		wget https://github.com/zhugengyu/minos-workspace/releases/download/0.0/ramdisk.bin; \
# 	fi

minos_uboot_build:
	cd u-boot && \
		make qemu_arm64_defconfig CROSS_COMPILE=aarch64-linux-gnu- && \
		make -j10 CROSS_COMPILE=aarch64-linux-gnu-

minos_kernel_build:
	cd linux-4.19.238 && \
		make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig && \
		make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j8 Image

minos_hypervisor_build:
	cd minos && \
		make qemu_arm64_defconfig && \
		make
	cd minos/tools/mkrmd && \
		make

minos_ramdisk_build:
	./minos/tools/mkrmd/mkrmd -f ramdisk.bin linux-4.19.238/arch/arm64/boot/Image ./qemu-virt.dtb

minos_prepare_sdboot:
	mkdir sdboot
	sudo mount -o loop,offset=32256 virtio-sd.img sdboot
	sudo cp minos/minos.bin sdboot/kernel.bin
	sudo cp minos/dtbs/qemu-arm64.dtb sdboot/
	sudo cp ramdisk.bin sdboot/

minos_run:
	~/env-work/qemu/build-aarch64/qemu-system-aarch64 -nographic -bios u-boot/u-boot.bin \
		-M virtualization=on,gic-version=3 \
		-cpu cortex-a53 -machine type=virt -smp 4 -m 2G -machine virtualization=true \
		-drive if=none,file=virtio-sd.img,format=raw,id=hd0 \
		-device virtio-blk-device,drive=hd0 \
		-device virtio-net-device,netdev=net0 -netdev user,id=net0,hostfwd=tcp:127.0.0.1:5555-:22	