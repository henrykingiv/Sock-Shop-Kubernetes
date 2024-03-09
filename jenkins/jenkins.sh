#!/bin/bash
sudo yum update -y
sudo yum upgrade -y
sudo yum install git -y
sudo yum install wget -y
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo yum-get update
sudo yum-get install jenkins -y
sudo yum install openjdk-11-jre -y
sudo yum install jenkins -y
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo hostnamectl set-hostname jenkins