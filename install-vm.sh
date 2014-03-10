#!/bin/bash

NETWORKDEVICE="ifcfg-eth0"

yum install -y virt-install nmap libvirt bridge-utils

./clean.sh

chkconfig libvirtd on

# Create the bridge
cp -f "install/etc/sysconfig/network-scripts/ifcfg-xenbr0" "/etc/sysconfig/network-scripts/ifcfg-xenbr0"
cp -f "/etc/sysconfig/network-scripts/$NETWORKDEVICE" "install/etc/sysconfig/network-scripts/$NETWORKDEVICE"
sed -i "s@^BOOTPROTO=.*@\#BOOTPROTO=@g" "install/etc/sysconfig/network-scripts/$NETWORKDEVICE"
sed -i "s@^BRIDGE=.*@@g" "install/etc/sysconfig/network-scripts/$NETWORKDEVICE"
echo "BRIDGE=xenbr0" >> install/etc/sysconfig/network-scripts/$NETWORKDEVICE
cp -f "/etc/sysconfig/network-scripts/$NETWORKDEVICE" "install/etc/sysconfig/network-scripts/$NETWORKDEVICE.OLD"
cp -f "install/etc/sysconfig/network-scripts/$NETWORKDEVICE" "/etc/sysconfig/network-scripts/$NETWORKDEVICE"

service network restart
service libvirtd start

# Install the virtual machine.
virt-install --name vm-guest --paravirt --ram 512 --file=/var/lib/libvirt/images/guest-os.img --file-size=8 --network bridge=xenbr0 --noautoconsole --nographics --os-type=linux --os-variant=rhel6 --location http://mirrors.maine.edu/CentOS/6.5/os/x86_64/ -x "ks=http://dataport.no-ip.biz:50780/ks.cfg SERVERNAME=server" --force

# Wait for virtual machine installation to finish.
echo "Waiting for virtual machine installation to finish before proceeding..."
while [ $(virsh list | grep vm-guest | wc -l) -ne "0" ]; do
	sleep 10
done

# VM installation has finished. Start it.
virsh start vm-guest

# Wait for vm-guest to come online.
sleep 120 # TODO: find a way to detect when the OS has finished loading.

# Get IP address of vm-guest. First the MAC address must be obtained.
VMGUESTMACADDR=$(xl network-list vm-guest | awk '{print $3}' | grep -v Mac)

VMGUESTIPADDR=$(nmap -sP 192.168.1.0/24 | grep -B 2  | grep hostname_here | awk '{print 2}')

