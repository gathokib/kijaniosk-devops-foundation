variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "local"
}

variable "region" {
  description = "Deployment region identifier."
  type        = string
  default     = "local"
}

variable "instance_type" {
  description = "Default server size used by the local Multipass deployment."
  type        = string
  default     = "standard"
}

variable "key_name" {
  description = "SSH key name associated with the deployment."
  type        = string
  default     = "kijanikiosk"
}

variable "ubuntu_image" {
  description = "Ubuntu image used for all KijaniKiosk servers."
  type        = string
  default     = "22.04"
}

variable "servers" {
  description = "Definitions for the KijaniKiosk application servers."
  type = map(object({
    cpus   = number
    memory = string
    disk   = string
  }))

  default = {
    api = {
      cpus   = 2
      memory = "2G"
      disk   = "10G"
    }

    payments = {
      cpus   = 2
      memory = "2G"
      disk   = "10G"
    }

    logs = {
      cpus   = 1
      memory = "1G"
      disk   = "10G"
    }
  }
}
