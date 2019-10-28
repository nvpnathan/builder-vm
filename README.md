# concourse

## Pre-req's
* folder on your datastore called `data_vols`
* Private ssh key in ~/.ssh

## Download the ova

```
wget https://cloud-images.ubuntu.com/releases/18.04/release/ubuntu-18.04-server-cloudimg-amd64.ova
```

## Ubuntu OVA Import

### Extract the OVF spec from the OVA

```
govc import.spec ~/Downloads/ubuntu-18.04-server-cloudimg-amd64.ova | python -m json.tool > ubuntu.json
```

Change `ubuntu.json` hostname, public-keys, Password, Network. It is necessary to set public-keys as Ubuntu cloud images (which the OVAs are) only allow SSH key auth from first-boot – no password-only auth

## Source `govc` variables

```
source govcvars.sh
```

## Deploy the OVA

```
govc import.ova -options=ubuntu.json ~/Downloads/ubuntu-18.04-server-cloudimg-amd64.ova
```

## VM Resources
Change the VM size to 4 vCPUs, 6GB RAM, 200GB disk and set the disk.enableUUID=1 flag (needed for disk identification from the vSphere Cloud Provider in Kubernetes)
**I think I can do all the vm changes in terraform cpu/mem/disk

NOTE: If you use linked clones, then you're stuck with the size of the disk that you specify below. If you use full-clones then you can change the disk size with Terraform. CPU and Memory can be changed with Terraform regardless of full or linked clones.

```
govc vm.change -vm ubuntu-bionic-18.04-cloudimg-20190402 -c 4 -m 6144 -e="disk.enableUUID=1"
govc vm.disk.change -vm ubuntu-bionic-18.04-cloudimg-20190402 -disk.label "Hard disk 1" -size 200G
#govc vm.network.change -vm ubuntu-bionic-18.04-cloudimg-20190402 -net="vlab-mgmt" ethernet-0
```

## Power on VM for Templating
```
govc vm.power -on=true ubuntu-bionic-18.04-cloudimg-20190402
```

## Template prep for 18.04

`ssh ubuntu@<ip-address>`

```
sudo apt update
sudo apt install open-vm-tools -y
sudo apt upgrade -y
sudo apt autoremove -y
```

```
# cleans out all of the cloud-init cache, disable and remove cloud-init customizations
sudo cloud-init clean --logs
sudo touch /etc/cloud/cloud-init.disabled
sudo rm -rf /etc/netplan/50-cloud-init.yaml
sudo apt purge cloud-init -y
sudo apt autoremove -y
```

```
# Don't clear /tmp
sudo sed -i 's/D \/tmp 1777 root root -/#D \/tmp 1777 root root -/g' /usr/lib/tmpfiles.d/tmp.conf

# Remove cloud-init and rely on dbus for open-vm-tools
sudo sed -i 's/Before=cloud-init-local.service/After=dbus.service/g' /lib/systemd/system/open-vm-tools.service
```

```
# cleanup current ssh keys so templated VMs get fresh key
sudo rm -f /etc/ssh/ssh_host_*

# add check for ssh keys on reboot...regenerate if neccessary
sudo tee /etc/rc.local >/dev/null <<EOL
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#

# By default this script does nothing.
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

# make the script executable
sudo chmod +x /etc/rc.local

# cleanup apt
sudo apt clean

# reset the machine-id (DHCP leases in 18.04 are generated based on this... not MAC...)
echo "" | sudo tee /etc/machine-id >/dev/null

# disable swap for K8s
sudo swapoff --all
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

# update grub for error: no such device: root
sudo update-grub

# cleanup shell history and shutdown for templating
history -c
history -w
sudo shutdown -h now
```

# Data Volume Prep (Initial deploy only)

## Script (built-in to Terraform) 

```
#!/bin/bash

# Partition the second disk
(
echo n # Add a new partition  
echo p # Primary partition  
echo 1 # Partition number  
echo   # First sector (Accept default: 1)  
echo   # Last sector (Accept default: varies)  
echo w # Write changes  
) | sudo fdisk /dev/sdb

echo yes | mkfs.ext4 /dev/sdb

sudo mkdir /media/data  
sudo echo '/dev/sdb1    /media/data  ext4  defaults  0 2' >> /etc/fstab  
sudo mount -a
```

## Manually (not needed)

1) Initiate fdisk with the following command:

    ```
    sudo fdisk /dev/sdb
    ```
2) Fdisk will display the following menu:

    ```
    Command (m for help): m <enter>
    Command action
    a   toggle a bootable flag
    b   edit bsd disklabel
    c   toggle the dos compatibility flag
    d   delete a partition
    l   list known partition types
    m   print this menu
    n   add a new partition
    o   create a new empty DOS partition table
    p   print the partition table
    q   quit without saving changes
    s   create a new empty Sun disklabel
    t   change a partition's system id
    u   change display/entry units
    v   verify the partition table
    w   write table to disk and exit
    x   extra functionality (experts only)

    Command (m for help):
    ```

3) We want to add a new partition. Type "n" and press enter.

    ```
    Command action
    e   extended
    p   primary partition (1-4)
    ```

4) We want a primary partition. Enter "p" and enter.

    ```
    Partition number (1-4):
    ```

5) Since this will be the only partition on the drive, number 1. Enter "1" and enter. 

  Command (m for help):
If it asks about the first cylinder, just type "1" and enter. (We are making 1 partition to use the whole disk, so it should start at the beginning.)

6) Now that the partition is entered, choose option "w" to write the partition table to the disk. Type "w" and enter.

  The partition table has been altered!
7) If all went well, you now have a properly partitioned hard drive that's ready to be formatted. Since this is the first partition, Linux will recognize it as /dev/sdb1, while the disk that the partition is on is still /dev/sdb.

## Terraform commands
Useful commands to delete JUST the VM and not the data volume since it's protected.

`terraform state list`

`terraform destroy -target vsphere_virtual_machine.vm`

