data "template_cloudinit_config" "first_stop" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/first_stop/init.cfg.tpl", {
      players = var.players
      motd = file("${path.module}/first_stop/motd")
    })
  }
}

resource "aws_instance" "first_stop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.nano"
  private_ip             = "10.0.0.7"
  subnet_id              = aws_subnet.private.id
  depends_on             = [aws_instance.nat]
  key_name               = aws_key_pair.key.key_name
  user_data_base64       = data.template_cloudinit_config.first_stop.rendered
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = merge(local.common_tags, {
    Name = "ssh_inception/first_stop"
  })
  connection {
    host        = self.private_ip
    port        = 123
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.key.private_key_pem

    # connect to NAT first, then connect to host
    bastion_user        = "ec2-user"
    bastion_host        = aws_instance.nat.public_ip
    bastion_port        = 22
    bastion_private_key = tls_private_key.key.private_key_pem
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait --long",
    ]
  }
}
