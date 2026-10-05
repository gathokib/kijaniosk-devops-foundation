variable "name" {
  description = "Name of the KijaniKiosk server."
  type        = string
}

variable "image" {
  description = "Ubuntu image used for the Multipass server."
  type        = string
}

variable "cpus" {
  description = "Number of CPU cores assigned to the server."
  type        = number
}

variable "memory" {
  description = "Amount of memory assigned to the server."
  type        = string
}

variable "disk" {
  description = "Amount of disk space assigned to the server."
  type        = string
}

variable "region" {
  description = "Deployment region identifier."
  type        = string
}

variable "instance_type" {
  description = "Deployment instance type."
  type        = string
}

variable "key_name" {
  description = "SSH key name associated with the server."
  type        = string
}
