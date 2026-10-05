resource "terraform_data" "server" {
  input = {
    name          = var.name
    image         = var.image
    cpus          = var.cpus
    memory        = var.memory
    disk          = var.disk
    region        = var.region
    instance_type = var.instance_type
    key_name      = var.key_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      multipass launch ${self.input.image} \
        --name ${self.input.name} \
        --cpus ${self.input.cpus} \
        --memory ${self.input.memory} \
        --disk ${self.input.disk}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "multipass delete ${self.input.name} --purge"
  }
}

data "external" "ip" {
  program = ["${path.module}/get_ip.sh", var.name]

  depends_on = [terraform_data.server]
}
