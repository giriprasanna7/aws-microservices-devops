pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region containing ECR and EC2')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '', description: '12-digit AWS account ID')
        string(name: 'EC2_HOST', defaultValue: '', description: 'EC2 public IPv4 address')
        string(name: 'SSH_CREDENTIALS_ID', defaultValue: 'ec2-deploy-key', description: 'Jenkins SSH private-key credential ID')
    }

    environment {
        IMAGE_TAG = "build-${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git rev-parse --short HEAD'
            }
        }

        stage('Validate configuration') {
            steps {
                sh '''
                    ECR_REGISTRY=example.invalid IMAGE_TAG=ci GRAFANA_ADMIN_PASSWORD=ci-only docker compose config --quiet
                    test -f nginx/default.conf
                    test -f prometheus/prometheus.yml
                    test -f terraform/main.tf
                '''
            }
        }

        stage('Run service tests') {
            steps {
                sh '''
                    set -e
                    for service in services/user-service services/product-service services/order-service; do
                      (cd "$service" && npm install --package-lock=false && npm test)
                    done
                '''
            }
        }

        stage('Build and tag images') {
            steps {
                sh '''
                    set -e
                    REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    docker build -t "$REGISTRY/user-service:$IMAGE_TAG" services/user-service
                    docker build -t "$REGISTRY/product-service:$IMAGE_TAG" services/product-service
                    docker build -t "$REGISTRY/order-service:$IMAGE_TAG" services/order-service
                '''
            }
        }

        stage('Push images to ECR') {
            steps {
                sh '''
                    set -e
                    REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
                    docker push "$REGISTRY/user-service:$IMAGE_TAG"
                    docker push "$REGISTRY/product-service:$IMAGE_TAG"
                    docker push "$REGISTRY/order-service:$IMAGE_TAG"
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: params.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    sh '''
                        set -e
                        REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                        SSH_OPTS="-o StrictHostKeyChecking=accept-new"
                        ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$EC2_HOST" "mkdir -p /opt/microservices/nginx /opt/microservices/prometheus /opt/microservices/grafana/provisioning/datasources"
                        scp $SSH_OPTS -i "$SSH_KEY" docker-compose.yml "$SSH_USER@$EC2_HOST:/opt/microservices/docker-compose.yml"
                        scp $SSH_OPTS -i "$SSH_KEY" nginx/default.conf "$SSH_USER@$EC2_HOST:/opt/microservices/nginx/default.conf"
                        scp $SSH_OPTS -i "$SSH_KEY" prometheus/prometheus.yml "$SSH_USER@$EC2_HOST:/opt/microservices/prometheus/prometheus.yml"
                        scp $SSH_OPTS -i "$SSH_KEY" grafana/provisioning/datasources/prometheus.yml "$SSH_USER@$EC2_HOST:/opt/microservices/grafana/provisioning/datasources/prometheus.yml"
                        ssh $SSH_OPTS -i "$SSH_KEY" "$SSH_USER@$EC2_HOST" "
                          set -e
                          cd /opt/microservices
                          grep -q '^ECR_REGISTRY=' .env
                          sed -i 's|^IMAGE_TAG=.*|IMAGE_TAG=${IMAGE_TAG}|' .env
                          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}
                          docker compose pull
                          docker compose up -d
                          docker compose ps
                          curl --fail --retry 12 --retry-delay 5 http://localhost/api/users/health
                          curl --fail --retry 12 --retry-delay 5 http://localhost/api/products/health
                          curl --fail --retry 12 --retry-delay 5 http://localhost/api/orders/health
                        "
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployment completed with image tag ${IMAGE_TAG}"
        }
        failure {
            echo 'Pipeline failed. Review the stage logs; the previously running Compose containers should remain available unless deployment was partially applied.'
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
