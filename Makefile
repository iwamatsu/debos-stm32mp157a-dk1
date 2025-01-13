
# apt install gcc-arm-linux-gnueabihf gcc-arm-none-eabi

USE_MEM := 4
USE_JOBS := 10
BOARD := stm32mp157a-dk1
DEB_ARCH ?= armhf
SUITE ?= bookworm
IMG_TYPE ?= base
IMG_FORMAT ?= raw
CACHE_MODE ?= pack

BASE_URL = "https://github.com/STMicroelectronics"
# OPTEE
OPTEE_VERSION ?= 3.19.0-stm32mp-r1.1
OPTEE_DOWNLOAD_URL := $(BASE_URL)/optee_os/archive/$(OPTEE_VERSION).tar.gz
OPTEE_PATCHES := 1.patch 2.patch
OPTEE_BIN = out/firmware/optee_os-$(OPTEE_VERSION)/tee-header_v2.bin \
	out/firmware/optee_os-$(OPTEE_VERSION)/tee-pager_v2.bin \
	out/firmware/optee_os-$(OPTEE_VERSION)/tee-pageable_v2.bin

# U-Boot
UBOOT_VERSION ?= 2022.10-stm32mp-r1.1
UBOOT_DOWNLOAD_URL ?= $(BASE_URL)/u-boot/archive/refs/tags/v$(UBOOT_VERSION).tar.gz
UBOOT_DEFCONFIG ?= stm32mp13_defconfig
UBOOT_BIN = out/firmware/u-boot-$(UBOOT_VERSION)/u-boot-nodtb.bin \
	  out/firmware/u-boot-$(UBOOT_VERSION)/u-boot.dtb

# ATF
ATF_VERSION ?= 2.8-stm32mp-r1.1
ATF_DOWNLOAD_URL ?= $(BASE_URL)/arm-trusted-firmware/archive/refs/tags/v$(ATF_VERSION).tar.gz
ATF_BIN = overlay/bootloader/opt/fip.bin \
	  overlay/bootloader/opt/tf-a-$(BOARD).stm32

# Linux kernel
LINUX_TAG ?= 6.1-stm32mp-r1.1
LINUX_VERSION ?= 6.1.28
KDEB_PKGVERSION = $(LINUX_VERSION)-1
LINUX_DOWNLOAD_URL ?= $(BASE_URL)/linux/archive/refs/tags/v$(LINUX_TAG).tar.gz
LINUX_BIN = overlay/linux/opt/linux-image-$(LINUX_VERSION)_$(LINUX_VERSION)-1_$(DEB_ARCH).deb

all: build-atf build-linux build-image

build-image:
	@test -d $(BOARD) || mkdir $(BOARD)

	@test -f overlay/bootloader/opt/fip.bin || \
		echo "no file, please run make build-atf." || exit 1
	@test -f overlay/bootloader/opt/tf-a-$(BOARD).stm32 || \
		echo "no file, please run make build-atf." || exit 1
	@test -f $(LINUX_BIN) || \
		echo "no file, please run make build-linux." || exit 1;

	debos -c $(USE_JOBS) --memory $(USE_MEM)Gb \
		--artifactdir $(BOARD) \
		-t architecture:$(DEB_ARCH) \
		-t suite:$(SUITE) \
		-t image_type:$(IMG_TYPE) \
		-t image_format:$(IMG_FORMAT) \
		-t cache_mode:$(CACHE_MODE) \
		base.yaml

# Linux kernel
downloads/v$(LINUX_VERSION).tar.gz:
	@test -f $@ || wget $(LINUX_DOWNLOAD_URL) -O $@
download-linux: downloads/v$(LINUX_VERSION).tar.gz

build/linux-$(LINUX_VERSION):
	@test -d build/linux-$(LINUX_TAG) || \
		tar -zxf downloads/v$(LINUX_VERSION).tar.gz -C build
expand-linux: download-linux build/linux-$(LINUX_VERSION)

