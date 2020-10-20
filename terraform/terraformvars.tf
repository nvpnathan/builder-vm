# provider variables
variable "vsphere_user" {
  type        = string
  description = "vsphere user"
}

variable "vsphere_password" {
  type = string
}

variable "vsphere_server" {
  type        = string
  description = "vcenter"
}

variable "vm_user" {
  type        = string
  description = "name of the user used for provisioning vm"
}

variable "vm_pwd" {
  type        = string
  description = "pwd of the user used for provisioning vm"
}

variable "datacenter" {
  type        = string
  description = "datacenter object in vcenter"
}

variable "portgroup" {
  type        = string
  description = "network progroup you want to provision to"
}

variable "data_datastore" {
  type        = string
  description = "vSphere Datastore for Data Volumes"
}

variable "vmrp" {
  description = "vsphere resource pool you want to provision to"
}

variable "vm_name" {
  type        = string
  description = "Display name of VM"
}

variable "ip" {
  type        = string
  description = "VM IP"
}

variable "dns" {
  type        = string
  description = "VM DNS"
}

variable "mask" {
  type        = string
  description = "VM Network Mask"
}

variable "gateway" {
  type        = string
  description = "VM Gateway"
}

variable "vm_hostname" {
  type        = string
  description = "VM domain"
}

variable "domain" {
  type        = string
  description = "VM domain"
}

variable "vm_vcpu" {
  type        = string
  description = "VM vCPU"
}

variable "vm_mem" {
  type        = string
  description = "VM Memory"
}

variable "vm_disk_size" {
  type        = string
  description = "VM Disk Size"
}

variable "vm_template" {
  description = "Template used to create the vSphere virtual machines (linked clone)"
}

variable "vm_folder" {
  description = "VM Folder for VM"
}

variable "linked_clone" {
  description = "Linked clone true or false"
}

