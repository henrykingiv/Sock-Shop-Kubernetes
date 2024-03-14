pipeline {
    agent any
    tools {
        terraform 'terraform'
    }
    stages {
        stage('terraform init') {
            steps {
                sh 'terraform init'
            }
        }
        stage('terraform fmt') {
            steps {
                sh 'terraform fmt'
            }
        }
        stage('terraform validate') {
            steps {
                sh 'terraform validate'
            }
        }
        stage('terraform plan') {
            steps {
                sh 'terraform plan'
            }
        }
        stage('terraform action') {
            steps {
                sh 'terraform ${action} -auto-approve'
            }
        }
    }
}