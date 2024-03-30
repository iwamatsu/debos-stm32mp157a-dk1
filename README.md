Debian image builder for stm32mp157a-dk1

# stm32mp157a-dk1

- [Discovery kit with STM32MP157A MPU](https://www.st.com/en/evaluation-tools/stm32mp157a-dk1.html)

# How to build

## Required packages

- debos
- make 
- gcc-arm-linux-gnueabihf
- gcc-arm-none-eabi
- wget
- bmap-tools

## Build

```
$ make
or
$ make build-atf ; make build-linux ; make build-image
```

If you want to build image with cache,
```
$ make build-image CACHE_MODE=unpack
```

## Writing to micro SD

```
$ sudo sh -c "zcat stm32mp157a-dk1/debian-armhf-bookworm-base.img > /dev/sdX"
```

or

```
$ sudo bmaptool copy --bmap stm32mp157a-dk1/debian-armhf-bookworm-base.bmap \
        stm32mp157a-dk1/debian-armhf-bookworm-base.img /dev/sdX
```

# License

Apache License, Version 2.0

Copyright 2024 Nobuhiro Iwamatsu <iwmaatsu@nigauri.org>

## License for files under patches/optee

The 2-Clause BSD License

- 1.patch:
  https://github.com/OP-TEE/optee_os/commit/359c54b79de65acb91a50acd20d28a166c448510

- 2.patch
  https://github.com/OP-TEE/optee_os/commit/5d6b6c795b8f02995d07ce9af35100b173fb1894
