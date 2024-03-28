#!/bin/bash

sudo apt-get update -y 
sudo apt-get install software-properties-common -y
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible python3-pip -y

echo "${key}" > /home/ubuntu/.ssh/id_rsa
sudo chmod 400 /home/ubuntu/.ssh/id_rsa
sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa


sudo touch /etc/ansible/hosts
sudo chown ubuntu:ubuntu /etc/ansible/hosts
sudo chown -R ubuntu:ubuntu /etc/ansible && chmod +x /etc/ansible


sudo chown -R ubuntu:ubuntu /etc/ansible
sudo chmod 777 /etc/ansible/hosts

sudo echo HAPROXY1: "${haproxy1}" > /home/ubuntu/ha-ip.yml
sudo echo HAPROXY2: "${haproxy2}" >> /home/ubuntu/ha-ip.yml

echo "[all:vars]" > /etc/ansible/hosts
echo "ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'" >> /etc/ansible/hosts
sudo echo "[haproxy1]" >> /etc/ansible/hosts
sudo echo "${haproxy1} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[haproxy2]" >> /etc/ansible/hosts
sudo echo "${haproxy2} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[main-master]" >> /etc/ansible/hosts
sudo echo "${master1} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[member-master]" >> /etc/ansible/hosts
sudo echo "${master2} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${master3} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[worker]" >> /etc/ansible/hosts
sudo echo "${worker1} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${worker2} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${worker3} ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa" >> /etc/ansible/hosts

sudo su -c "ansible-playbook /home/ubuntu/playbook/install.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/keepalived.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/main-master.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/member-master.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/worker.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/kubectl.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/stage.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/prod.yml" ubuntu
sudo su -c "ansible-playbook /home/ubuntu/playbook/monitoring.yml" ubuntu

sudo hostnamectl set-hostname ansible