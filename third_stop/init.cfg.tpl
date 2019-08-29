#cloud-config
repo_update: true
repo_upgrade: all
ssh_pwauth: no
hostname: third-stop
packages:
- nmap
- iputils-ping
- net-tools
- ftp
- members
users:
- default
%{ for player in players ~}
- name: ${player.login}
  lock_passwd: false
  primary-group: student
  ssh_authorized_keys:
  - ${ssh_public_key}
  shell: /bin/bash
%{ endfor ~}
write_files:
- path: /etc/motd
  content: ${filebase64("third_stop/motd")}
  encoding: b64
runcmd:
- sudo rm /etc/update-motd.d/*
- sudo rm /etc/legal
- sudo hostname third-stop
- service sshd reload
