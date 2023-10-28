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


    stage('Push Images to Nexus') {
     steps {
        script {
            def nexusRepository = 'jenkins_nexus_repo' // Replace with your Nexus repository name
            def nexusCredentialsId = 'nexus' // Replace with your Nexus credentials ID

            def dockerImageTag = "${appRegistry}:${BUILD_NUMBER}"
            def nexusArtifactId = "${JOB_NAME}-${BUILD_NUMBER}"

            // Push the Docker image to Nexus
            nexusArtifactUploader(
                nexusVersion: 'nexus3', // Use 'nexus2' if you are using Nexus 2.x
                protocol: 'docker',
                server: 'http://18.207.144.208:8081', // Replace with your Nexus server URL
                groupId: 'com.example', // Replace with your Nexus group ID
                repository: nexusRepository,
                credentialsId: nexusCredentialsId,
                dockerImageTag: dockerImageTag,
                nexusArtifactId: nexusArtifactId
            )
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

