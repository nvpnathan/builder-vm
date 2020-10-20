## vSphere Information
vsphere_user = "administrator@vsphere.local"
vsphere_password = "VMware1!"
vsphere_server = "vlab-vcsa.vballin.com"
datacenter = "vlab-dc"
portgroup = "tf-vlab-dmz"
data_datastore = "vlab-nfs-ds-01"
vmrp        = "tf-terraform-vms"
vm_template = "packer-templates/packer-ubuntu-1804-2020-04-13T1586805398"

## VM Information
vm_name = "vlab-builder-01"
vm_user = "nathan"
vm_pwd = "VMware1!"
vm_folder = "terraform-vms" # Must exist
vm_vcpu = "2"
vm_mem = "4096"
vm_disk_size = "32"
linked_clone = "false"

## IP information
ip = "192.168.69.50"
mask = "24"
dns = "192.168.64.60"
gateway = "192.168.69.1"
vm_hostname = "vlab-builder"
domain = "vballin.com"