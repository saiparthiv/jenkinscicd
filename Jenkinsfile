def COLOR_MAP = [
    SUCCESS: 'good',      // Green color for successful builds
    FAILURE: 'danger',    // Red color for failed builds
    UNSTABLE: 'warning',  // Yellow color for unstable builds
    ABORTED: 'warning',   // Yellow color for aborted builds
]

pipeline {
    agent any
    tools {
      maven "MAVEN3"
      jdk "OracleJDK17"
      ansible "YourAnsibleInstallation"
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


    stage('Run Ansible Playbook') {
        steps {
            script {
                sh "ansible-galaxy collection install datadog.dd"
                def playbookPath = "${WORKSPACE}/install_datadog.yml"
                
                // Run the Ansible playbook
                def ansibleCommand = "ansible-playbook ${playbookPath} -v"
                def ansibleStatus = sh(script: ansibleCommand, returnStatus: true)

                if (ansibleStatus != 0) {
                    error("Ansible playbook execution failed with status ${ansibleStatus}")
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
                ALL_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "^$REPO_URL")

                # Identify the "latest" image
                LATEST_IMAGE_ID=""
                for IMAGE in $ALL_IMAGES; do
                  IMAGE_NAME=$(echo "$IMAGE" | cut -d: -f1)
                  IMAGE_TAG=$(echo "$IMAGE" | cut -d: -f2)

                  if [ "$IMAGE_TAG" == "latest" ]; then
                    LATEST_IMAGE_ID=$(docker inspect -f '{{.Id}}' "$IMAGE_NAME:$IMAGE_TAG")
                    break
                  fi
                done

                # Iterate over each image
                for IMAGE in $ALL_IMAGES; do
                  IMAGE_NAME=$(echo "$IMAGE" | cut -d: -f1)
                  IMAGE_TAG=$(echo "$IMAGE" | cut -d: -f2)

                  # Check if the tag is not "latest" and the image ID is different from the "latest" image ID
                  IMAGE_ID=$(docker inspect -f '{{.Id}}' "$IMAGE_NAME:$IMAGE_TAG")
                  if [ "$IMAGE_TAG" != "latest" ] && [ "$IMAGE_ID" != "$LATEST_IMAGE_ID" ]; then
                    echo "Removing image: $IMAGE"
                    docker rmi "$IMAGE_NAME:$IMAGE_TAG"
                  fi
                done

                echo "Cleanup completed."


            '''
            //Send a Slack Notification
            echo 'Slack Notifications.'
            slackSend channel: '#jenkinscicd',
                color: COLOR_MAP[currentBuild.currentResult],
                message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"

        }
    }
}

