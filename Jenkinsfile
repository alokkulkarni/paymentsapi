pipeline {
    agent any
    environment {
        DOCKER_REGISTRY = 'https://hub.docker.com/alokkulkarni'  // Replace with your registry
        IMAGE_NAME = 'paymentsapi'
        IMAGE_TAG = "${BUILD_NUMBER}"
        // SONAR_PROJECT_KEY = 'paymentsapi'
        // AWS_REGION = 'eu-west-2'  // Adjust as needed
        // S3_BUCKET = 'paymentsapi'  // Replace with your S3 bucket
        // KUBECONFIG = credentials('eks-kubeconfig')  // Jenkins credential ID for kubeconfig
        // SCAN_S3_BUCKET = 'your-security-reports-bucket'  // Add this line
        GITHUB_REPO = 'alokkulkarni/paymentsapi'  // Replace with your GitHub org/repo
        GITHUB_BRANCH = 'main'  // Replace with your default branch
    }
    tools {
        jdk 'JDK 17'  // Make sure this matches your Jenkins tool configuration
    }
    stages {
        stage('Debug Env') {
            steps {
                sh 'uname -a'
                sh 'which docker || echo "Docker not found"'
                sh 'ls /var/run/docker.sock || echo "Socket not mounted"'
            }
        }
        stage('Checkout') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: "*/${GITHUB_BRANCH}"]],
                    extensions: [],
                    userRemoteConfigs: [[
                        credentialsId: 'jenkinsgithubappak',
                        url: "https://github.com/alokkulkarni/paymentsapi.git"
                    ]]
                ])
            }
        }
        stage('Build') {
            steps {
                sh 'chmod +x /var/jenkins_home/workspace/paymentsapi'
                sh 'chmod +x *'
                sh 'ls -l ./gradlew'
                sh 'chmod +x ./gradlew'
                sh 'bash ./gradlew clean build -x test'
            }
        }
        stage('Test') {
            steps {
                script {
                    def workspace = pwd()
                    sh """
                        cd ${workspace}
                        bash ./gradlew test jacocoTestReport
                        bash ./gradlew pitest
                    """
                    junit allowEmptyResults: true, testResults: '**/build/test-results/test/*.xml'
                    jacoco(
                        execPattern: "**/*.exec",
                        classPattern: "**/*main*",
                        sourcePattern: "**/*.java",
                        exclusionPattern: "**/*Test*"
                    )
                }
            }
        }
        stage('Generate SBOM') {
            steps {
                script {
                    def workspace = pwd()
                    sh """
                        cd ${workspace}
                        bash ./gradlew cyclonedxBom
                        mkdir -p sbom-artifacts
                        cp sbom/* sbom-artifacts/
                    """
                    archiveArtifacts artifacts: 'sbom-artifacts/*', fingerprint: true
                }
            }
        }
        // stage('Analyze SBOM for Vulnerabilities') {
        //     steps {
        //         // Use Grype or other tool to scan SBOM for vulnerabilities
        //         grypeScan autoInstall: false, repName: 'grypeReport_${JOB_NAME}_${BUILD_NUMBER}.txt', scanDest: 'dir:sbom-artifacts'
        //         archiveArtifacts artifacts: '*', fingerprint: true
        //     }
        // }
        stage('Run Grype SBOM Scan') {
            steps {
                script {
                    def grypeVersion = 'v0.65.0'   // Change as needed
                    def osName = sh(script: "uname | tr '[:upper:]' '[:lower:]'", returnStdout: true).trim()
                    def arch = 'amd64'             // Adjust if needed

                    // Use one SBOM file path from sbom-artifacts, e.g. bom.xml or JSON file
                    def sbomFile = 'sbom-artifacts/*.xml'  
                    def reportFile = 'grype-report.json'

                    sh """
                    # Download and install Grype
                    curl -sSfL https://github.com/anchore/grype/releases/download/${grypeVersion}/grype_${grypeVersion.replaceFirst('v','')}_${osName}_${arch}.tar.gz -o grype.tar.gz
                    tar -xzf grype.tar.gz
                    chmod +x grype
                    mv grype /usr/local/bin/grype

                    # Verify installation
                    grype version

                    # Run Grype scan on the SBOM file and output JSON report
                    grype sbom:${sbomFile} -o json > ${reportFile}

                    echo "Grype scan complete. Report saved as ${reportFile}"
                    """
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                 withSonarQubeEnv('sonarqubeak') {
                    sh """
                        bash ./gradlew sonar -Dsonar.host.url="http://192.168.1.174:9000" -Dsonar.projectKey=alokkulkarni_paymentsapi -Dsonar.jacocoPath="**/build/test-results/test/*.xml"
                    """
                }
            }
        }
        // stage('Export Reports to S3') {
        //     steps {
        //         withAWS(region: "${AWS_REGION}", credentials: 'aws-credentials') {  // Configure AWS credentials in Jenkins
        //             sh """
        //                 aws s3 cp build/test-results/test s3://${S3_BUCKET}/${BUILD_NUMBER}/test-reports/ --recursive
        //                 aws s3 cp build/reports/jacoco s3://${S3_BUCKET}/${BUILD_NUMBER}/coverage-reports/ --recursive
        //                 aws s3 cp build/reports/pitest s3://${S3_BUCKET}/${BUILD_NUMBER}/mutation-reports/ --recursive
        //                 aws s3 cp sbom-artifacts s3://${S3_BUCKET}/${BUILD_NUMBER}/sbom/ --recursive
        //                 aws s3 cp vulnerability-reports s3://${S3_BUCKET}/${BUILD_NUMBER}/vulnerability-reports/ --recursive
        //             """
        //         }
        //     }
        // }
        stage('Build and Push Docker Image') {
            steps {
                script {
                    docker.withRegistry("${DOCKER_REGISTRY}", 'docker-credential') {  // Configure Docker credentials in Jenkins
                        def customImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                        customImage.push()
                        customImage.push('latest')
                    }
                }
            }
        }
        // stage('Container Security Scan') {
        //     steps {
        //         script {
        //             def workspace = pwd()
        //             def scanScript = "${workspace}/scripts/container-scan.sh"
        //             sh """
        //                 cd ${workspace}
        //                 ${scanScript} -i "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" \
        //                             -b "${SCAN_S3_BUCKET}" \
        //                             -f "json" \
        //                             -s "HIGH,CRITICAL" \
        //                             -R "${AWS_REGION}"
        //             """
        //         }
        //     }
        // }
        // stage('Deploy to EKS') {
        //     steps {
        //         script {
        //             def workspace = pwd()
        //             withKubeConfig([credentialsId: 'eks-kubeconfig']) {
        //                 sh """
        //                     cd ${workspace}
        //                     helm upgrade --install paymentsapi helm/paymentsapi \
        //                         --namespace dev \
        //                         --create-namespace \
        //                         --set image.repository=${DOCKER_REGISTRY}/${IMAGE_NAME} \
        //                         --set image.tag=${IMAGE_TAG} \
        //                         --set sbom.enabled=true \
        //                         -f helm/paymentsapi/values-dev.yaml
        //                 """
        //             }
        //         }
        //     }
        // }
    }
    post {
        always {
            script {
                if (getContext(hudson.FilePath)) {
                    deleteDir()
                }
            }
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}