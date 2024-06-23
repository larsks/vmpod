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

exec firectl --kernel /boot/vmlinux --initrd-path /boot/initrd \
	--kernel-opts "console=ttyS0 ip=${ifaddr%/*}::${gateway}:${NETMASK}:${HOSTNAME}:eth0:off $VM_KERNEL_CMDLINE" \
	--root-drive "$root_drive" \
	--tap-device vnic/"${VM_MAC_ADDR}" \
	--ncpus "${VM_CPUS:-1}" \
	--memory "${VM_MEMORY:-512}"
