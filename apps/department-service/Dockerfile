FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q clean package -DskipTests
# agente Java do OpenTelemetry; só é ativado quando o chart define otel.enabled
RUN curl -fsSL -o /opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.10.0/opentelemetry-javaagent.jar

FROM eclipse-temurin:17-jre
RUN useradd --system --uid 10001 app
USER app
WORKDIR /application
COPY --from=build /opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
COPY --from=build /build/target/*.jar application.jar
EXPOSE 8080
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"
ENTRYPOINT ["java", "-jar", "application.jar"]
