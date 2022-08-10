# Set Java (https://hub.docker.com/r/adoptopenjdk/openjdk11/)
FROM openjdk:11-jdk

# Create a group and user
RUN groupadd -r spring && useradd -r -g spring spring

# Tell docker that all future commands should run as the appuser user
USER spring:spring

# Copy the project JAR file into the container as 'demo-spring-boot-docker.jar'
ARG JAR_FILE=build/libs/\*.jar
COPY ${JAR_FILE} demo-spring-boot-docker.jar

# The array form the ENTRYPOINT is used so that there is no shell wrapping the Java process
ENTRYPOINT ["java","-jar","/demo-spring-boot-docker.jar"]
