
#!/bin/bash
set -x # echo on

# use caution when using -y (automatic "yes")
sudo apt -y update
sudo apt -y upgrade

# install docker
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# use docker as non-root
sudo groupadd docker
sudo usermod -aG docker nathan
sudo systemctl enable docker

# install docker-compose
do curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# stop services for cleanup
sudo service rsyslog stop

# clear audit logs
# -s0 sets the bites to 0 erasing the file
sudo truncate -s0 /var/log/wtmp
sudo truncate -s0 /var/log/lastlog

# create data volume mount directory
mkdir -p /media/data
mkdir -p /media/backup

# add data volume mount to fstab
cat > /tmp/fstab.sh << "EOF"
fstab=/etc/fstab
if ! grep -q '/media/data' /etc/fstab ;
then
    echo "#data-disk" >> /etc/fstab
    echo "/dev/sdb1    /media/data ext4  defaults  0 2" >> /etc/fstab
else
    echo "Entry in fstab exists."
fi
EOF

chmod +x /tmp/fstab.sh
sudo /tmp/./fstab.sh

# add data volume mount to fstab
cat > /tmp/backup-fstab.sh << "EOF"
fstab=/etc/fstab
if ! grep -q '/media/backup' /etc/fstab ;
then
    echo "#backup-disk" >> /etc/fstab
    echo "/dev/sdc1    /media/backup ext4  defaults  0 3" >> /etc/fstab
else
    echo "Entry in fstab exists."
fi
EOF

chmod +x /tmp/backup-fstab.sh
sudo /tmp/./backup-fstab.sh

# mount data volume
sudo mount /dev/sdb1 /media/data

# mount data volume
sudo mount /dev/sdc1 /media/backup

# partition, format & mount data volume
cat > /tmp/data-vol.sh << "EOF"
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

echo yes | mkfs.ext4 /dev/sdb1

sudo mkdir /media/data  
sudo echo '/dev/sdb1    /media/data  ext4  defaults  0 2' >> /etc/fstab  
sudo mount /dev/sdb1 /media/data
EOF

chmod +x /tmp/data-vol.sh
sudo /tmp/./data-vol.sh

# partition, format & mount backup volume
cat > /tmp/backup-vol.sh << "EOF"
#!/bin/bash

# Partition the second disk
(
echo n # Add a new partition  
echo p # Primary partition  
echo 1 # Partition number  
echo   # First sector (Accept default: 1)  
echo   # Last sector (Accept default: varies)  
echo w # Write changes  
) | sudo fdisk /dev/sdc

echo yes | mkfs.ext4 /dev/sdc1

sudo mkdir /media/backup  
sudo echo '/dev/sdc1    /media/data  ext4  defaults  0 3' >> /etc/fstab  
sudo mount /dev/sdc1 /media/backup
EOF

chmod +x /tmp/backup-vol.sh
sudo /tmp/./backup-vol.sh

# change ownership to ubuntu
sudo chown -R nathan:nathan /home/nathan/
sudo chown -R nathan:nathan /media/data/
sudo chown -R nathan:nathan /media/backup/

# cleanup /tmp directories
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# cleanup apt
sudo apt clean

# cleans out all of the cloud-init cache / logs - this is mainly cleaning out networking info
sudo cloud-init clean --logs

# grow the partition
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1

# add remote repo
sudo git clone https://github.com/nvpnathan/pxe-esxi.git /media/data/pxe-esxi

# cleanup shell history
history -c
history -w
