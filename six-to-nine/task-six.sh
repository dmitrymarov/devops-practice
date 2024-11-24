#!/bin/bash
set -euo pipefail
CONTAINER_NAME="sshing-gitea-1"
GITEA_API_URL="http://localhost:3000"
GITEA_USERNAME="asuadmin"
GITEA_TOKEN="3ebbe20d581dfba13dbcf24a24273ca3f06e094f"
GITHUB_REPO="https://github.com/Kazantsev27/CreatePDF.git"
WORK_DIR=$(mktemp -d)

exec_in_container() {
    docker exec -i "$CONTAINER_NAME" "$@"
}

cleanup() {
    echo "Очистка временных файлов..."
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT


echo "Создание организации 'practice'..."
exec_in_container curl -X POST \
    "$GITEA_API_URL/api/v1/orgs" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d '{
        "username": "practice",
        "description": "Организация для практики",
        "visibility": "public"
    }' > /dev/null 2>&1
sleep 2

echo "Создание репозитория 'NewCreate'..."
exec_in_container curl -X POST \
    "$GITEA_API_URL/api/v1/orgs/practice/repos" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d '{
        "name": "NewCreate",
        "description": "Миграция из CreatePDF",
        "private": false,
        "auto_init": false
    }' > /dev/null 2>&1

echo "Клонирование исходного репозитория из GitHub..."
cd "$WORK_DIR" || exit
git clone --mirror "$GITHUB_REPO" source-repo > /dev/null 2>&1
cd source-repo || exit

echo "Пуш..."
git remote add gitea "http://${GITEA_USERNAME}:${GITEA_TOKEN}@localhost:3030/practice/NewCreate.git" 
git push --mirror gitea > /dev/null 2>&1

echo "Выполнение скрипта завершено успешно!"
echo "Репозиторий доступен по адресу: http://localhost:3030/practice/NewCreate.git"
