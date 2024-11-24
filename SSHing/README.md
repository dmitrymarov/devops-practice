# Задание №4
**Настроить один из вариантов SSHing Shim docs, чтобы можно было склонировать репозиторий используя SSH.**

---
### Введение

Вся настройка выполняется в формате _"нажать на кнопку - получить результат"_.  
Для этого был создан скрипт `everything_you_need.sh`.  
Он выполняет основные задачи, такие как:
- Создание необходимых директорий
- Генерация SSH-ключей
- Создание файла docker-compose.yml для запуска контейнера Gitea.
- Создание shim-скрипта для интеграции SSH с Gitea
- Запуск контейнера и проверка его состояния
- Вывод инструкций для завершения настройки

### Описание скрипта

1. Настройка окружения и переменных:
``` bash
set -eou pipefail # Завершить скрипт при первой же ошибки
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
```
2. Создание необходимых папок
```bash
mkdir -p "$GITEA_DIR/ssh/host_keys"
mkdir -p "$GITEA_DIR/gitea"
mkdir -p "$SSH_DIR"
```
3. Создание файла `docker-compose.yml`
``` bash
cat > "$DOCKER_COMPOSE_FILE" << 'EOL'
services:
  gitea:
    image: gitea/gitea:latest
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    ports:
      - "3030:3000" # Используются другие порты, так как стандартные - заняты
      - "127.0.0.1:2222:22"
    volumes:
      - ./gitea:/data
      - /home/asuadmin/.ssh:/data/git/.ssh
      - ./ssh/host_keys:/etc/ssh
EOL

echo "docker-compose.yml создан." # Уведомляем, что этот этап выполнен
```
4. Создание ключей SSH
``` bash
sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"
sudo chown "$GIT_USER:$GIT_USER" "$SSH_DIR"

if [ ! -f "$SSH_DIR/id_rsa" ]; then
    echo "Генерация SSH-ключей для пользователя $GIT_USER."
    sudo -u "$GIT_USER" ssh-keygen -t rsa -b 4096 -C "$GITEA_HOST_KEY_COMMENT" -f "$SSH_DIR/id_rsa" -N ""
else
    echo "SSH-ключи для пользователя $GIT_USER уже существуют."
fi
```
5. Создание shim-скрипта для Gitea, команды взяты [отсюда](https://docs.gitea.com/installation/install-with-docker#sshing-shim-with-authorized_keys)
``` bash
sudo tee "$GITEA_SHIM" > /dev/null << 'EOL'
#!/bin/sh
ssh -p 2222 -o StrictHostKeyChecking=no git@127.0.0.1 "SSH_ORIGINAL_COMMAND=\"$SSH_ORIGINAL_COMMAND\" /usr/bin/gitea serv $@"
EOL

sudo chmod +x "$GITEA_SHIM"
echo "Shim-скрипт Gitea создан и сделан исполняемым."
```
6. Запуск контейнера и проверка его состояния
``` bash
echo "Запуск Docker Compose."
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

echo "Проверка запущенных контейнеров:"
docker-compose -f "$DOCKER_COMPOSE_FILE" ps
```
7. Вывод инструкций
``` bash 
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
```

# _Доказательства_

```bash
asuadmin@DESKTOP-HR0UPC9:~/devops-practice$ ./everything_you_need.sh 
docker-compose.yml создан.
Генерация SSH-ключей для пользователя asuadmin.
Generating public/private rsa key pair.
Your identification has been saved in /home/asuadmin/.ssh/id_rsa
Your public key has been saved in /home/asuadmin/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:... Gitea Host Key
The keys randomart image is:
+---[RSA 4096]----+
...
Shim-скрипт Gitea создан и сделан исполняемым.
Запуск Docker Compose.
[+] Running 1/0
 ✔ Container sshing-gitea-1  Running                                                                                                                                                                               0.0s 
Проверка запущенных контейнеров:
NAME             IMAGE                COMMAND                  SERVICE   CREATED         STATUS         PORTS
sshing-gitea-1   gitea/gitea:latest   "/usr/bin/entrypoint…"   gitea     4 minutes ago   Up 4 minutes   127.0.0.1:2222->22/tcp, 0.0.0.0:3030->3000/tcp, [::]:3030->3000/tcp
===============================================
Установка Gitea завершена успешно!

Следующие шаги для завершения настройки:
1. Откройте веб-браузер и перейдите по адресу http://localhost:3030 для первоначальной настройки Gitea.
2. Создайте администратора и настройте необходимые параметры.
3. Добавьте свои SSH-ключи через веб-интерфейс Gitea в разделе 'SSH / GPG Keys'.
4. Для клонирования репозиториев используйте SSH URL, например:
   git clone ssh://git@localhost:2222/username/repo.git
===============================================
asuadmin@DESKTOP-HR0UPC9:~/devops-practice$ git clone ssh://git@localhost:2222/asuadmin/asuadmin.git
Cloning into 'asuadmin'...
The authenticity of host '[localhost]:2222 ([127.0.0.1]:2222)' cant be established.
ED25519 key fingerprint is SHA256: ... 
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '[localhost]:2222' (ED25519) to the list of known hosts.
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0 (from 0)
Receiving objects: 100% (3/3), done.
```