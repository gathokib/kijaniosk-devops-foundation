output "server_names" {
  description = "Names of all provisioned KijaniKiosk servers."
  value = {
    for name, server in module.app_server : name => server.name
  }
}

output "server_ips" {
  description = "Dynamic IPv4 addresses of all provisioned KijaniKiosk servers."
  value = {
    for name, server in module.app_server : name => server.ip_address
  }
}

output "ssh_commands" {
  description = "SSH commands for the provisioned servers."
  value = {
    for name, server in module.app_server :
    name => "ssh ubuntu@${server.ip_address}"
  }
}
