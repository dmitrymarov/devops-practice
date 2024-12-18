~~Этот репозиторий был создан с целью решения тестового задания...~~
# Задание №1
**Развернуть Jenkins и Gitea в контейнерах при помощи ansible-playbook**

---

Все выполняется на Win 10 под WSL 2 Ubuntu-24.04

```powershell
PS C:\Users\marov> wsl --version
Версия WSL: 2.3.26.0
Версия ядра: 5.15.167.4-1
Версия WSLg: 1.0.65
Версия MSRDC: 1.2.5620
Версия Direct3D: 1.611.1-81528511
Версия DXCore: 10.0.26100.1-240331-1435.ge-release
Версия Windows: 10.0.19045.5131
PS C:\Users\marov> wsl -l
Дистрибутивы подсистемы Windows для Linux:
Ubuntu-24.04 (по умолчанию)
```
Сразу стоит уточнить, что в задании не указано, что сервисы должны быть настроены и _работать_, поэтому будет рассмотрена обыкновенная установка. 
* Вначале устанавливается docker.  
```yaml
    - name: Install Docker
      apt:
        name:
          - docker.io
          - docker-compose
        state: present
        update_cache: true
```  
* Затем запускается docker.  
```yaml
    - name: Start Docker
      service:
        name: docker
        state: started
        enabled: true
```  
* Загружается докер-образ Jenkins.  
```yaml
    - name: Pull Jenkins
      docker_image:
        name: jenkins/jenkins:lts
        source: pull
```  
* Создается хранилище для Jenkins.  
```yaml
    - name: Create Jenkins volume
      docker_volume:
        name: jenkins_home
```  
* Запускается контейнер jenkins.  
```yaml
    - name: Run Jenkins
      docker_container:
        name: jenkins
        image: jenkins/jenkins:lts
        ports:
          - "8080:8080"
          - "50000:50000"
        volumes:
          - jenkins_home:/var/jenkins_home
```  
* Создается папка(директорию) под Gitea.  
```yaml
    - name: Create directory for Gitea
      file:
        path: /opt/gitea
        state: directory
        mode: '0755'
```  
* Копируется [готовый docker compose файл](https://docs.gitea.com/installation/install-with-docker#basics "Ссылка на источник") в созданную папку  
```yaml
    - name: Copy docker-compose.yml for Gitea
      copy:
        dest: /opt/gitea/docker-compose.yml
        content: |
          version: "3"
          networks:
            gitea:
              external: false
          services:
            server:
              image: gitea/gitea:1.22.3
              container_name: gitea
              environment:
                - USER_UID=1000
                - USER_GID=1000
              restart: always
              networks:
                - gitea
              volumes:
                - ./gitea:/data
                - /etc/timezone:/etc/timezone:ro
                - /etc/localtime:/etc/localtime:ro
              ports:
                - "3000:3000"
                - "2221:22"
```  
* Запускается Gitea  
```yaml
    - name: Run Gitea with Docker Compose
      docker_compose:
        project_src: /opt/gitea
        state: present
```  
* Еще написаны handler'ы на всякий случай, в этом задании они не нужны
```yaml
  handlers:
    - name: Restart Gitea
      docker_compose:
        project_src: /opt/gitea
        state: restarted
    
    - name: Restart Jenkins
      docker_container:
        name: jenkins
        state: restarted
```
> Примечание.
> Установить docker используя ansible можно было бы и _по-другому_

```yaml
- name: Install required system packages
  apt:
    pkg:
      - apt-transport-https
      - ca-certificates
      - software-properties-common
    state: latest
    update_cache: true

- name: Add Docker GPG apt Key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present

- name: Add Docker Repository
  apt_repository:
    repo: deb https://download.docker.com/linux/ubuntu {{ubuntu_ver}} stable
    state: present

- name: Update apt and install docker-ce
  apt:
    pkg:
      - docker-ce
      - docker-compose
    state: latest
    update_cache: true

- name: Add remote "{{ username }}" user to "docker" group
  user:
    name: "{{ username }}"
    groups: docker
    append: yes
```
    Разберемся в том, что происходит:  
    1. Устанавливаются необходимые системные пакеты для работы с Docker
    2. Добавляется официальный GPG-ключ Docker
    3. Добавляется официальный репозиторий Docker для Ubuntu "нужной" версии
    4. Устанавливается docker 
    5. Добавление "нужного" пользователя в группу docker 
    Под "нужным" я имею ввиду те значения, которые будут указаны в vars.
    
    Вопрос: Почему я не использую способ выше?
    Ответ: А зачем, если задание выполняется на моей машине, где я знаю, что все это уже выполнено? 

# Задание №2

**Развернуть стека мониторинга prometheus+nodeexporter+cadvisor**

[Ссылка на README](../main/monitoring/README.md)

# Задание №3

**Используя готовую роль развернуть Grafana. Удостовериться в работоспособности дашборда. Добавить все файлы плейбука в репозиторий Github в каталог Grafana.**

[Ссылка на README](../main/monitoring/files/README.md)

# Задание №4

**Настроить один из вариантов SSHing Shim docs, чтобы можно было склонировать репозиторий используя SSH.**

[Ссылка на README](../main/SSHing/README.md)

# Задание №5

**В инстансе Gitea, создать организацию "practice" в который разместить следующий [репозиторий](https://github.com/Kazantsev27/CreatePDF), все коммиты должны быть перенесены в новый репозиторий. Репозиторий назвать: NewCreate.**

[Ссылка на README](../main/six-to-nine/README.md)

# Задание №6-8

+ **Создать организацию Тестовая в Jenkins и настроить интеграцию с Gitea организации practice**
+ **Добавить в репозиторий NewCreate Jenkinsfile, который будет собирать проект (выполняет mvn package)**
+ **Запустить сканирование организации practice в Jenkins. Убедиться, что NewCreate собирается**

[Ссылка на README](../main/six-to-nine/seven-to-nine/README.md)


# Дополнительные задания 

+ **Написать Dockerfile, который запускает nginx и при обращении к localhost:8085 выдает страницу с приветствие "Добрый день! Это тестовое задание для меня было отличным шагом!". Разместить Dockerfile и файл index.html в GitHub в каталоге nginx.**
+ **Поднять инстанс с артефакторием Nexus. Удалить стандартные репозитории и настроить proxy-репозиторий для pypi. Название для proxy-репозитория указать: test-proxy**
+ **Поднять воркер(агент) для Jenkins и подключить к существующему инстансту.**
+ **Написать скрипт на bash который на вход получает текстовый файл и выводит строки в которых есть слово testbash на экран и в дальнейшем формировует новый файл из всех найденных строк и подсчитывает это количество строк и также записывает в файл. Разместить скрипт в GitHub в каталоге bash**
+ **Создать нового пользователя в Linux и добавить его в группу sudo, настроить выполнение sudo без пароля**
+ **Просмотреть основные характеристики машины Linux: объем ОЗУ, количество ядер, объем HDD, файловую систему томов, релиз дистрибутива Linux**

[Ссылка на README](../main/add-tasks/README.md)
