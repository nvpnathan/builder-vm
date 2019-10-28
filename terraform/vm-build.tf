# Configure the VMware vSphere Provider
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  version        = "1.13.0"

  # if you have a self-signed cert
  allow_unverified_ssl = true
}

## vSphere Data Collection
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_resource_pool" "pool" {
  name          = var.vmrp
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "shared_datastore" {
  name          = var.data_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "portgroup" {
  name          = var.portgroup
  datacenter_id = data.vsphere_datacenter.dc.id
}

## Create Resources
resource "random_id" "unique_id" {

  keepers = {
    name = var.vm_name
  }

  byte_length = 4
}

# Create the data disk 
resource "vsphere_virtual_disk" "data_volume" {
  vmdk_path  = "data_vols/${var.vm_name}-data-pd.vmdk"
  size       = 25
  datacenter = var.datacenter
  datastore  = var.data_datastore
  type       = "thin"
  lifecycle {
    prevent_destroy = false
  }
}

resource "vsphere_virtual_disk" "backup_volume" {
  vmdk_path  = "data_vols/${var.vm_name}-bckup-pd.vmdk"
  size       = 100
  datacenter = var.datacenter
  datastore  = var.data_datastore
  type       = "thin"
  lifecycle {
    prevent_destroy = false
  }
}

# Create VM
resource "vsphere_virtual_machine" "vm" {
  name             = "${var.vm_name}-${random_id.unique_id.hex}"
  folder           = var.vm_folder
  num_cpus         = var.vm_vcpu
  memory           = var.vm_mem
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  resource_pool_id = data.vsphere_resource_pool.pool.id

  disk {
    label            = "${var.vm_name}.vmdk"
    size             = var.vm_disk_size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
  }

  disk {
    attach       = true
    path         = vsphere_virtual_disk.data_volume.vmdk_path
    label        = "builder-pd"
    unit_number  = 1
    datastore_id = data.vsphere_datastore.shared_datastore.id
    disk_mode    = "independent_persistent"
  }

  disk {
    attach       = true
    path         = vsphere_virtual_disk.backup_volume.vmdk_path
    label        = "backup-pd"
    unit_number  = 2
    datastore_id = data.vsphere_datastore.shared_datastore.id
    disk_mode    = "independent_persistent"
  }

  network_interface {
    network_id   = data.vsphere_network.portgroup.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    linked_clone  = var.linked_clone

    customize {
      linux_options {
        host_name = var.vm_hostname
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.ip
        ipv4_netmask = var.mask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = [var.dns]
      dns_suffix_list = [var.domain]
    }
  }

  provisioner "file" {
    connection {
      host        = self.default_ip_address
      type        = "ssh"
      user        = var.vm_user
      private_key = file("~/.ssh/id_rsa")
      #password     = "${var.vm_pwd}"
    }
    source      = "../template.sh"
    destination = "/tmp/template.sh"
  }

  provisioner "remote-exec" {
    connection {
      host        = self.default_ip_address
      type        = "ssh"
      user        = var.vm_user
      private_key = file("~/.ssh/id_rsa")
      #password = "${var.vm_pwd}"
    }

    inline = [
      "chmod +x /tmp/template.sh",
      "sudo bash /tmp/template.sh",
    ]
  }

  provisioner "file" {
    connection {
      host        = self.default_ip_address
      type        = "ssh"
      user        = var.vm_user
      private_key = file("~/.ssh/id_rsa")
      #password     = "${var.vm_pwd}"
    }
    source      = "../docker-compose.yaml"
    destination = "/home/nathan/docker-compose.yaml"
  }
}

## Output VM Name, IP address, Hostname

output "VM_IP" {
  value = var.ip
}

output "VM_NAME" {
  value = var.vm_name
}

output "VM_HOSTNAME" {
  value = var.vm_hostname
}

output "SSH" {
  value = "${var.vm_user}@${var.ip}"
}

