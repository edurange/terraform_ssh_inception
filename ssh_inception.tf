variable "students" {
  type = list(object({
    login                  = string,
    password               = object({ plaintext = string, hash = string }),
    fourth_stop_password   = object({ plaintext = string, hash = string }),
    fifth_stop_password    = object({ plaintext = string, hash = string }),
    satans_palace_password = object({ plaintext = string, hash = string }),
    secret_starting_line   = string,
    secret_first_stop      = string,
    secret_second_stop     = string,
    secret_third_stop      = string,
    secret_fourth_stop     = string,
    secret_fifth_stop      = string,
  master_string = string }))
  description = "list of players in the student group"
}

variable "scenario_id" {
  type        = string
  description = "identifier for instance of this scenario"
}

locals {
  common_tags = {
    scenario_id = var.scenario_id
  }
}

resource "random_string" "fifth_stop_password_key" {
  length  = 8
  special = false
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
  key_name   = "ssh_inception/key (${var.scenario_id})"
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
