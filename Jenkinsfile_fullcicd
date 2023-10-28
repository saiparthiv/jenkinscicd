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
      ansible "ansible"
  }

    environment {
        registryCredential = 'ecr:us-east-1:awscreds'
        appRegistry = "805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd"
        jenkinscicdRegistry = "https://805619463928.dkr.ecr.us-east-1.amazonaws.com"
    }

  stages {

    stage('Fetch Code') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'githublogin', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD')]) {
                        // Use the GIT_CREDENTIAL variable for Git authentication
                        checkout([
                            $class: 'GitSCM',
                            branches: [[name: '*/main']],
                            userRemoteConfigs: [[
                                url: 'https://github.com/saiparthiv/jenkinscicd.git',
                                credentialsId: 'githublogin' // Use the same credentials ID as in 'withCredentials'
                            ]]
                        ])
                    }
                }
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


    stage('Deploy ECS with Terraform') {
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


    stage('Run Ansible Playbook to install Datadog') {
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
             
            sh '''
            #!/bin/bash

            # Define the image name
            image_name="805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd"

            # Check if the image exists
            if docker images | awk '{print $1}' | grep -q "^$image_name$"; then
                # Remove the image
                docker rmi $image_name
                if [ $? -eq 0 ]; then
                    echo "Image $image_name removed successfully."
                else
                    echo "Failed to remove image $image_name."
                    exit 1
                fi
            else
                echo "Image $image_name not found on the host machine."
            fi
            '''
            //Send a Slack Notification
            echo 'Slack Notifications.'
            slackSend channel: '#jenkinscicd',
                color: COLOR_MAP[currentBuild.currentResult],
                message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"

        }
    }
}

