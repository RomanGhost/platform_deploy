# Базовый образ с Go 1.23
FROM golang:1.23 as builder

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем файлы проекта
COPY go.mod go.sum ./
RUN go mod download

# Копируем весь код
COPY . .

# Сборка приложения
RUN go build -o app .

# Финальный образ
FROM debian:bookworm-slim

# Устанавливаем рабочую директорию
WORKDIR /app

# Копируем скомпилированное приложение из предыдущего контейнера
COPY --from=builder /app/app .

# Открываем порт (если нужно)
EXPOSE 7878
EXPOSE 8080

# Запускаем приложение
CMD ["./app"]
