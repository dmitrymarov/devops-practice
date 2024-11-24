# Задание №5
**В инстансе Gitea, создать организацию "practice" в который разместить следующий [репозиторий](https://github.com/Kazantsev27/CreatePDF), все коммиты должны быть перенесены в новый репозиторий. Репозиторий назвать: NewCreate.**

---
### Введение

Для выполнения этого задания также написан скрипт формата формате _"нажать на кнопку - получить результат"_

Он выполняет основные задачи, такие как:

- Создание организации
- Создание репозитория
- Клонирование удаленного репозитория в репозиторий организации

---
#### ВАЖНО
Перед запуском скрипта необходимо настроить переменные:
```bash
CONTAINER_NAME="gitea"                  # Имя Docker-контейнера с Gitea
GITEA_API_URL="http://localhost:3000"   # URL API Gitea
GITEA_USERNAME="username"               # Имя пользователя Gitea
GITEA_TOKEN="your-token-api"            # Токен доступа Gitea
GITHUB_REPO="url-to-github-repo"        # URL GitHub репозитория
```
___
### Описание скрипта

Пройдем поэтапно по содержимому скрипта:

1. Вначале создаются необходимые переменные и временная папка, где будут хранится файлы до пуша в gitea. 
``` bash
#!/bin/bash
set -euo pipefail   # обработка ошибок)
CONTAINER_NAME="sshing-gitea-1"
GITEA_API_URL="http://localhost:3000"
GITEA_USERNAME="asuadmin"
GITEA_TOKEN="3ebbe20d581dfba13dbcf24a24273ca3f06e094f"
GITHUB_REPO="https://github.com/Kazantsev27/CreatePDF.git"
WORK_DIR=$(mktemp -d)
```

2. Две функции, первая позволяет выполнять команды в контейнере, вторая удаляет временные файлы при завершении скрипта.
```bash
exec_in_container() {
    docker exec -i "$CONTAINER_NAME" "$@"
}

cleanup() {
    echo "Очистка временных файлов..."
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT
```

3. Как собственно написано ниже, тут создается организация.  
Заходим в контейнер, используем API Gitea для создания организации, передавая информацию о ней в формате json. Затем немного ждем, чтобы все прошло успешно.  
`> /dev/null 2>&1` - нужно для того, чтобы ничего лишнего в консоль не выводилось.
``` bash
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
```

4. Заходим в контейнер, используем API Gitea для создания репозитория, передавая информацию о нем в формате json. 
``` bash
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
```
5. Выполняем ПОЛНОЕ копирование/клонирование удаленного репозитория.
``` bash
echo "Клонирование исходного репозитория из GitHub..."
cd "$WORK_DIR" || exit
git clone --mirror "$GITHUB_REPO" source-repo > /dev/null 2>&1
cd source-repo || exit
```

6. Добавляем репозиторий и отправляем/пушим в него полную копию(делаем зеркальное копирование при пуше)
``` bash
echo "Пуш..."
git remote add gitea "http://${GITEA_USERNAME}:${GITEA_TOKEN}@localhost:3030/practice/NewCreate.git" 
git push --mirror gitea > /dev/null 2>&1
```
7. Сигнализируем о том, что все завершено успешно
``` bash
echo "Выполнение скрипта завершено успешно!"
echo "Репозиторий доступен по адресу: http://localhost:3030/practice/NewCreate.git" 
```

### Скриншот того, что все работает: 
![alt-текст](https://snipboard.io/hzZmVO.jpg "Скриншот рабочего дашборда")