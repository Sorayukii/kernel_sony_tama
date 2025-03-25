#!/bin/bash

KERNEL_DIR=$(pwd)
OUT_DIR=$KERNEL_DIR/out
KERNEL_IMAGE="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
CLANGDIR="/workspace"
CONFIG_NAME=tama_aurora_kddi_defconfig
BOT_TOKEN="your_bot_token"
CHAT_ID="your_gc_id"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Functions to send Telegram notifications
send_telegram_message() {
    MESSAGE="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE"
}

send_telegram_file() {
    FILE_PATH="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
        -F "chat_id=$CHAT_ID" \
        -F "document=@$FILE_PATH"
}

# Notification if the script is interrupted or encounters an error
error_handler() {
    [ -f log.txt ] && send_telegram_file "log.txt"
    send_telegram_message "⚠️ Compilation was unexpectedly stopped!"
    exit 1
}

# Catch errors and interrupts (moved here)
trap error_handler ERR INT

# Start kernel compilation
send_telegram_message "🔨 Starting kernel compilation for $CONFIG_NAME on branch $BRANCH..."

rm -f log.txt
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

export KBUILD_BUILD_USER=nobody
export KBUILD_BUILD_HOST=android_build
export USE_CCACHE=1
export PATH="$CLANGDIR/bin:$PATH"

make O=$OUT_DIR ARCH=arm64 $CONFIG_NAME
if make -j$(nproc --all) \
    O=$OUT_DIR \
    LLVM=1 \
    LLVM_IAS=1 \
    ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    AS=llvm-as \
    NM=llvm-nm \
    STRIP=llvm-strip \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    READELF=llvm-readelf \
    HOSTCC=clang \
    HOSTCXX=clang++ \
    HOSTAR=llvm-ar \
    HOSTLD=ld.lld \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee -a log.txt; then

    if [ -f "$KERNEL_IMAGE" ] && [ -f log.txt ]; then
        send_telegram_file "$KERNEL_IMAGE"
        send_telegram_file "log.txt"
        send_telegram_message "✅ Compilation completed!"
    else
        send_telegram_file "log.txt"
        send_telegram_message "❌ Compilation failed!"
    fi
fi
