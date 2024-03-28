#!/bin/bash
echo "${private_key}" >> /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
sudo hostnamectl set-hostname Bastion