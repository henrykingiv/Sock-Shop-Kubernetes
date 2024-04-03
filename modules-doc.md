# ANSIBLE/PLAYBOOK
Introduction
This Terraform code defines an AWS EC2 instance resource of type "aws_instance" named "ansible". The purpose of this instance is to host an ansible server in the AWS environment, specifically within the European region ("eu"). The code is part of a modular approach, with the ansible-specific configurations organized in a separate module.

Ansible was configured to help us configure our master, worker and HA-proxy server to serve different purposes for this project.

# CHALLENGES WITH KUBERNETES INSTALLER
Installation of the Kubernetes packages prove challenging as the kubernetes.oi had moved the package from its google.cloud host into another package installer. A little research from my end, I was able to notice this change and made the effect on my playbook code. Please find attached below.

The codes are highlighted below:
resource "aws_instance" "ansible" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ansible-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-id
  user_data                   = templatefile("./module/ansible/ansible.sh", {
    key = var.private_key,
    haproxy1 = var.HAproxy1,
    haproxy2 = var.HAproxy2,
    master1  = var.master1,
    master2  = var.master2,
    master3  = var.master3,
    worker1  = var.worker1,
    worker2  = var.worker2,
    worker3  = var.worker3
  })

  tags = {
    Name = var.tag-ansible
  }
}

resource "null_resource" "copy-playbook" {
  connection {
    type = "ssh"
    host = aws_instance.ansible.private_ip
    user = "ubuntu"
    private_key = var.private_key
    bastion_host = var.bastion_host
    bastion_user = "ubuntu"
    bastion_private_key = var.private_key
  }
  provisioner "file" {
    source = "./module/ansible/playbook"
    destination = "/home/ubuntu/playbook"
  }
}

resource "aws_security_group" "ansible" {
  name        = "ansible-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.tag-ansible-sg
  }
}

module "ansible" {
  source         = "./module/ansible"
  ami            = "ami-0c1c30571d2dae5c9"
  ansible-sg     = data.aws_security_group.k8s-sg.id
  instance_type  = "t2.micro"
  keyname        = module.keypair.public-key
  subnet-id      = data.aws_subnet.prvtsub02.id
  private_key    = module.keypair.private-key
  HAproxy1       = module.ha-proxy.ha-proxy1-pri-ip
  HAproxy2       = module.ha-proxy.ha-proxy2-pri-ip
  master1        = module.master-node.master_private_ip[0]
  master2        = module.master-node.master_private_ip[1]
  master3        = module.master-node.master_private_ip[2]
  worker1        = module.worker-node.worker_private_ip[0]
  worker2        = module.worker-node.worker_private_ip[1]
  worker3        = module.worker-node.worker_private_ip[2]
  tag-ansible    = "${local.name}-ansible"
  bastion_host   = module.bastion-host.bastion_ip
  vpc_id         = data.aws_vpc.vpc.id
  tag-ansible-sg = "${local.name}-ansible-sg"
}

