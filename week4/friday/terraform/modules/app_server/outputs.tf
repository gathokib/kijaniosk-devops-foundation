output "name" {
  description = "Name of the Multipass server."
  value       = var.name
}

output "ip_address" {
  description = "Dynamic IPv4 address of the Multipass server."
  value       = data.external.ip.result.ip
}
