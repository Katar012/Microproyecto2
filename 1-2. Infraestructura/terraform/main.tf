# Aprovisiona vm-microservices transfiriendo los cookbooks de Chef
resource "null_resource" "provision_microservices" {
  triggers = {
    chef_dir_hash = sha256(join("", [for f in fileset("${path.module}/../chef", "**") : filesha256("${path.module}/../chef/${f}")]))
  }

  connection {
    type     = "ssh"
    host     = var.microservices_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  # Clean up old chef temp files BEFORE transferring new ones
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp/chef"
    ]
  }

  # Copy fresh chef directory
  provisioner "file" {
    source      = "${path.module}/../chef"
    destination = "/tmp/chef"
  }

  # Execute Chef
  provisioner "remote-exec" {
    inline = [
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done",
      "command -v cinc-client >/dev/null 2>&1 || curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-microservices.json"
    ]
  }
}

# Aprovisiona vm-haproxy
resource "null_resource" "provision_haproxy" {
  depends_on = [null_resource.provision_microservices]

  triggers = {
    chef_dir_hash = sha256(join("", [for f in fileset("${path.module}/../chef", "**") : filesha256("${path.module}/../chef/${f}")]))
  }

  connection {
    type     = "ssh"
    host     = var.haproxy_ip
    user     = var.ssh_user
    password = var.ssh_password
  }

  provisioner "file" {
    source      = "${path.module}/../chef"
    destination = "/tmp/chef"
  }

  provisioner "remote-exec" {
    inline = [
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done",
      "command -v cinc-client >/dev/null 2>&1 || curl -L https://omnitruck.cinc.sh/install.sh | sudo bash -s -- -v 18",
      "cd /tmp/chef && sudo cinc-client -z -c /tmp/chef/solo.rb -j /tmp/chef/nodes/vm-haproxy.json"
    ]
  }
}
