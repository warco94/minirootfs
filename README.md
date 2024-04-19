# Mini RootFS

This script creates a very simple rootfs.
It uses BusyBox[https://busybox.net/], in order to provide basic UNIX utilities.

A cross-compilation toolchain is needed for building. The script was tested with an
[ARM toolchain](https://toolchains.bootlin.com/downloads/releases/toolchains/armv5-eabi/tarballs/armv5-eabi--glibc--stable-2023.08-1.tar.bz2),
with glibc C library, for Linux.


## Usage

Please note the requirement about `fakeroot`, to set correct files permissions.
The output is an initramfs CPIO archive, `initramfs.cpio.gz`, as small as about 3MB.

```
fakeroot ./minirootfs.sh arm-buildroot-linux-gnueabi-
```

## Test

The rootfs may be tested with an actual Linux Embedded board, or with a development machine using:
  - [QEMU](https://www.qemu.org/).
  - A recent [Linux](https://www.kernel.org/) kernel.

```
qemu-system-arm -m 128M -M virt -nographic -kernel /path/to/linux-6.8.7/arch/arm/boot/zImage -initrd ./initramfs.cpio.gz -append "root=/dev/ram0"
```

The Linux kernel may be compiled with the same toolchain:

```
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.7.tar.xz
tar xf linux-6.8.7.tar.xz
cd linux-6.8.7
make ARCH=arm CROSS_COMPILE=arm-buildroot-linux-gnueabi- defconfig
make ARCH=arm CROSS_COMPILE=arm-buildroot-linux-gnueabi- kvm_guest.config
make ARCH=arm CROSS_COMPILE=arm-buildroot-linux-gnueabi- zImage
```
