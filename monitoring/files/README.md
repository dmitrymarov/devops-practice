# Задание №3

**Используя готовую роль развернуть Grafana. Удостовериться в работоспособности дашборда. Добавить все файлы плейбука в репозиторий Github в каталог Grafana.**

---

## Структура репозитория 
```
monitoring/
    │   ├── deploy2.yml
    │   └── roles/
    │       └── grafana/
    │           ├── defaults/ 
    │           │   └── main.yml
    │           ├── files/
    │           │   └── host.json
    │           ├── handlers/
    │           │   └── main.yml
    │           ├── tasks/
    │           │   └── main.yml
    │           ├── templates/
    │           │   ├── datasource.yml.j2
    │           │   ├── grafana.yml.j2
    │           │   └── dashboard.yml
    │           └── vars/
    │               └── main.yml
    └──
```
## Инструкция
### Конфигурация
* В `deploy.yml` указана роль grafana для запуска grafana как ни странно.

### Роль grafana
Рассмотрим содержимое каждого каталога и файлов внутри роли:
- `defaults/main.yml`:  
В этом файле определяются значения переменных по умолчанию, это пути к папкам, версия контейнера, адрес контейнера, адрес источника данных(прометеуса), и api ключ для импорта готового дэшборда.

```yaml
grafana_volume: /data/grafana
grafana_volume_data: "{{ grafana_volume }}/data"
grafana_volume_log: "{{ grafana_volume }}/log"
grafana_volume_conf: "{{ grafana_volume }}/conf"
grafana_volume_provisioning: "{{ grafana_volume }}/provisioning"
grafana_volume_dashboard: "{{ grafana_volume_provisioning }}/dashboards"
grafana_volume_datasource: "{{ grafana_volume_provisioning }}/datasource"
grafana_volume_plugins: "{{ grafana_volume }}/plugins"
grafana_image: grafana/grafana:9.2.18
grafana_container_name: grafana
grafana_ports:
  - 0.0.0.0:8084:3000
grafana_prometheus_url: http://prometheus:9090
grafana_api_key: "eyJrIjoidDVEVm9DVUw0S2tLVWhTcFE5WjJDZW9pM2x1U2tPd0giLCJuIjoiYXN1YWRtaW4iLCJpZCI6MX0="
```
- `vars/main.yml`:  
В данном примере дополнительные переменные не определены.

- `handlers/main.yml`:  
Обработчик, который перезапускает контейнер при изменении конфигурации.
``` yaml
---
- name: Restart Grafana
  community.docker.docker_container:
    container_default_behavior: no_defaults 
    name: grafana
    state: started
    restart: true
  listen: restartContainerGrafana
```

- `tasks/main.yml`:
Основной файл с задачами, в котором написаны все шаги по установке и настройке grafana.  
Ниже разберем задачи поэтапно:  

Проверка, того что необходимые Docker-сети существуют и создает их в ином случае.
``` yaml 
- name: Ensure Docker networks exist
  community.docker.docker_network:
    name: "{{ item }}"
    state: present
  loop:
    - monitoring_external
    - monitoring_internal
    - monitoring
```
Создание директории для хранения данных, конфигураций и других ресурсов Grafana, а также копирование шаблонов конфигурации, настройки источника данных, json-файла дашборда. 

``` yaml
- name: Create directories for Grafana
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: 472
    group: 472
    mode: '0755'
  loop:
    - "{{ grafana_volume }}"
    - "{{ grafana_volume_data }}"
    - "{{ grafana_volume_log }}"
    - "{{ grafana_volume_conf }}"
    - "{{ grafana_volume_provisioning }}"
    - "{{ grafana_volume_dashboard }}"
    - "{{ grafana_volume_datasource }}"
    - "{{ grafana_volume_plugins }}"

- name: Copy Grafana configuration
  ansible.builtin.template:
    src: "grafana.ini.j2"
    dest: "{{ grafana_volume_conf }}/grafana.ini"
    mode: "0600"
    owner: 472
    group: 472
  notify:
    - restartContainerGrafana

- name: Copy Grafana datasource
  ansible.builtin.template:
    src: "datasource.yml.j2"
    dest: "{{ grafana_volume_datasource }}/datasource.yml"
    mode: "0600"
    owner: 472
    group: 472
  notify:
    - restartContainerGrafana

- name: Copy Dashboard
  ansible.builtin.copy:
    src: files/host.json
    dest: "{{ grafana_volume_dashboard }}/host.json"
    owner: 472
    group: 472
  notify:
    - restartContainerGrafana
```
Запуск контейнера grafana, с указанием всех ранее показанных параметров, маппингом томов.  
Также добавлена проверка состояния, с интервалов в 2 минуты. 
``` yaml
- name: Start Grafana
  community.docker.docker_container:
    name: "{{ grafana_container_name }}"
    image: "{{ grafana_image }}"
    networks:
      - name: monitoring_external
      - name: monitoring
      - name: monitoring_internal
    restart_policy: on-failure
    ports: "{{ grafana_ports }}"
    hostname: grafana
    volumes:
      - "{{ grafana_volume_conf }}/grafana.ini:/etc/grafana/grafana.ini"
      - "{{ grafana_volume_dashboard }}:/etc/grafana/provisioning/dashboard"
      - "{{ grafana_volume_datasource }}:/etc/grafana/provisioning/datasource"
      - "{{ grafana_volume_log }}:/var/log/grafana"
      - "{{ grafana_volume_data }}:/var/lib/grafana"
    healthcheck:
      test: ["CMD", "wget", "--spider", "--quiet", "http://127.0.0.1:3000/healthz"]
      interval: 2m
      timeout: 5s
      retries: 3
      start_period: 1m
```
Импорт дашборда в Grafana с помощью API ключа.
``` yaml
- name: Import Grafana dashboards
  community.grafana.grafana_dashboard:
    grafana_url: "http://localhost:8084"
    grafana_api_key: "{{ grafana_api_key }}"
    state: present
    path: "{{ grafana_volume_dashboard }}/host.json"
    overwrite: yes
    folder: "General"  
    commit_message: "Updated by Ansible"
```

- `templates/grafana.ini.j2`: Шаблон конфигурационного файла Grafana.
- `templates/datasource.yml.j2`: Шаблон файла настройки источника данных для Grafana.

``` yaml 
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: {{ grafana_prometheus_url }}
    basicAuth: true
    isDefault: true
    editable: true
```
- `files/host.json`: Файл с описанием дашборда для Grafana.

### Скриншот того, что все работает: 
![alt-текст](https://snipboard.io/csVv3z.jpg "Скриншот рабочего дашборда")