# PLAYBOOKS
# INSTALL.YML
---
  - name: Install k8s dependencies on master and worker nodes.
    hosts: main-master, member-master, worker
    remote_user: ubuntu
    become: true
    become_method : sudo
    become_user: root
    gather_facts: true
    connection: ssh

    tasks:
     - name : update and upgrade ubuntu environment
       shell: |
                sudo apt update

     - name : Add k8s repo to ubuntu
       shell: |
                sudo apt -y install curl apt-transport-https
                curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

     - name: Install required packages before installing kubelet, kubectl and kubeadm
       shell: |
                sudo apt update
                sudo apt -y install vim git curl wget kubelet kubeadm kubectl
                sudo apt-mark hold kubelet kubeadm kubectl

     - name : Disable swap and confirm that the setting is correct
       shell: |
                sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
                sudo swapoff -a
                sudo mount -a
                free -h
    
     - name : Enable Kernel modules
       shell: |
                sudo modprobe overlay
                sudo modprobe br_netfilter

     - name : Add some settings to sysctl
       shell: |
          sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
          net.bridge.bridge-nf-call-ip6tables = 1
          net.bridge.bridge-nf-call-iptables = 1
          net.ipv4.ip_forward = 1

     - name : Reload sysctl
       command: sudo sysctl --system

     - name : Install docker container runtime
       shell: |
                sudo apt update
                sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
                sudo apt update
                sudo apt install -y containerd.io docker-ce docker-ce-cli

     - name: Create directory
       shell: sudo mkdir -p /etc/systemd/system/docker.service.d
     - name: Add conf for containerd
       shell: |
          sudo tee /etc/docker/daemon.json <<EOF
          {
             "exec-opts": ["native.cgroupdriver=systemd"],
             "log-driver": "json-file",
             "log-opts": {
             "max-size": "100m"
             },
            "storage-driver": "overlay2"
          }
          EOF

     - name: Enable and start docker service
       shell: |
                sudo systemctl daemon-reload
                sudo systemctl restart docker
                sudo systemctl enable docker

     - name: Install required packages before downloading cri-dockerd
       shell: |
                sudo apt update
                sudo apt install git wget curl

     - name: downlaod the latest binary package of cri-dockerd
       shell: |
                VER=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest|grep tag_name | cut -d '"' -f 4|sed 's/v//g')
                wget https://github.com/Mirantis/cri-dockerd/releases/download/v${VER}/cri-dockerd-${VER}.amd64.tgz
                tar xvf cri-dockerd-${VER}.amd64.tgz

     - name: Move cri-dockerd binary package to /usr/local/bin directory
       shell: sudo mv cri-dockerd/cri-dockerd /usr/local/bin/

     - name: configure systemd units for cri-dockerd
       shell: |
                wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
                wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
                sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
                sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

     - name: Start and enable the services
       shell: |
                sudo systemctl daemon-reload
                sudo systemctl enable cri-docker.service
                sudo systemctl enable --now cri-docker.socket

# KEEPALIVED
- hosts: haproxy1
    become: true
    vars_files:
      - /home/ubuntu/ha-ip.yml

    tasks:
      - name: Installation of keepalived
        shell: sudo apt install keepalived -y

      - name: Configure keepalived
        shell: |
          sudo bash -c 'echo "
          vrrp_instance haproxy-vip1 {
            state MASTER
            priority 100
            interface ens5
            virtual_router_id 60
            advert_int 1
            authentication {
              auth_type PASS
              auth_pass 1234
            }
            unicast_src_ip "{{HAPROXY1}}"
            unicast_peer {
              "{{HAPROXY2}}"
            }
            virtual_ipaddress {
              10.0.101.19/24
            }
          } " > /etc/keepalived/keepalived.conf'
      - name: Restart keepalived
        shell: |
          sudo systemctl restart keepalived
          sudo systemctl enable keepalived

  - hosts: haproxy2
    become: true
    vars_files:
      - /home/ubuntu/ha-ip.yml

    tasks:
      - name: Installation of keepalived
        shell: sudo apt install keepalived -y

      - name: Configure keepalived
        shell: |
          sudo bash -c 'echo "
          vrrp_instance haproxy-vip2 {
            state BACKUP
            priority 99
            interface ens5
            virtual_router_id 60
            advert_int 1
            authentication {
              auth_type PASS
              auth_pass 1234
            }
            unicast_src_ip "{{HAPROXY2}}"
            unicast_peer {
              "{{HAPROXY1}}"
            }
            virtual_ipaddress {
              10.0.101.19/24
            }
          } " > /etc/keepalived/keepalived.conf'
      - name: Restart keepalived
        shell: |
          sudo systemctl restart keepalived
          sudo systemctl enable keepalived

