resource "tls_private_key" "third_stop" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "template_cloudinit_config" "third_stop" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "bash_history.cfg"
    content_type = "text/cloud-config"
    merge_type   = "list(append)+dict(recurse_list)"
    content = templatefile("${path.module}/bash_history.yml.tpl", {
      aws_key_id  = var.aws_access_key_id
      aws_sec_key = var.aws_secret_access_key
      scenario_id = var.scenario_id
      players    = var.students
    })
  }

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    merge_type   = "list(append)+dict(recurse_list)"
    content = templatefile("${path.module}/third_stop/init.cfg.tpl", {
      players        = var.students
      ssh_public_key = tls_private_key.third_stop.public_key_openssh
      motd           = file("${path.module}/third_stop/motd")
      hide_credentials = file("${path.module}/third_stop/hide_credentials")
    })
  }
}

resource "aws_instance" "third_stop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.nano"
  private_ip             = "10.0.0.13"
  subnet_id              = aws_subnet.private.id
  depends_on             = [aws_instance.nat]
  key_name               = aws_key_pair.key.key_name
  user_data_base64       = data.template_cloudinit_config.third_stop.rendered
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = merge(local.common_tags, {
    Name = "ssh_inception/third_stop"
  })
  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.key.private_key_pem

    # connect to NAT first, then connect to host
    bastion_user        = "ec2-user"
    bastion_host        = aws_instance.nat.public_ip
    bastion_private_key = tls_private_key.key.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait --long",
    ]
  }
}
