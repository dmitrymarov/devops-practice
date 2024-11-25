#!/bin/bash

set -euo pipefail

ADMIN_USER="admin"
NEW_PASSWORD="asuadmin"
CONTAINER_NAME="nexus"
INITIAL_PASSWORD_FILE="/nexus-data/admin.password"
NEXUS_URL="http://localhost:8086/service/rest/v1"
PROXY_REPO="test-proxy"

echo -e "Начинаем установку..."
docker-compose up -d

echo -e "Ждём запуска Nexus..."
while ! curl -s http://localhost:8086 > /dev/null; do
    echo "Все еще ждём..."
    sleep 10
done
# echo -e "Получаем стандартный пароль администратора..."
# if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
#     INITIAL_PASSWORD=$(docker exec $CONTAINER_NAME cat $INITIAL_PASSWORD_FILE)
#     echo "Стандартный пароль получен."
# fi
# echo -e "Меняем пароль на '$NEW_PASSWORD'..."
# curl -u $ADMIN_USER:$INITIAL_PASSWORD -X POST "$NEXUS_URL/security/users/admin/change-password" \
#   -H 'Content-Type: application/json' \
#   -d '{
#         "currentPassword": "'"$INITIAL_PASSWORD"'",
#         "password": "'"$NEW_PASSWORD"'",
#         "confirmPassword": "'"$NEW_PASSWORD"'"
#       }'

# echo "Пароль администратора успешно изменен."

ADMIN_PASS="$NEW_PASSWORD"

repository_exists() {
    local repo_name=$1
    curl -s -u "$ADMIN_USER:$ADMIN_PASS" -X GET "$NEXUS_URL/repositories/$repo_name" > /dev/null
}

echo -e "Создаём proxy-репозиторий для pypi..."
if repository_exists "$PROXY_REPO"; then
    echo "Репозиторий $PROXY_REPO уже существует. Удаляем..."
    curl -s -u "$ADMIN_USER:$ADMIN_PASS" -X DELETE "$NEXUS_URL/repositories/$PROXY_REPO"
    echo "Репозиторий $PROXY_REPO удалён."
fi

curl -u "$ADMIN_USER:$ADMIN_PASS" -X POST "$NEXUS_URL/repositories/pypi/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "'"$PROXY_REPO"'",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    },
    "proxy": {
      "remoteUrl": "https://pypi.org/",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "negativeCache": {
      "enabled": true,
      "timeToLive": 1440
    },
    "httpClient": {
      "blocked": false,
      "autoBlock": true
    }
  }'
echo "Proxy-репозиторий $PROXY_REPO создан."

echo -e "Удаляем стандартные репозитории..."
for repo in $(curl -s -u "$ADMIN_USER:$ADMIN_PASS" -X GET "$NEXUS_URL/repositories" | jq -r '.[].name'); do
  if [[ "$repo" != "$PROXY_REPO" ]]; then
    echo "Удаляем репозиторий: $repo"
    curl -s -u "$ADMIN_USER:$ADMIN_PASS" -X DELETE "$NEXUS_URL/repositories/$repo"
    echo "Репозиторий $repo удалён."
  fi
done

echo -e "Создаём виртуальное окружение для Python..."
python3 -m venv venv
source venv/bin/activate

echo -e "Обновляем pip..."
pip install --upgrade pip > /dev/null

echo -e "Проверяем установку пакета через репозиторий..."
pip install --index-url http://localhost:8086/repository/test-proxy/simple/ requests > ./result.txt

