#cloud-config
repo_update: true
repo_upgrade: all
ssh_pwauth: yes
hostname: satans-palace
groups:
- student
users:
- default
%{ for player in players ~}
- name: ${player.login}
  groups: student
  passwd: ${player.satans_palace_password_hash}
  lock_passwd: false
  shell: /bin/bash
%{ endfor ~}
write_files:
- path: /etc/motd
  encoding: b64
  content: ${filebase64("satans_palace/motd")}
runcmd:
- rm /etc/update-motd.d/*
- rm /etc/legal
- hostname satans-palace
- sed -i -e '/^\#Port/s/^.*$/Port 666/' etc/ssh/sshd_config
%{ for player in players ~}
- "echo exit >> /home/${player.login}/.bashrc"
%{ endfor ~}
- service sshd reload

