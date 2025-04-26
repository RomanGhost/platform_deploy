#!/bin/bash

# Немедленно выходить, если команда завершается с ошибкой
set -e
# Считать использование необъявленных переменных ошибкой
set -u
# Проверять код возврата каждой команды в пайплайне
set -o pipefail

# --- Конфигурация ---
PLATFORM_REPO="git@github.com:RomanGhost/p2pStock.git"
CHAT_REPO="git@github.com:RomanGhost/chat.git"
SENDER_REPO="git@github.com:RomanGhost/sender.git"

CLIENT_PLATFORM_DIR="client_platform"
SERVER_PLATFORM_DIR="server_platform"
SERVER_CHAT_DIR="server_chat"
SERVER_SENDER_DIR="server_sender"

# --- Функция для клонирования, удаления Dockerfile и копирования ---
# Параметры: <repo_url> <temp_subdir_name> <src_path1> <dest_dir1> [<src_path2> <dest_dir2> ...]
clone_and_copy() {
    local repo_url="$1"
    local temp_subdir_name="$2"
    shift 2 # Убираем repo_url и temp_subdir_name из списка аргументов

    local temp_path="${WORK_DIR}/${temp_subdir_name}"
    local repo_basename=$(basename "$repo_url" .git) # Для логов

    echo "Клонирование $repo_basename..."
    # Клонируем только последний коммит для скорости
    git clone --quiet --depth 1 "$repo_url" "$temp_path"
    # Если нужна полная история, уберите --depth 1

    # --- ИСПРАВЛЕНИЕ: Рекурсивное удаление Dockerfile ---
    echo "Поиск и удаление всех Dockerfile в $temp_path..."
    # Ищем все файлы (-type f) с именем Dockerfile (-name Dockerfile)
    # рекурсивно внутри $temp_path и удаляем их (-delete).
    # Опция -print выводит найденные файлы перед удалением (можно убрать, если не нужно).
    find "$temp_path" -type f -name Dockerfile -print -delete
    echo "Удаление Dockerfile завершено."
    # ----------------------------------------------------

    while (( "$#" >= 2 )); do
        local src_path="$1"
        local dest_dir="$2"
        shift 2

        echo "Копирование из ${temp_path}/${src_path} в $dest_dir..."
        # Создаем целевую директорию, если ее нет (-p игнорирует ошибку, если она уже существует)
        mkdir -p "$dest_dir"
        # Копируем содержимое (-a - режим архива, сохраняет права, владельца и т.д.)
        # Использование /., чтобы скопировать содержимое папки, а не саму папку
        cp -a "${temp_path}/${src_path}/." "$dest_dir/"
    done
}

# --- Основная часть скрипта ---

# Создаем одну временную директорию для всех операций
WORK_DIR=$(mktemp -d -t setup_project_XXXXXX)
echo "Создана временная директория: $WORK_DIR"

# Функция очистки, которая будет вызвана при выходе (нормальном или по ошибке)
cleanup() {
  echo "Очистка временной директории: $WORK_DIR"
  rm -rf "$WORK_DIR"
}
# Регистрируем функцию очистки
trap cleanup EXIT INT TERM

# --- Подготовка платформы ---
echo "Работа с платформой ($PLATFORM_REPO)"
clone_and_copy "$PLATFORM_REPO" "platform" "Client" "$CLIENT_PLATFORM_DIR" "Server" "$SERVER_PLATFORM_DIR"

# --- Подготовка чата ---
echo "Работа с чатом ($CHAT_REPO)"
# Копируем все из корня репозитория (.) в целевую папку
clone_and_copy "$CHAT_REPO" "chat" "." "$SERVER_CHAT_DIR"

# --- Подготовка sender ---
echo "Работа с sender ($SENDER_REPO)"
# Копируем все из корня репозитория (.) в целевую папку
clone_and_copy "$SENDER_REPO" "sender" "." "$SERVER_SENDER_DIR"

# --- Сборка и запуск Docker ---
echo "Сборка и запуск Docker контейнеров..."
# --build пересобирает образы перед запуском
docker-compose up -d --build

echo "Скрипт успешно завершен."

# Очистка сработает автоматически при выходе благодаря trap
exit 0