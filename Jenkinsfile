pipeline {
    agent any
    tools {
      maven "MAVEN3"
      jdk "OracleJDK17"
  }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'
        appRegistry = "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd"
        jenkinscicdRegistry = "https://805619463928.dkr.ecr.us-east-1.amazonaws.com"
    }

  stages {
    stage('Fetch Code'){
      steps {
        git branch: 'main', url: 'https://github.com/saiparthiv/jenkinscicd.git'
      }
    }


    stage('SonarQube Analysis') {
      steps {
        script {
            def scannerHome = tool name: 'SonarQubeScanner', type: 'hudson.plugins.sonar.SonarRunnerInstallation'
            def projectKey = 'jenkinscicd'
            def projectVersion = '1.0'
            
            withSonarQubeEnv('sonar') {
                sh """
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectName='jenkinscicd' \
                        -Dsonar.projectKey='jenkinscicd' \
                        -Dsonar.projectVersion='1.0' \
                   """
            }
        }
      }
    }


    stage('Build Image using Docker') {
       steps {
       
         script {
                dockerImage = docker.build( appRegistry + ":$BUILD_NUMBER", "-f Dockerfile .")
             }

     }
    
    }

    stage('Upload Image to ECR') {
          steps{
            script {
              docker.withRegistry( jenkinscicdRegistry, registryCredential ) {
                dockerImage.push("$BUILD_NUMBER")
                dockerImage.push('latest')
              }
            }
          }
    }


    stage('Deploy to ECS with Terraform') {
      steps {
        script {
          // Set the AWS credentials and region for Terraform
          withAWS(credentials: 'awscreds', region: 'us-east-1') {
            // Define the path to your Terraform script
            def terraformScriptPath = "${WORKSPACE}"

            // Initialize and apply the Terraform configuration
            sh "cd ${terraformScriptPath} && terraform init"
            sh "cd ${terraformScriptPath} && terraform apply -auto-approve"

            // Optionally, capture and save the Terraform outputs for reference
            def ecsClusterId = sh(script: "cd ${terraformScriptPath} && terraform output ecs_cluster_id", returnStatus: true)
            def ecsServiceName = sh(script: "cd ${terraformScriptPath} && terraform output ecs_service_name", returnStatus: true)

            // Print the ECS cluster and service details
            echo "ECS Cluster ID: ${ecsClusterId}"
            echo "ECS Service Name: ${ecsServiceName}"
          }
        }
      }
    }



  }
  post {
        always {
            //Send a Slack Notification
            slackSend(
                  channel: '#jenkinscicd',
                  color: currentBuild.result == 'SUCCESS' ? '#008000' : '#FF0000',
                  message: "Build ${currentBuild.fullName} ${currentBuild.result}"
            )

        }
    }
}

