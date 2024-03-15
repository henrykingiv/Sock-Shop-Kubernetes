#!/bin/bash

sudo yum update -y
sudo dnf install -y ansible-core
sudo yum install python-pip -y
sudo yum install wget -y
sudo yum install unzip -y
sudo bash -c ' echo "StrictHostingKeyChecking No" >> /etc/ssh/ssh_config'

echo "${key}" > /home/ec2-user/.ssh/id_rsa
sudo chmod 400 /home/ec2-user/.ssh/id_rsa
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa


sudo touch /etc/ansible/hosts
sudo chown ec2-user:ec2-user /etc/ansible/hosts
sudo chown -R ec2-user:ec2-user /etc/ansible && chmod +x /etc/ansible


sudo chown -R ec2-user:ec2-user /etc/ansible
sudo chmod 777 /etc/ansible/hosts

sudo echo HAPROXY1: "${haproxy1}" > /home/ec2-user/ha-ip.yml
sudo echo HAPROXY2: "${haproxy2}" >> /home/ec2-user/ha-ip.yml


sudo echo "[haproxy1]" > /etc/ansible/hosts
sudo echo "${haproxy1} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[haproxy2]" >> /etc/ansible/hosts
sudo echo "${haproxy2} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[main-master]" >> /etc/ansible/hosts
sudo echo "${master1} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[member-master]" >> /etc/ansible/hosts
sudo echo "${master2} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${master3} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "[worker]" >> /etc/ansible/hosts
sudo echo "${worker1} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${worker2} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts
sudo echo "${worker3} ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa" >> /etc/ansible/hosts

# sudo su -c "ansible-playbook /home/ec2-user/playbook/install.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/keepalived.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/main-master.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/member-master.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/worker.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/kubectl.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/stage.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/prod.yml" ec2-user
# sudo su -c "ansible-playbook /home/ec2-user/playbook/monitoring.yml" ec2-user

sudo hostnamectl set-hostname ansible
