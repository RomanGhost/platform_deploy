# Используем официальный образ Go для сборки приложения
FROM golang:1.23 AS builder

# Устанавливаем рабочую директорию в контейнере
WORKDIR /app

# Копируем файлы проекта
COPY go.mod go.sum ./
RUN go mod download

COPY . .

EXPOSE 8080

# Собираем бинарник Go-приложения
CMD go run main.go