#!/usr/bin/env bash
#
# Copyright (C) 2018-2019 Rama Bondan Prakoso (rama982)
#
# Docker Kernel Build Script

# TELEGRAM START
git clone --depth=1 https://github.com/fabianonline/telegram.sh telegram

TELEGRAM=telegram/telegram

tg_channelcast() {
  "${TELEGRAM}" -f "$(echo "$ZIP_DIR"/*.zip)" \
  -t $TELEGRAM_TOKEN \
  -c $CHAT_ID -H \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}
# TELEGRAM END

# Main environtment
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
PARENT_DIR="$(dirname "$KERNEL_DIR")"
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
DTBO_IMG=$KERNEL_DIR/out/arch/arm64/boot/dtbo.img

git submodule update --init --recursive
git clone --depth=1 https://github.com/Ryujinz/anykernel -b main
git clone https://github.com/xyz-prjkt/xRageTC-clang compiler --depth=1

# Build kernel
export TZ="Asia/Jakarta"
export PATH="$PWD/compiler/bin:$PATH"
export KBUILD_COMPILER_STRING="$PWD/compiler/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
export ARCH=arm64
export KBUILD_BUILD_USER="renaldigp"
export KBUILD_BUILD_HOST="ryujin"
KBUILD_BUILD_TIMESTAMP=$(date)

if [ ${TYPE} = "DEBUG" ]; then
    echo "CONFIG_PSTORE=y" >> ${DEFCONFIG}
    echo "CONFIG_PSTORE_CONSOLE=y" >> ${DEFCONFIG}
    echo "CONFIG_PSTORE_PMSG=y" >> ${DEFCONFIG}
    echo "CONFIG_PSTORE_RAM=y" >> ${DEFCONFIG}
    echo "CONFIG_AUDIT=y" >> ${DEFCONFIG}
    echo "# CONFIG_AUDITSYSCALL is not set" >> ${DEFCONFIG}
fi

build_kernel () {
    make -j$(nproc --all) O=out \
        ARCH=arm64 \
        CC=clang \
        AR=llvm-ar OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        OBJCOPY=llvm-objcopy \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

make O=out ARCH=arm64 ${DEFCONFIG}
build_kernel
if ! [ -a $KERN_IMG ]; then
    tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

# Make zip installer

# ENV
ZIP_DIR=$KERNEL_DIR/anykernel

# Modify kernel name in anykernel
sed -i "s/ExampleKernel by osm0sis @ xda-developer/${KERNAME}${TYPE} by renaldigp @ github.com/g" $ZIP_DIR/anykernel.sh

# Make zip
make -C $ZIP_DIR clean
cp $KERN_IMG $ZIP_DIR
cp $DTBO_IMG $ZIP_DIR
make -C $ZIP_DIR normal

KERNEL=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)
FILEPATH=$(echo "$ZIP_DIR"/*.zip)
HASH=$(git log --pretty=format:'%h' -1)
COMMIT=$(git log --pretty=format:'%h: %s' -1)
URL=$(git config --get remote.origin.url)
tg_channelcast "<b>Latest commit:</b> <a href='$URL/commits/$HASH'>$COMMIT</a>" \
               "<b>Device:</b> $SUPPORTED" \
               "<b>Kernel:</b> $KERNEL" \
               "<b>Type:</b> $TYPE" \
               "<b>Firmware:</b> $FIRMWARE" \
               "<b>sha1sum:</b> <pre>$(sha1sum "$FILEPATH" | awk '{ print $1 }')</pre>" \
               "<b>Date:</b> $KBUILD_BUILD_TIMESTAMP"