# KUBECTL
---
 - hosts: haproxy1
   tasks:
     - name: Copy the file from ansible host to ha-lb
       copy: src=/home/ubuntu/config dest=/home/ubuntu

     - name: make directory and copy required file to it
       shell: |
        sudo su -c 'mkdir -p $HOME/.kube' ubuntu
        sudo su -c 'mv /home/ubuntu/config /home/ubuntu/.kube' ubuntu
        sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu

     - name: Install Kubectl
       shell: sudo snap install kubectl --classic

     - name: Install weave pod network
       command: kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml


 - hosts: haproxy2
   tasks:
     - name: Copy the file from ansible host to ha-lb
       copy: src=/home/ubuntu/config dest=/home/ubuntu

     - name: make directory and copy required file to it
       shell: |
        sudo su -c 'mkdir -p $HOME/.kube' ubuntu
        sudo su -c 'mv /home/ubuntu/config /home/ubuntu/.kube' ubuntu
        sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu

     - name: Install Kubectl
       shell: sudo snap install kubectl --classic

     - name: Install weave pod network
       command: kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# MAIN-MASTER
- hosts: main-master
  become: true
  vars_files: 
    - /home/ubuntu/ha-ip.yml

  tasks:
    
    - name: Initialize Kubernetes on Master Node
      shell: sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket /run/cri-dockerd.sock --upload-certs --control-plane-endpoint {{HAPROXY1}}:6443
      register: output

    - name: Storing Logs and Generated token for future purpose.
      local_action: copy content={{ output.stdout }} dest="/tmp/token" mode=0777
    
    - name: make directory and copy required file to it
      shell: |
        sudo su -c 'mkdir -p $HOME/.kube' ubuntu
        sudo su -c 'sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config' ubuntu
        sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu
    
    - name: Fetch the config file from the main-master to ansible host
      run_once: true
      fetch: src=/home/ubuntu/.kube/config dest=/home/ubuntu/ flat=yes

- hosts: member-master
  become: true
  gather_facts: true
  tasks:

    - name: Generated token to join master.
      local_action: shell sed -n 73,75p /tmp/token > /tmp/mastertoken
    
    - name: Copy master token
      copy:
        src: /tmp/mastertoken
        dest: /tmp/join-command
        owner: root
        group: root
        mode: '0777'

    - name: Insert socket url at the back of token
      shell: sed -i '$ s/$/\ --cri-socket\ unix:\/\/\/var\/run\/cri-dockerd.sock/g' /tmp/join-command

    - name: Add new Kubernetes master member
      command: sh /tmp/join-command
    
    - name: make directory and copy required file to it
      shell: |
        sudo su -c 'mkdir -p $HOME/.kube' ubuntu
        sudo su -c 'sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config' ubuntu
        sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu

---
- name: Download and install Prometheus stack Helm chart
  hosts: haproxy1
  become: true

  vars:
    namespace: monitoring
    prometheus_port: 31090
    grafana_port: 31300

  tasks:
  - name: Download and unpack Helm
    shell: |
      wget https://get.helm.sh/helm-v3.5.2-linux-amd64.tar.gz
      tar -xvf helm-v3.5.2-linux-amd64.tar.gz
      mv linux-amd64/helm /usr/local/bin/helm
      rm -rvf helm-v3.5.2-linux-amd64.tar.gz

  - name: Create namespace
    shell: sudo su -c "kubectl create namespace "{{ namespace }}"" ubuntu

  - name: Add the Prometheus stack Helm repo
    shell: sudo su -c "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts" ubuntu

  - name: Update the Helm repo
    shell: sudo su -c "helm repo update" ubuntu

  - name: Install & Expose Prometheus & Grafana service
    shell: sudo su -c "helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace "{{ namespace }}" --set prometheus.service.nodePort="{{ prometheus_port }}" --set prometheus.service.type=NodePort --set grafana.service.nodePort="{{ grafana_port }}" --set grafana.service.type=NodePort" ubuntu

---
 - hosts: haproxy1
   become: true
   tasks:

    - name: Deleting Previous Deployment to prod-shop
      shell: sudo su -c "kubectl delete -f prod-complete.yaml" ubuntu
      ignore_errors: true
      args:
        chdir: US-Team-Sock-Shop-App-Repo/deploy/kubernetes

    - name: Deploying Latest Features to prod-shop
      shell: sudo su -c "kubectl apply -f prod-complete.yaml" ubuntu
      args:
        chdir: US-Team-Sock-Shop-App-Repo/deploy/kubernetes

