pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                Build the application
            }
        }
        stage('Test') {
            steps {
                Test the application
            }
        }
        stage('Deploy') {
            steps {
                Deploy the application
            }
        }
    }
}
