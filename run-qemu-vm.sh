#!/bin/bash

set -x

: "${VM_KERNEL_CMDLINE:=""}"
: "${VM_MAC_ADDR:=""}"

gateway=$(ip route | awk '$1 == "default" {print $3}')
ifname=$(ip route | awk '$1 == "default" {print $5}')
ifaddr=$(ip addr show $ifname | awk '$1 == "inet" {print $2}')

eval "$(ipcalc -m "${ifaddr}")"

ip addr flush "$ifname"
ip tuntap add dev vnic mode tap
ip link add virbr type bridge
ip link set "$ifname" master virbr
ip link set vnic master virbr

for link in virbr vnic "$ifname"; do
	ip link set "$link" up
done

if [ -f /boot/root.img ]; then
	root_drive="/boot/root.img"
else
	root_drive=/dev/null
fi

if [ -z "$VM_MAC_ADDR" ]; then
	VM_MAC_ADDR="c0:ff:ee$(printf ":%02X" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))"
fi

exec qemu-system-x86_64 -M microvm -accel kvm \
	-m "${VM_MEMORY:-1024}" \
	-smp cpus="${VM_CPUS:-1}" \
	-kernel /boot/vmlinuz \
	-append "earlyprintk=ttyS0 console=ttyS0 ip=${ifaddr%/*}::${gateway}:${NETMASK}:${HOSTNAME}:eth0:off $VM_KERNEL_CMDLINE" \
	-initrd /boot/initrd \
	-drive file="$root_drive",format=raw \
	-device virtio-net-device,id=net0,netdev=net0 \
	-netdev tap,id=net0,ifname=vnic,script=no,downscript=no \
	-parallel none \
	-nographic -serial mon:stdio