---
 - hosts: haproxy1
   become: true

   tasks:

    - name: Checking if Application Repo exist on haproxy server
      stat:
        path: /home/ubuntu/US-Team-Sock-Shop-App-Repo
      register: repo_exists

    - name: Cloning Application Repo
      git:
        repo: https://github.com/CloudHight/US-Team-Sock-Shop-App-Repo.git
        dest: /home/ubuntu/US-Team-Sock-Shop-App-Repo
      when: not repo_exists.stat.exists

    - name: Updating Application Repo
      shell:
        cmd: git pull
        chdir: /home/ubuntu/US-Team-Sock-Shop-App-Repo
      when: repo_exists.stat.exists

    - name: Deleting Previous Deployment to stage-shop
      shell: sudo su -c "kubectl delete -f staging-complete.yaml" ubuntu
      ignore_errors: true
      args:
        chdir: US-Team-Sock-Shop-App-Repo/deploy/kubernetes

    - name: Deploying Latest Features to stage-shop
      shell: sudo su -c "kubectl apply -f staging-complete.yaml" ubuntu
      args:
        chdir: US-Team-Sock-Shop-App-Repo/deploy/kubernetes

- hosts: worker
  remote_user: ubuntu
  become: true
  become_method: sudo
  become_user: root
  gather_facts: true
  connection: ssh

  tasks:

     - name: Generated token - 1.
       local_action: shell sed -n 83,84p /tmp/token > /tmp/workertoken
      
     - name: Copy Worker token
       copy:
        src: /tmp/workertoken
        dest: /tmp/join-worker-command
        owner: root
        group: root
        mode: '0777'

     - name: Insert socket url at the back of token       
       shell: sed -i '$ s/$/\ --cri-socket\ unix:\/\/\/var\/run\/cri-dockerd.sock/g' /tmp/join-worker-command

     - name: Join Workers to Masters
       command: sudo sh /tmp/join-worker-command
   
     - name: Copy the file from ansible host to worker nodes
       copy: src=/home/ubuntu/config dest=/home/ubuntu

     - name: make directory and copy required file to it
       shell: |
        sudo su -c 'mkdir -p $HOME/.kube' ubuntu
        sudo su -c 'mv /home/ubuntu/config /home/ubuntu/.kube' ubuntu
        sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu

# Ansible user bash script
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

# Bastion-Host
Introduction
This Terraform code defines an AWS EC2 instance resource of type "aws_instance" named "bastion". The purpose of this instance is to host a bastion server in the AWS environment, and acts as a jumpbox to all our available servers. The code is part of a modular approach, with the Bastion-specific configurations organized in a separate module.

resource "aws_instance" "bastion" {
  ami                         = var.ami
  vpc_security_group_ids      = [aws_security_group.Bastion-sg.id]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-id
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/bastion-script.sh", {
    private_key = var.private_key
  })

  tags = {
    Name = var.tag-bastion
  }
}

# Creating Bastion and Ansible security group
resource "aws_security_group" "Bastion-sg" {
  name        = "Bastion-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = var.tag-Bastion-sg
  }
}

module "bastion-host" {
  source         = "./module/bastion-host"
  ami            = "ami-0c1c30571d2dae5c9"
  instance_type  = "t2.micro"
  keyname        = module.keypair.public-key
  subnet-id      = data.aws_subnet.pubsub01.id
  private_key    = module.keypair.private-key
  tag-bastion    = "${local.name}-bastion"
  vpc_id         = data.aws_vpc.vpc.id
  tag-Bastion-sg = "${local.name}-bastion-sg"
}

# Bastion-Host script
#!/bin/bash
echo "${private_key}" >> /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
sudo hostnamectl set-hostname Bastion

# Grafana and Prometheus
Overview
The load balancer resource is an essential component in a Grafana/Prometheus environment, ensuring high availability and efficient distribution of incoming traffic across multiple instances. This setup utilizes AWS resources to create an application load balancer (ALB) along with target groups and listeners.

