#!/bin/bash

set -euo pipefail
GITEA_DIR="$PWD/SSHing"
DOCKER_COMPOSE_FILE="$GITEA_DIR/docker-compose.yml"
GITEA_SHIM="/usr/local/bin/gitea"
GIT_USER="asuadmin"
GIT_UID=1000
GIT_GID=1000
SSH_DIR="/home/$GIT_USER/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
HOST_KEYS_DIR="$GITEA_DIR/ssh/host_keys"
GITEA_HOST_KEY_COMMENT="Gitea Host Key"

mkdir -p "$GITEA_DIR/ssh/host_keys"
mkdir -p "$GITEA_DIR/gitea"
mkdir -p "$SSH_DIR"

cat > "$DOCKER_COMPOSE_FILE" << 'EOL'
services:
  gitea:
    image: gitea/gitea:latest
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    ports:
      - "3030:3000"
      - "127.0.0.1:2222:22"
    volumes:
      - ./gitea:/data
      - /home/asuadmin/.ssh:/data/git/.ssh
      - ./ssh/host_keys:/etc/ssh
EOL

echo "docker-compose.yml создан."

sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"
sudo chown "$GIT_USER:$GIT_USER" "$SSH_DIR"

if [ ! -f "$SSH_DIR/id_rsa" ]; then
    echo "Генерация SSH-ключей для пользователя $GIT_USER."
    sudo -u "$GIT_USER" ssh-keygen -t rsa -b 4096 -C "$GITEA_HOST_KEY_COMMENT" -f "$SSH_DIR/id_rsa" -N ""
else
    echo "SSH-ключи для пользователя $GIT_USER уже существуют."
fi

sudo tee "$GITEA_SHIM" > /dev/null << 'EOL'
#!/bin/sh
ssh -p 2222 -o StrictHostKeyChecking=no git@127.0.0.1 "SSH_ORIGINAL_COMMAND=\"$SSH_ORIGINAL_COMMAND\" /usr/bin/gitea serv $@"
EOL

sudo chmod +x "$GITEA_SHIM"
echo "Shim-скрипт Gitea создан и сделан исполняемым."

echo "Запуск Docker Compose."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "Проверка запущенных контейнеров:"
docker-compose -f "$DOCKER_COMPOSE_FILE" ps

echo "==============================================="
echo "Установка Gitea завершена успешно!"
echo ""
echo "Следующие шаги для завершения настройки:"
echo "1. Откройте веб-браузер и перейдите по адресу http://localhost:3030 для первоначальной настройки Gitea."
echo "2. Создайте администратора и настройте необходимые параметры."
echo "3. Добавьте свои SSH-ключи через веб-интерфейс Gitea в разделе 'SSH / GPG Keys'."
echo "4. Для клонирования репозиториев используйте SSH URL, например:"
echo "   git clone ssh://git@localhost:2222/username/repo.git"
echo "==============================================="