build-linux: expand-linux
	cp configs/linux-6.1-stm32mp_defconfig build/linux-$(LINUX_TAG)/.config

	yes '' | make -C build/linux-$(LINUX_TAG) ARCH=arm olddefconfig
	yes '' | make -C build/linux-$(LINUX_TAG) ARCH=arm \
		CROSS_COMPILE=arm-linux-gnueabihf- \
		KDEB_PKGVERSION=$(KDEB_PKGVERSION) \
		bindeb-pkg -j${USE_JOBS}

	mkdir -p overlay/linux/opt
	cp build/*.deb overlay/linux/opt/.

$(LINUX_BIN): build-linux

# U-Boot
downloads/v$(UBOOT_VERSION).tar.gz:
	@test -f $@ || wget $(UBOOT_DOWNLOAD_URL) -O $@
download-uboot: downloads/v$(UBOOT_VERSION).tar.gz

build/u-boot-$(UBOOT_VERSION):
	@test -d build/u-boot-$(UBOOT_VERSION) || \
		tar -zxf downloads/v$(UBOOT_VERSION).tar.gz -C build
expand-uboot: download-uboot build/u-boot-$(UBOOT_VERSION)

build-uboot: expand-uboot
	cp configs/stm32_defconfig.uboot build/u-boot-$(UBOOT_VERSION)/.config
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- olddefconfig \
       		-C build/u-boot-$(UBOOT_VERSION) \
		-j$(USE_JOBS)
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
		DEVICE_TREE=stm32mp157a-dk1 all \
       		-C build/u-boot-$(UBOOT_VERSION) \
		-j$(USE_JOBS)

	mkdir -p out/firmware/u-boot-$(UBOOT_VERSION)

	cp build/u-boot-$(UBOOT_VERSION)/u-boot-nodtb.bin \
		out/firmware/u-boot-$(UBOOT_VERSION)/.
	cp build/u-boot-$(UBOOT_VERSION)/u-boot.dtb  \
		out/firmware/u-boot-$(UBOOT_VERSION)/.

$(UBOOT_BIN): build-uboot

# OPTEE
downloads/$(OPTEE_VERSION).tar.gz:
	@test -f $@ || wget $(OPTEE_DOWNLOAD_URL) -O $@
download-optee: downloads/$(OPTEE_VERSION).tar.gz

build/optee_os-$(OPTEE_VERSION):
	@test -d build/optee_os-$(OPTEE_VERSION) || \
		tar -zxf downloads/$(OPTEE_VERSION).tar.gz -C build
expand-optee: download-optee build/optee_os-$(OPTEE_VERSION)

build/optee_os-$(OPTEE_VERSION)/patched-stamp:
	for p in $(OPTEE_PATCHES) ; do \
		echo "Patch: $$p" ;\
		patch -d build/optee_os-$(OPTEE_VERSION) -p1 < patches/optee/$$p ;\
	done
	touch build/optee_os-$(OPTEE_VERSION)/patched-stamp
patch-optee: expand-optee build/optee_os-$(OPTEE_VERSION)/patched-stamp

build-optee: patch-optee
	make -C build/optee_os-$(OPTEE_VERSION)/ \
		-j$(USE_JOBS) \
		CROSS_COMPILE=arm-none-eabi- \
		CROSS_COMPILE_core=arm-none-eabi- \
		CROSS_COMPILE_ta_arm32=arm-none-eabi- \
		CFG_ARM32_core=y \
		PLATFORM=stm32mp1 \
		PLATFORM_FLAVOR=157A_DK1 \
		CFG_STM32MP1_OPTEE_IN_SYSRAM=y \
		all

	mkdir -p out/firmware/optee_os-$(OPTEE_VERSION)

	for b in tee-header_v2.bin tee-pager_v2.bin tee-pageable_v2.bin ; do \
		cp build/optee_os-$(OPTEE_VERSION)/out/arm-plat-stm32mp1/core/$${b} \
			out/firmware/optee_os-$(OPTEE_VERSION)/. ; \
	done

# ATF
downloads/v$(ATF_VERSION).tar.gz:
	@test -f $@ || wget $(ATF_DOWNLOAD_URL) -O $@
download-atf: downloads/v$(ATF_VERSION).tar.gz

build/arm-trusted-firmware-$(ATF_VERSION):
	@test -d build/arm-trusted-firmware-$(ATF_VERSION) || \
		tar -xzf downloads/v$(ATF_VERSION).tar.gz -C build
expand-atf: download-atf build/arm-trusted-firmware-$(ATF_VERSION)

build-atf: expand-atf $(UBOOT_BIN) $(OPTEE_BIN)
	make -C build/arm-trusted-firmware-$(ATF_VERSION) \
		-j$(USE_JOBS) \
		CROSS_COMPILE=arm-none-eabi- \
		STM32MP_SDMMC=1 \
		AARCH32_SP=optee \
		DTB_FILE_NAME=$(BOARD).dtb \
		BL33=../../out/firmware/u-boot-$(UBOOT_VERSION)/u-boot-nodtb.bin \
		BL33_CFG=../../out/firmware/u-boot-$(UBOOT_VERSION)/u-boot.dtb \
		STM32MP_USB_PROGRAMMER=1 \
		STM32MP1_OPTEE_IN_SYSRAM=1 \
		PLAT=stm32mp1 \
		TARGET_BOARD= \
		ARM_ARCH_MAJOR=7 \
		ARCH=aarch32 \
		CFG_ARM_core=y \
		BL32=../../out/firmware/optee_os-$(OPTEE_VERSION)/tee-header_v2.bin \
		BL32_EXTRA1=../../out/firmware/optee_os-$(OPTEE_VERSION)/tee-pager_v2.bin \
		BL32_EXTRA2=../../out/firmware/optee_os-$(OPTEE_VERSION)/tee-pageable_v2.bin \
		all fip

	mkdir -p out/firmware/arm-trusted-firmware-$(ATF_VERSION)
	mkdir -p overlay/bootloader/opt

	for b in tf-a-$(BOARD).stm32 fip.bin; do \
		cp build/arm-trusted-firmware-$(ATF_VERSION)/build/stm32mp1/release/$${b} \
			out/firmware/arm-trusted-firmware-$(ATF_VERSION)/. ; \
		cp build/arm-trusted-firmware-$(ATF_VERSION)/build/stm32mp1/release/$${b} \
			overlay/bootloader/opt/. ; \
	done

$(ATF_BIN): build-atf

clean:
	rm -rf build/*

cleanall: clean
	rm -rf downloads/*
	rm -rf out/firmware
	rm -rf overlay/bootloader
	rm -rf $(BOARD)

.PHONY: build-image clean cleanall
