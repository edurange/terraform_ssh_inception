variable "players" {
  type        = list(object({login=string, password=string, fourth_stop_password=string}))
  description = "list of players"
}

provider "aws" {
  profile = "default"
  region  = "us-west-1"
}

# find most recent official Ubuntu 18.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# find most recent official amazon nat instance ami
data "aws_ami" "nat" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat*"]
  }

  owners = ["amazon"]
}

# create ssh key pair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# upload the public key to aws
resource "aws_key_pair" "key" {
  key_name   = "ssh_inception_key"
  public_key = tls_private_key.key.public_key_openssh
}

# save the private key locally
resource "local_file" "key" {
  sensitive_content = tls_private_key.key.private_key_pem
  filename          = "id_rsa"

  provisioner "local-exec" {
    command = "chmod 600 id_rsa"
  }
}

resource "aws_vpc" "Cloud" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "SSH_Inception/Cloud"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.Cloud.id
}

resource "aws_subnet" "SubnetNAT" {
  vpc_id     = aws_vpc.Cloud.id
  cidr_block = "10.0.129.0/24"
  tags = {
    Name = "SSH_Inception/Cloud/SubnetNAT"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.Cloud.id
  cidr_block = "10.0.0.0/27"
  tags = {
    Name = "SSH_Inception/Cloud/PlayerSubnet"
  }
}

resource "aws_security_group" "public" {
  name   = "NATSG"
  vpc_id = aws_vpc.Cloud.id

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_security_group" "private" {
  vpc_id = aws_vpc.Cloud.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

resource "aws_route_table" "SubnetNATRouteTable" {
  vpc_id = aws_vpc.Cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

resource "aws_route_table_association" "nat_subnet_route_table_association" {
  subnet_id      = aws_subnet.SubnetNAT.id
  route_table_id = aws_route_table.SubnetNATRouteTable.id
}

# Route all traffic outbound from PlayerSubnet to NAT Instance
resource "aws_route_table" "player_subnet_route_table" {
  vpc_id = aws_vpc.Cloud.id

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.nat.id
  }
}

resource "aws_route_table_association" "player_subnet_route_table_association" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.player_subnet_route_table.id
}

resource "aws_instance" "nat" {
  ami                         = data.aws_ami.nat.id
  instance_type               = "t2.nano"
  private_ip                  = "10.0.129.5"
  subnet_id                   = aws_subnet.SubnetNAT.id
  vpc_security_group_ids      = [aws_security_group.public.id]
  associate_public_ip_address = true
  source_dest_check           = false
  user_data                   = templatefile("nat/init.cfg",{
    players = var.players
  })
  key_name                    = aws_key_pair.key.key_name
  tags = {
    Name = "ssh_inception/nat"
  }
}

resource "aws_instance" "starting_line" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.nano"
  private_ip    = "10.0.0.5"
  subnet_id     = aws_subnet.private.id
  depends_on    = [aws_instance.nat]
  key_name      = aws_key_pair.key.key_name

  vpc_security_group_ids = [aws_security_group.private.id]
  user_data              = templatefile("starting_line/init.cfg.tmpl", {
    players = var.players
  })
  tags = {
    Name = "ssh_inception/starting_line"
  }

  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.key.private_key_pem

    bastion_user        = "ec2-user"
    bastion_host        = aws_instance.nat.public_ip
    bastion_private_key = tls_private_key.key.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
    ]
  }
}

resource "aws_instance" "first_stop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.nano"
  private_ip             = "10.0.0.7"
  subnet_id              = aws_subnet.private.id
  depends_on             = [aws_instance.nat]
  key_name               = aws_key_pair.key.key_name
  user_data              = templatefile("first_stop/init.cfg", {
    players = var.players
  })
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = {
    Name = "ssh_inception/first_stop"
  }
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
      "cloud-init status --wait",
    ]
  }
}

resource "tls_private_key" "third_stop" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_instance" "second_stop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.nano"
  private_ip             = "10.0.0.10"
  subnet_id              = aws_subnet.private.id
  depends_on             = [aws_instance.nat]
  key_name               = aws_key_pair.key.key_name
  user_data              = templatefile("second_stop/init.cfg", {
    players          = var.players
    ssh_private_key  = tls_private_key.third_stop.private_key_pem
  })
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = {
    Name = "ssh_inception/second_stop"
  }

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

resource "aws_instance" "third_stop" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.nano"
  private_ip             = "10.0.0.13"
  subnet_id              = aws_subnet.private.id
  depends_on             = [aws_instance.nat]
  key_name               = aws_key_pair.key.key_name
  user_data              = templatefile("third_stop/init.cfg.tpl", {
    players        = var.players
    ssh_public_key = tls_private_key.third_stop.public_key_openssh
  })
  vpc_security_group_ids = [aws_security_group.private.id]
  tags = {
    Name = "ssh_inception/third_stop"
  }
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

#resource "aws_instance" "FourthStop" {
#  ami           = "${data.aws_ami.ubuntu.id}"
#  instance_type = "t2.micro"
#  private_ip    = "10.0.0.16"
#  subnet_id     = "${aws_subnet.private.id}"
#  depends_on    = ["aws_instance.NAT"]
#  tags = {
#    Name = "SSH_Inception/Cloud/PlayerSubnet/FourthStop"
#  }
#}
#resource "aws_instance" "FifthStop" {
#  ami           = "${data.aws_ami.ubuntu.id}"
#  instance_type = "t2.micro"
#  private_ip    = "10.0.0.17"
#  subnet_id     = "${aws_subnet.private.id}"
#  depends_on    = ["aws_instance.NAT"]
#  tags = {
#    Name = "SSH_Inception/Cloud/PlayerSubnet/FifthStop"
#  }
#}
#resource "aws_instance" "SatansPalace" {
#  ami           = "${data.aws_ami.ubuntu.id}"
#  instance_type = "t2.micro"
#  private_ip    = "10.0.0.19"
#  subnet_id     = "${aws_subnet.private.id}"
#  depends_on    = ["aws_instance.NAT"]
#  tags = {
#    Name = "SSH_Inception/Cloud/PlayerSubnet/SatansPalace"
#  }
#}
#resource "aws_instance" "AnonFTP" {
#  ami           = "${data.aws_ami.ubuntu.id}"
#  instance_type = "t2.micro"
#  private_ip    = "10.0.0.14"
#  subnet_id     = "${aws_subnet.private.id}"
#  depends_on    = ["aws_instance.NAT"]
#  tags = {
#    Name = "SSH_Inception/Cloud/PlayerSubnet/AnonFTP"
#  }
#}