Terraform Code
Below is the Terraform code used to define the load balancer and related resources:

grafana/main.tf:

resource "aws_lb" "grafana_lb" {
  load_balancer_type = "application"
  subnets = var.subnets
  security_groups = [var.grafana_sg]
  enable_deletion_protection = false
  tags = {
    Name = "grafana-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "grafana-tg" {
  name     = "grafana-tg"
  port     = 31300
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 5
    healthy_threshold    = 3
    unhealthy_threshold  = 5  
    path = "/graph"
    
 }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "grafana-http" {
  load_balancer_arn = aws_lb.grafana_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "grafana-https" {
  load_balancer_arn = aws_lb.grafana_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "grafana-tg-attachment" {
  target_group_arn = aws_lb_target_group.grafana-tg.arn
  target_id        = element(split(",", join(",", var.instance)), count.index)
  port             = 31300
  count            = 3
}
#Create Route 53 Record
resource "aws_route53_record" "grafana_record" {
  zone_id = var.route53_zone_id
  name    = var.grafana_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.grafana_lb.dns_name
    zone_id                = aws_lb.grafana_lb.zone_id
    evaluate_target_health = true
  }
}

# Prometheus/main.tf
resource "aws_lb" "prome_lb" {
  load_balancer_type = "application"
  subnets = var.subnets
  security_groups = [var.prome_sg]
  enable_deletion_protection = false
  tags = {
    Name = "prome-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "prome-tg" {
  name     = "prome-tg"
  port     = 31090
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 5
    healthy_threshold    = 3
    unhealthy_threshold  = 5  
    path = "/graph"
    
 }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "prome-http" {
  load_balancer_arn = aws_lb.prome_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prome-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "prome-https" {
  load_balancer_arn = aws_lb.prome_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prome-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "prome-tg-attachment" {
  target_group_arn = aws_lb_target_group.prome-tg.arn
  target_id        = element(split(",", join(",", var.instance)), count.index)
  port             = 31090
  count            = 3
}
#Create Route 53 Record
resource "aws_route53_record" "prome_record" {
  zone_id = var.route53_zone_id
  name    = var.prome_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.prome_lb.dns_name
    zone_id                = aws_lb.prome_lb.zone_id
    evaluate_target_health = true
  }
}

module "promethues" {
  source            = "./module/promethues"
  subnets           = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  prome_sg          = data.aws_security_group.k8s-sg.id
  vpc_id            = data.aws_vpc.vpc.id
  cert_acm          = data.aws_acm_certificate.amazon_issued.arn
  instance          = module.worker-node.workernode-id
  route53_zone_id   = data.aws_route53_zone.route53_zone.zone_id
  prome_domain_name = "promethues.henrykingroyal.co"
}

module "grafana" {
  source              = "./module/grafana"
  subnets             = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  grafana_sg          = data.aws_security_group.k8s-sg.id
  vpc_id              = data.aws_vpc.vpc.id
  cert_acm            = data.aws_acm_certificate.amazon_issued.arn
  instance            = module.worker-node.workernode-id
  route53_zone_id     = data.aws_route53_zone.route53_zone.zone_id
  grafana_domain_name = "grafana.henrykingroyal.co"
}

# HA-PROXY
Introduction:
Keepalived is an open-source software package that provides high availability for Linux systems by monitoring network services and automatically failing over to standby servers in case of failure. It is commonly used in scenarios where uninterrupted service availability is critical, such as load balancers, web servers, and network appliances.

This documentation aims to provide a comprehensive guide to configuring Keepalived using YAML format, specifically focusing on defining Virtual Router Redundancy Protocol (VRRP) instances for high availability of services.
resource "aws_instance" "ha-proxy-1" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ha-proxy-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-1
  user_data                   = templatefile("./module/ha-proxy/ha-proxy-1.sh", {
    master1 = var.master1
    master2 = var.master2
    master3 = var.master3

  })

  tags = {
    Name = var.tag-ha-proxy1
  }
}

resource "aws_instance" "ha-proxy-2" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.ha-proxy-sg]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  subnet_id                   = var.subnet-2
  user_data                   = templatefile("./module/ha-proxy/ha-proxy-2.sh", {
    master1 = var.master1
    master2 = var.master2
    master3 = var.master3

  })

  tags = {
    Name = var.tag-ha-proxy2
  }
}

module "ha-proxy" {
  source        = "./module/ha-proxy"
  ami           = "ami-0c1c30571d2dae5c9"
  ha-proxy-sg   = data.aws_security_group.k8s-sg.id
  instance_type = "t3.medium"
  keyname       = module.keypair.public-key
  subnet-1      = data.aws_subnet.prvtsub01.id
  master1       = module.master-node.master_private_ip[0]
  master2       = module.master-node.master_private_ip[1]
  master3       = module.master-node.master_private_ip[2]
  tag-ha-proxy1 = "${local.name}-ha-proxy1"
  subnet-2      = data.aws_subnet.prvtsub02.id
  tag-ha-proxy2 = "${local.name}-ha-proxy2"
}

# Prod/Stage Load Balancer
A production load balancer is a crucial component in distributed computing environments, particularly in web applications, where it serves to efficiently distribute incoming network traffic across multiple servers or resources. The primary purpose of a load balancer is to optimize resource utilization, maximize throughput, minimize response time, and ensure high availability of services by evenly distributing incoming requests

Here are some key aspects and functionalities of a production load balancer:

Traffic Distribution: The load balancer evenly distributes incoming requests across multiple servers, nodes, or resources based on predefined algorithms such as Round Robin, Least Connections, IP Hashing, or other custom methods.

High Availability: Load balancers are often deployed in redundant configurations to eliminate single points of failure. In case one load balancer fails, another one takes over seamlessly to ensure continuous operation.

Health Checks: Load balancers regularly monitor the health and status of backend servers. If a server becomes unavailable or unresponsive, the load balancer will automatically reroute traffic to healthy servers, thus ensuring reliability.

SSL Termination: Many modern load balancers provide SSL termination, offloading the SSL/TLS encryption and decryption process from backend servers. This reduces the computational load on servers and improves overall performance.

Session Persistence: Some applications require that subsequent requests from the same client are sent to the same backend server to maintain session state. Load balancers can support session persistence (also known as sticky sessions) to ensure continuity of sessions.

Scalability: Load balancers facilitate horizontal scaling by allowing easy addition or removal of backend servers as per demand fluctuations. This ensures that the system can handle increased traffic without degradation in performance.

Logging and Monitoring: Production load balancers often provide logging and monitoring capabilities, allowing administrators to track traffic patterns, analyze performance metrics, and troubleshoot issues effectively.

Security: Load balancers can provide security features such as DDoS protection, Web Application Firewall (WAF), and access control mechanisms to safeguard against malicious attacks and unauthorized access.

resource "aws_lb" "prod_lb" {
  name = "prod-lb"
  load_balancer_type = "application"
  subnets = (var.subnets)
  security_groups = [var.prod_sg]
  
  tags = {
    Name = "prod-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "prod-tg" {
  name     = "prod-tg"
  port     = 30002
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 4
    healthy_threshold    = 3
    unhealthy_threshold  = 3
   }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "prod-http" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "prod-https" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.prod_cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "prod-tg-attachment" {
  target_group_arn = aws_lb_target_group.prod-tg.arn
  target_id        = element(split(",", join(",","${var.instance}")),count.index)
  port             = 30002
  count = 3
}
#Create Route 53 Record
resource "aws_route53_record" "stage_record" {
  zone_id = var.route53_zone_id
  name    = var.prod_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.prod_lb.dns_name
    zone_id                = aws_lb.prod_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb" "stage_lb" {
  name = "stage-lb"
  load_balancer_type = "application"
  subnets = var.subnets
  security_groups = [var.stage_sg]

  
  tags = {
    Name = "stage-lb"
  }
}

#Create Target Group
resource "aws_lb_target_group" "stage-tg" {
  name     = "stage-tg"
  port     = 30001
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    interval             = 30
    timeout              = 4
    healthy_threshold    = 3
    unhealthy_threshold  = 3
   }
}
#Create LB Listener for HTTP
resource "aws_lb_listener" "stage-http" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-tg.arn
  }
}
#Create LB Listener for HTTPS
resource "aws_lb_listener" "stage-https" {
  load_balancer_arn = aws_lb.stage_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.stage_cert_acm

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage-tg.arn
  }
}

