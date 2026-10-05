module "app_server" {
  source   = "./modules/app_server"
  for_each = var.servers

  name          = "kijanikiosk-${each.key}"
  image         = var.ubuntu_image
  cpus          = each.value.cpus
  memory        = each.value.memory
  disk          = each.value.disk
  region        = var.region
  instance_type = var.instance_type
  key_name      = var.key_name
}
