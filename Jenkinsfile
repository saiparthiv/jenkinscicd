def COLOR_MAP = [
    'SUCCESS': 'good', 
    'FAILURE': 'danger',
]
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
            // Run the Docker image cleanup script
            sh '''
            #!/bin/bash

            # Define the repository URL
            REPO_URL="805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd"

            # Get a list of all images from the repository
            ALL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "^$REPO_URL")

            # Iterate over each image
            for IMAGE in $ALL_IMAGES; do
              IMAGE_NAME_TAG=$(echo "$IMAGE" | cut -d ' ' -f 1)
              IMAGE_ID=$(echo "$IMAGE" | cut -d ' ' -f 2)

              # Get the image tag
              IMAGE_TAG=$(docker inspect --format='{{.Config.Image}}' "$IMAGE_ID" | cut -d ':' -f 2)

              # Check if the tag is not 'latest' or is empty
              if [ -z "$IMAGE_TAG" ] || [ "$IMAGE_TAG" != "latest" ]; then
                echo "Removing image: $IMAGE_NAME_TAG"
                docker rmi "$IMAGE_NAME_TAG"
              fi
            done

            echo "Cleanup completed."
            '''

            echo 'Slack Notifications.'
            slackSend channel: '#jenkinscicd',
                color: COLOR_MAP[currentBuild.currentResult],
                message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"
        }
    }
}