#Target group attachment
resource "aws_lb_target_group_attachment" "stage-tg-attachment" {
  target_group_arn = aws_lb_target_group.stage-tg.arn
  target_id        = element(split(",", join(",","${var.instance}")),count.index)
  port             = 30001
  count = 3
}
#Create Route 53 Record
resource "aws_route53_record" "stage_record" {
  zone_id = var.route53_zone_id
  name    = var.stage_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.stage_lb.dns_name
    zone_id                = aws_lb.stage_lb.zone_id
    evaluate_target_health = true
  }
}

module "prod-lb" {
  source           = "./module/prod-lb"
  subnets          = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  prod_sg          = data.aws_security_group.k8s-sg.id
  vpc_id           = data.aws_vpc.vpc.id
  prod_cert_acm    = data.aws_acm_certificate.amazon_issued.arn
  instance         = module.worker-node.workernode-id
  route53_zone_id  = data.aws_route53_zone.route53_zone.zone_id
  prod_domain_name = "prod.henrykingroyal.co"
}

module "stage-lb" {
  source            = "./module/stage-lb"
  subnets           = [data.aws_subnet.pubsub01.id, data.aws_subnet.pubsub02.id, data.aws_subnet.pubsub03.id]
  stage_sg          = data.aws_security_group.k8s-sg.id
  vpc_id            = data.aws_vpc.vpc.id
  stage_cert_acm    = data.aws_acm_certificate.amazon_issued.arn
  instance          = module.worker-node.workernode-id
  route53_zone_id   = data.aws_route53_zone.route53_zone.zone_id
  stage_domain_name = "stage.henrykingroyal.co"

}

