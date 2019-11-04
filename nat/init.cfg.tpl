#cloud-config
repo_update: true
repo_upgrade: all
ssh_pwauth: yes
hostname: nat
preserve_hostname: false
packages:
- nmap
- iputils-ping
- net-tools
- ftp
users:
- default
%{ for player in players ~}
- name: ${player.login}
  lock_passwd: false
  passwd: ${player.password.hash}
  shell: /bin/bash
%{ endfor ~}
write_files:
- path: /etc/update-motd.d/30-banner
  content: |2
    #!/bin/sh
    cat << 'EOF'
                    ____    ____    __  __
                   /\  _`\ /\  _`\ /\ \/\ \
                   \ \,\L\_\ \,\L\_\ \ \_\ \
                    \/_\__ \\/_\__ \\ \  _  \
                      /\ \L\ \/\ \L\ \ \ \ \ \
                      \ `\____\ `\____\ \_\ \_\
                       \/_____/\/_____/\/_/\/_/
      ______                                 __
     /\__  _\                               /\ \__  __
     \/_/\ \/     ___     ___     __   _____\ \ ,_\/\_\    ___     ___
        \ \ \   /' _ `\  /'___\ /'__`\/\ '__`\ \ \/\/\ \  / __`\ /' _ `\
         \_\ \__/\ \/\ \/\ \__//\  __/\ \ \L\ \ \ \_\ \ \/\ \L\ \/\ \/\ \
         /\_____\ \_\ \_\ \____\ \____\\ \ ,__/\ \__\\ \_\ \____/\ \_\ \_\
         \/_____/\/_/\/_/\/____/\/____/ \ \ \/  \/__/ \/_/\/___/  \/_/\/_/
                                         \ \_\
                                          \/_/

    Welcome to SSH Inception. The goal is to answer all questions by exploring
    the local network at 10.0.0.0/27.  Your are currently at the NAT Instance.
    Your journey will begin when you login into the next host:

      ssh 10.0.0.5

    For every host you login to you will be greeted with instructions. Each host
    will give you a list of useful commands to solve each challenge. Use man
    pages to help find useful options for commands. For example if the instructions
    say to use the command 'ssh' entering 'man ssh' will print the man page.
    To print this message again, type 'cat message'
 
    Helpful commands: ssh, help, man

    EOF
runcmd:
- rm -f /etc/update-motd.d/{70-available-updates,75-system-update}
- chmod +x /etc/update-motd.d/30-banner
- hostname nat
- update-motd
- service sshd restart
- echo "$(/etc/update-motd.d/30-banner)" > /home/student/message
- sudo echo "$(/etc/update-motd.d/30-banner)" > /etc/motd
