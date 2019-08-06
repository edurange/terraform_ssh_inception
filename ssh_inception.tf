provider "aws" {
  profile    = "default"
  region     = "us-west-1"
}

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

resource "aws_vpc" "Cloud" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "SSH_Inception/Cloud"
  }
}

resource "aws_subnet" "SubnetNAT" {
  vpc_id = "${aws_vpc.Cloud.id}"
  cidr_block = "10.0.129.0/24"
  tags = {
    Name = "SSH_Inception/Cloud/SubnetNAT"
  }
}

resource "aws_subnet" "PlayerSubnet" {
  vpc_id = "${aws_vpc.Cloud.id}"
  cidr_block = "10.0.0.0/27"
  tags = {
    Name = "SSH_Inception/Cloud/PlayerSubnet"
  }
}

resource "aws_instance" "NAT" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.SubnetNAT.id}"
  tags = {
    Name = "SSH_Inception/Cloud/SubnetNAT/NAT"
  }
}

