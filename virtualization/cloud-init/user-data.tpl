#cloud-config
# Declarative template only. Runtime rendering must inject the public SSH key.
hostname: ubuntu-devops
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
package_update: true
package_upgrade: false
packages:
  - openssh-server
  - qemu-guest-agent
users:
  - default
  - name: __VM_ADMIN_USER__
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - __VM_ADMIN_SSH_PUBLIC_KEY__
runcmd:
  - [systemctl, enable, --now, qemu-guest-agent]
  - [systemctl, enable, --now, ssh]
