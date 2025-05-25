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
                        def version = ''
                        if (fileExists('pom.xml')) {
                            version = sh(
                                script: """
                                    grep '<version>' pom.xml | head -1 | sed -E 's/.*<version>([^<]+)<\\/version>.*/\\1/' | sed 's/-SNAPSHOT//' | xargs
                                """,
                                returnStdout: true
                            ).trim()
                        } else if (fileExists('build.gradle')) {
                            version = sh(
                                script: '''
                                    grep ^version build.gradle | sed -E "s/version[ \\t]*=[ \\t]*[\\"\\']([^\\\"\\']+)[\\"\\']/\\1/" | sed 's/-SNAPSHOT//' | xargs
                                ''',
                                returnStdout: true
                            ).trim()
                        }

                        if (!version) {
                            version = '0.0.1'
                        }

                        def branch = env.BRANCH_NAME ?: 'unknown-branch'

                        echo "Building Docker image with tags: paymentsapi:${branch} and paymentsapi:v${version}"

                        sh '''
                            docker buildx build \
                                --platform=linux/amd64 \
                                --load \
                                -t alokkulkarni/paymentsapi:v${version}\
                                .
                        '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    def branch = env.BRANCH_NAME?.replaceAll('/', '-') ?: "unknown-branch"
                    def branchTag = "${env.IMAGE_NAME}:${branch}"
                    def releaseTag = "alokkulkarni/${env.IMAGE_NAME}:v${env.RELEASE_VERSION}"

                    withDockerRegistry(credentialsId: 'docker-credential', url: '') {
                        // Push with try/catch to not fail first push
                        // try {
                        //     sh "docker push ${branchTag}"
                        // } catch (e) {
                        //     echo "Failed to push ${branchTag} (might be first time), continuing..."
                        // }
                        try {
                            sh "docker push alokkulkarni/${env.IMAGE_NAME}:v${env.RELEASE_VERSION}"
                        } catch (e) {
                            echo "Failed to push ${releaseTag} (might be first time), continuing..."
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo "Cleaning up Docker images..."
            sh "docker rmi alokkulkarni/paymentsapi:latest || true"

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