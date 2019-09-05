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
  passwd: ${player.satans_palace_password.hash}
  lock_passwd: false
  shell: /bin/bash
%{ endfor ~}
write_files:
- path: /etc/motd
  encoding: b64
  content: ${filebase64("satans_palace/motd")}
- path: /root/setup_player_home
  encoding: b64
  content: ${filebase64("satans_palace/setup_player_home")}
  permissions: '0550'
runcmd:
- rm /etc/update-motd.d/*
- rm /etc/legal
- hostname satans-palace
- sed -i -e '/^\#Port/s/^.*$/Port 666/' /etc/ssh/sshd_config
%{ for player in players ~}
- ['/root/setup_player_home', '${player.login}', '${player.master_string}']
%{ endfor ~}
- service sshd restart
