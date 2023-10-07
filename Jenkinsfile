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

  }
  post {
        always {
            // Run the Docker image cleanup script
            sh '''
                #!/bin/bash
                image_name="805619463928.dkr.ecr.us-east-1.amazonaws.com/jenkinscicd"
                image_tags=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$image_name" | awk -F ":" '{print $2}')
                if [ -z "$image_tags" ]; then
                    echo "No matching images found."
                else
                    for tag in $image_tags; do
                        if [ "$tag" == "latest" ]; then
                            echo "Keeping image: $image_name:$tag"
                        else
                            docker rmi -f "$image_name:$tag"
                            if [ $? -eq 0 ]; then
                                echo "Removed image: $image_name:$tag"
                            else
                                echo "Failed to remove image: $image_name:$tag"
                            fi
                        fi
                    done
                fi
            '''

            echo 'Slack Notifications.'
            slackSend channel: '#jenkinscicd',
                color: COLOR_MAP[currentBuild.currentResult],
                message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"
        }
    }
}