# Worker and Master Nodes

Overview
This Terraform configuration is designed to create multiple worker and master nodes on AWS to be part of a computing cluster or similar infrastructure setup.

resource "aws_instance" "master" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.security-group]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  count                       = 3
  subnet_id                   = element(var.subnet-id, count.index)
  user_data                   = <<-EOF
  #!/bin/bash
  sudo hostnamectl set-hostname master-$(hostname -1)
  EOF

  tags = {
    Name = "${var.instance_name}${count.index}"
  }
}

resource "aws_instance" "worker" {
  ami                         = var.ami
  vpc_security_group_ids      = [var.security-group]
  instance_type               = var.instance_type
  key_name                    = var.keyname
  count                       = 3
  subnet_id                   = element(var.subnet-id, count.index)
  user_data                   = <<-EOF
  #!/bin/bash
  sudo hostnamectl set-hostname worker-$(hostname -1)
  EOF

  tags = {
    Name = "${var.instance_name}${count.index}"
  }
}

module "master-node" {
  source         = "./module/master-node"
  ami            = "ami-0c1c30571d2dae5c9"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type  = "t3.medium"
  keyname        = module.keypair.public-key
  subnet-id      = [data.aws_subnet.prvtsub01.id, data.aws_subnet.prvtsub02.id, data.aws_subnet.prvtsub03.id]
  instance_name  = "${local.name}-master"
}

module "worker-node" {
  source         = "./module/worker-node"
  ami            = "ami-0c1c30571d2dae5c9"
  security-group = data.aws_security_group.k8s-sg.id
  instance_type  = "t3.medium"
  keyname        = module.keypair.public-key
  subnet-id      = [data.aws_subnet.prvtsub01.id, data.aws_subnet.prvtsub02.id, data.aws_subnet.prvtsub03.id]
  instance_name  = "${local.name}-worker"
}