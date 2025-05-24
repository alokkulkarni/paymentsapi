name: CI
run-name:  is testing out GitHub Actions 🚀
on:
  push:
    branches:
      - main

env:
  IMAGE_NAME: paymentsapi
  IMAGE_TAGS: 
  IMAGE_REGISTRY: hub.docker.com
  IMAGE_NAMESPACE: alokkulkarni
  USERNAME: 
  PASSWORD: 

jobs:
  build-and-push-image:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
        - name: checkout code
          uses: actions/checkout@v3
          with:
            fetch-depth: 0 

        - name: setup jdk 17
          uses: actions/setup-java@v3
          with:
            distribution: 'corretto'
            java-version: 17

        - name: unit tests
          run: ./gradlew test

        - name: build the app
          run: |
            ./gradlew clean
            ./gradlew -DskipTests build
        
        # - name: SonarQube Scan
        #   uses: SonarSource/sonarqube-scan-action@v4
        #   with:
        #     sonar_host_url: 
        #     sonar_token: 
        
        # - name: build the docker image
        #   uses: docker/build-push-action@v4
        #   with:
        #     context: .
        #     dockerfile: Dockerfile
        #     push: false
        #     tags: /:

        - name: login to docker hub
          uses: docker/login-action@v3
          with:
            username: 
            password: 

        - name: Build and Push Docker Image
          run: |
            docker build -t /: .
            docker tag /: /:latest
            docker push /:
            docker push /:latest

        # - name: push the docker image to docker hub
        #   uses: docker/build-push-action@v4
        #   with:
        #     context: .
        #     dockerfile: Dockerfile
        #     push: true
        #     tags: /:
