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
groups:
- student
users:
- default
%{ for player in players ~}
- name: ${player.login}
  groups: student
  lock_passwd: true
  ssh_authorized_keys:
  - ${ssh_public_key}
  shell: /bin/bash
%{ endfor ~}
write_files:
- path: /etc/motd
  content: ${filebase64("third_stop/motd")}
  encoding: b64
- path: /root/hide_credentials
  content: ${filebase64("third_stop/hide_credentials")}
  encoding: b64
  permissions: '0550'
runcmd:
- sudo rm /etc/update-motd.d/*
- sudo rm /etc/legal
- sudo hostname third-stop
%{ for player in players ~}
- /root/hide_credentials ${player.login} ${player.fourth_stop_password.plaintext}
- echo ${player.secret_third_stop} > /home/${player.login}/secret
%{ endfor ~}
- service sshd reload
