# Задание №2

**Развернуть стека мониторинга prometheus+nodeexporter+cadvisor**

---

## Структура репозитория
```
monitoring/
    │   ├── deploy2.yml
    │   └── roles/
    │       └── monitoring/
    │           ├── tasks/
    │           │   └── main.yml
    │           ├── templates/
    │           │   ├── docker-compose.yml.j2
    │           │   └── prometheus.yml.j2
    └── 
```
## Компоненты стека мониторинга
Стек мониторинга включает следующие компоненты:
* Prometheus - система мониторинга и алертинга
* Node Exporter - для сбора метрик хоста
* cAdvisor - для мониторинга контейнеров

## Инструкция
### Конфигурация
* В `deploy2.yml` указаны основные переменные:
  - Пользователь для установки
  - Порты для сервисов
  - Путь к папке мониторинга
  - Роль для запуска _"всего остального"_

### Основной файл - main.yml
Пройдемся по основному файлу:  
Как можно заметить, ниже происходит установка docker и добавление пользователя в группу docker, несмотря на то, что ранее было подмечено, что пользователь и так в группе docker, а сам docker уже установлен. Сделано просто чтобы было)
``` yaml
- name: Install Docker
  apt:
    name: docker.io
    state: present
    update_cache: yes

- name: Install Docker Compose
  get_url:
    url: "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-{{ ansible_architecture }}"
    dest: /usr/local/bin/docker-compose
    mode: '0755'

- name: Verify Docker Compose installation
  command: docker-compose --version
  register: compose_version

- name: Add user to docker group
  user:
    name: "{{ ansible_user }}"
    groups: docker
    append: yes
```
Дальше создается папка для мониторинга и папка для конфигов прометеуса, чтобы сложить все в одно место.
``` yaml
- name: Create directory for monitoring
  file:
    path: "{{ monitoring_dir }}"
    state: directory
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
    mode: '0755'
- name: Create directories for config's
  file:
    path: "{{ monitoring_dir }}/conf/prometheus"
    state: directory
    owner: "{{ ansible_user }}"
    group: "{{ ansible_user }}"
    mode: '0755'
  with_items:
    - "{{ monitoring_dir }}/conf/prometheus"
```
Дальше используется шаблон docker-compose.yml.j2 (jinja2), опять же, чтобы показать что умею. С помощью шаблона создается нужный файл и помещается в созданную выше папочку.
``` yaml
- name: Deploy docker-compose.yml
  template:
    src: docker-compose.yml.j2
    dest: "{{ monitoring_dir }}/docker-compose.yml"
```
Дальше используется шаблон уже для прометеуса, также создается файл и помещается в указанную директорию.
```yaml
- name: Deploy prometheus.yml
  template:
    src: prometheus.yml.j2
    dest: "{{ monitoring_dir }}/conf/prometheus/prometheus.yml"
```
Затем уже запускается созданный ранее docker-compose файл.
``` yaml
- name: Run Docker Compose
  docker_compose:
    project_src: "{{ monitoring_dir }}"
    state: present
    restarted: yes
```

### Шаблоны
* `docker-compose.yml.j2` - описание docker-compose конфигурации
* `prometheus.yml.j2` - конфигурация для сбора метрик Prometheus

____
#### `docker-compose.yml.j2`
Вначале настройка прометеуса...
``` yaml
services:
    prometheus:
        image: prom/prometheus:latest
        restart: always
        container_name: prometheus
        command:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--web.console.libraries=/usr/share/prometheus/console_libraries'
        - '--web.console.templates=/usr/share/prometheus/consoles'
        - '--web.enable-admin-api'
        ports:
        - "{{ prometheus_port }}:9090"
        depends_on:
        - cadvisor
        - node_exporter
        volumes:
        - ./conf/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
        - prometheus_data:/prometheus
        networks:
        - monitoring
```
Затем настройка экспортера...
``` yaml 
  node_exporter:
    image: prom/node-exporter:latest
    restart: always
    container_name: node_exporter
    ports:
      - "{{ node_exporter_port }}:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.rootfs=/host'
    networks:
      - monitoring
```
Затем настройка мониторинга контейнеров
``` yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    restart: always
    container_name: cadvisor
    ports:
      - "{{ cadvisor_port }}:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    networks:
      - monitoring
```
____
#### `prometheus.yml.j2`
```yaml
# Глобальные настройки Prometheus
global:
# Интервал сбора метрик и оценки правил - 15 секунд, вместо минуты, просто потому что в примере было 15 секунд, ни на что особо в данном примере не влияет
  scrape_interval:     15s
  evaluation_interval: 15s
# Конфиги для сбора метрик
scrape_configs:
# Мониторинг самого Prometheus по порту 9090
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
# Мониторинг cAdvisor по порту 8081
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8081']
# Мониторинг node_exporter по порту 9100
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']
```
____


### Установка

Выполнить развертывание можно командой:

```bash
ansible-playbook deploy2.yml
```

### Доступ к сервисам

* Prometheus: `http://localhost:9090`
* Node Exporter: `http://localhost:9100`
* cAdvisor: `http://localhost:8081`
