def appVersion = ''

pipeline {
    agent any
    environment {
        DOCKER_REGISTRY = 'https://hub.docker.com/repositories/alokkulkarni'  // Replace with your registry
        IMAGE_NAME = 'paymentsapi'
        IMAGE_TAG = "${BUILD_NUMBER}"
        // SONAR_PROJECT_KEY = 'paymentsapi'
        // AWS_REGION = 'eu-west-2'  // Adjust as needed
        // S3_BUCKET = 'paymentsapi'  // Replace with your S3 bucket
        // KUBECONFIG = credentials('eks-kubeconfig')  // Jenkins credential ID for kubeconfig
        // SCAN_S3_BUCKET = 'your-security-reports-bucket'  // Add this line
        GITHUB_REPO = 'alokkulkarni/paymentsapi'  // Replace with your GitHub org/repo
        GITHUB_BRANCH = 'main'  // Replace with your default branch
        TRIVY_VERSION = "0.24.0"  // Set the Trivy version to install
        TRIVY_INSTALL_PATH = "/usr/local/bin/trivy"  // Path to install Trivy
    }
    tools {
        jdk 'JDK 17'  // Make sure this matches your Jenkins tool configuration
    }
    stages {
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
                    def sbomFile = sh(script: "ls sbom-artifacts/*.xml", returnStdout: true).trim()
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
                    grype sbom:${sbomFile} -o json --add-cpes-if-none > ${reportFile}

                    echo "Grype scan complete. Report saved as ${reportFile}"
                    """
                }
            }
        }
        stage('SonarQube Analysis') {
            steps {
                 withSonarQubeEnv('sonarToken') {
                    sh """
                        bash ./gradlew sonar -Dsonar.host.url="http://192.168.86.243:9000" -Dsonar.projectKey=alokkulkarni_paymentsapi -Dsonar.jacocoPath="**/build/test-results/test/*.xml"
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
        stage('Setup Docker Buildx') {
            steps {
                sh '''
                    if ! docker buildx version > /dev/null 2>&1; then
                        echo "Installing Docker Buildx..."
                        mkdir -p ~/.docker/cli-plugins
                        curl -SL https://github.com/docker/buildx/releases/download/v0.12.0/buildx-v0.12.0.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
                        chmod +x ~/.docker/cli-plugins/docker-buildx
                        docker buildx create --use || true
                    fi
                    docker buildx version
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                        if (fileExists('pom.xml')) {
                            appVersion = sh(
                                script: """
                                    grep '<version>' pom.xml | head -1 | sed -E 's/.*<version>([^<]+)<\\/version>.*/\\1/' | sed 's/-SNAPSHOT//' | xargs
                                """,
                                returnStdout: true
                            ).trim()
                        } else if (fileExists('build.gradle')) {
                            appVersion = sh(
                                script: '''
                                    grep ^version build.gradle | sed -E "s/version[ \\t]*=[ \\t]*[\\"\\']([^\\\"\\']+)[\\"\\']/\\1/" | sed 's/-SNAPSHOT//' | xargs
                                ''',
                                returnStdout: true
                            ).trim()
                        }

                        if (!appVersion) {
                            appVersion = '0.0.1'
                        }

                        echo "Building Docker image with and paymentsapi:v${appVersion}"

                        sh "docker buildx build --platform=linux/amd64 --load -t ${GITHUB_REPO}:v${appVersion} -f Dockerfile ."
                }
            }
        }

        stage('Check and Install Trivy') {
            steps {
                script {
                    // Check if Trivy is installed
                    def trivyInstalled = sh(script: "which trivy", returnStatus: true)
                    
                    // If Trivy is not installed, install it
                    if (trivyInstalled != 0) {
                        echo "Trivy not found, installing..."

                        // Debugging: print current working directory and available files
                        sh "pwd"
                        sh "ls -l"

                        // Attempt to install Trivy
                        try {
                            sh """
                                curl -sfL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-x86_64.tar.gz -o trivy.tar.gz
                                tar zxvf trivy.tar.gz
                                sudo mv trivy /usr/local/bin/
                                rm trivy.tar.gz
                            """
                        } catch (Exception e) {
                            error "Trivy installation failed: ${e.getMessage()}"
                        }

                        // Verify installation
                        def trivyInstalledCheck = sh(script: "which trivy", returnStatus: true)
                        if (trivyInstalledCheck != 0) {
                            error "Trivy installation failed. Trivy not found after installation attempt."
                        } else {
                            echo "Trivy installed successfully."
                        }
                    } else {
                        echo "Trivy is already installed"
                    }
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                script {
                    // Perform Trivy scan on a Docker image (replace with your image)
                    def image = 'your-image:latest'
                    echo "Scanning Docker image: ${image} using Trivy"
                    try {
                        sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${image}"
                    } catch (Exception e) {
                        error "Trivy scan failed: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-credential', url: '') {
                        try {
                            sh "docker push ${GITHUB_REPO}:v${appVersion} || true"
                        } catch (e) {
                            echo "Failed to push ${GITHUB_REPO}:v${appVersion} (might be first time), continuing..."
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo "Cleaning up Docker images..."
            sh "docker rmi ${GITHUB_REPO}:v${appVersion} || true"

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