# Stage 1: Build stage
FROM gradle:8.7-jdk21 AS builder

WORKDIR /app

# Копируем только файлы зависимостей отдельно для кэширования
COPY build.gradle settings.gradle ./

# Скачиваем зависимости заранее
RUN gradle dependencies --no-daemon

# Теперь копируем весь код
COPY . .

# Собираем проект
RUN gradle build --no-daemon

# Stage 2: Runtime stage
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
