#!/bin/bash
set -euo pipefail
GITEA_URL="http://localhost:3030"
GITEA_USER="asuadmin"
GITEA_TOKEN="3ebbe20d581dfba13dbcf24a24273ca3f06e094f"
ORGANIZATION_NAME="practice"
REPO_NAME="NewCreate"

echo "Создание Jenkinsfile в репозитории..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

git clone "http://${GITEA_USER}:${GITEA_TOKEN}@localhost:3030/${ORGANIZATION_NAME}/${REPO_NAME}.git"
cd "$REPO_NAME"

cat << 'EOF' > Jenkinsfile
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                git 'http://sshing-gitea-1:3000/practice/NewCreate.git'
            }
        }
        
        stage('Build') {
            steps {
                sh 'mvn package'
            }
        }
    }
    
    post {
        success {
            echo 'Сборка успешна!'
        }
        failure {
            echo 'Сборка провалена.'
        }
    }
}

EOF

git add Jenkinsfile
git config user.email "asuadmin@noreply.com"
git config user.name "ASUAdmin"

if ! git diff --cached --quiet; then
    git commit -m "Add Jenkinsfile"
    git push
    if [ $? -ne 0 ]; then
        echo "Не удалось отправить Jenkinsfile в репозиторий"
        exit 1
    fi
else
    echo "Изменений для коммита нет."
fi
echo "Очистка..."
rm -rf "$WORK_DIR"