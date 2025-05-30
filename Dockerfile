# Use Alpine 3.22 as the base image
FROM alpine:3.21

# Set the environment variable for OpenJDK version
ENV JAVA_VERSION 17

# Install OpenJDK 17 and dependencies
RUN apk update && \
    apk add --no-cache openjdk17

WORKDIR /app

# Copy application jar
COPY build/libs/*.jar app.jar

# Create SBOM directory and copy SBOM files
# RUN mkdir -p /app/sbom
# COPY build/sbom/*.json /app/sbom/
# COPY build/sbom/*.xml /app/sbom/

# Add SBOM label to provide metadata about the image
# LABEL org.opencontainers.image.sbom.path="/app/sbom"
# LABEL org.cyclonedx.sbom.format="JSON,XML"

EXPOSE 8585:8585
ENTRYPOINT ["java","-jar","app.jar"]