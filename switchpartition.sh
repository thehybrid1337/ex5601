#!/bin/sh

# Check if kmod-mtd-rw is installed
if ! opkg list-installed | grep -q "kmod-mtd-rw"; then
    opkg update
    opkg install kmod-mtd-rw
    if [ $? -ne 0 ]; then
        echo "kmod-mtd-rw failed to install"
        exit 1
    fi
fi


rmmod mtd-rw
ubidetach -p /dev/mtd6

sleep 1

insmod mtd-rw i_want_a_brick=1
if [ $? -ne 0 ]; then
    echo "kmod-mtd-rw failed to load"
    exit 1
fi

ubiattach -p /dev/mtd6
if [ $? -ne 0 ]; then
    echo "mtd6 failed to attach"
    rmmod mtd-rw
    exit 1
fi

sleep 2

dd if=/dev/ubi0_2 of=/tmp/ubi0_2.bin
dd if=/dev/ubi1_2 of=/tmp/ubi1_2.bin

read() {
    local file=$1
    local offset=$2
    hexdump -s $offset -n 1 -v -e '1/1 "%02X"' "$file"
}

write() {
    local file=$1
    local offset=$2
    local value=$3
    echo -ne "\x$value" | dd of="$file" bs=1 seek=$offset count=1 conv=notrunc 2>/dev/null
}

echo "Before:"
byte4_ubi0=$(read /tmp/ubi0_2.bin 4)
byte6_ubi0=$(read /tmp/ubi0_2.bin 6)
byte4_ubi1=$(read /tmp/ubi1_2.bin 4)
byte6_ubi1=$(read /tmp/ubi1_2.bin 6)
echo "ubi0_2: byte4=$byte4_ubi0, byte6=$byte6_ubi0"
echo "ubi1_2: byte4=$byte4_ubi1, byte6=$byte6_ubi1"

write /tmp/ubi0_2.bin 4 $byte4_ubi1
write /tmp/ubi0_2.bin 6 $byte6_ubi1
write /tmp/ubi1_2.bin 4 $byte4_ubi0
write /tmp/ubi1_2.bin 6 $byte6_ubi0

echo "After:"
new_byte4_ubi0=$(read /tmp/ubi0_2.bin 4)
new_byte6_ubi0=$(read /tmp/ubi0_2.bin 6)
new_byte4_ubi1=$(read /tmp/ubi1_2.bin 4)
new_byte6_ubi1=$(read /tmp/ubi1_2.bin 6)
echo "ubi0_2: byte4=$new_byte4_ubi0, byte6=$new_byte6_ubi0"
echo "ubi1_2: byte4=$new_byte4_ubi1, byte6=$new_byte6_ubi1"

ubiupdatevol /dev/ubi0_2 /tmp/ubi0_2.bin
ubiupdatevol /dev/ubi1_2 /tmp/ubi1_2.bin

rm -f /tmp/ubi0_2.bin /tmp/ubi1_2.bin
ubidetach -p /dev/mtd6
rmmod mtd-rw

echo "OK, please reboot"