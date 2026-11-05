# AWS Microservices DevOps Assignment

A starter three-microservice application and DevOps deployment package for the four-day assignment.

## What is included

- `services/user-service`, `services/product-service`, `services/order-service`: small Node.js REST services with `/health` and `/metrics`.
- `nginx/default.conf`: routes `/api/users`, `/api/products`, and `/api/orders`.
- `docker-compose.yml`: runs the three services, Nginx, Prometheus, Node Exporter, and Grafana.
- `terraform/`: provisions one Ubuntu EC2 instance, three ECR repositories, an EC2 IAM role/profile, and a security group.
- `Jenkinsfile`: tests, builds, tags, pushes images to ECR, and deploys the approved tag to EC2 over SSH.
- `prometheus/` and `grafana/`: monitoring configuration and a provisioned Prometheus data source.
- `.gitignore` and `.dockerignore`: keep local secrets and build artifacts out of Git.

> This is a deployable starter/demo app because no existing application ZIP was attached. If your company supplied a real application, use its source code instead of these sample service implementations, while retaining/adapting the DevOps files.

## Architecture

GitHub -> Jenkins -> Docker build/test -> Amazon ECR (3 repositories) -> EC2 Docker Compose -> Nginx -> User/Product/Order services.
Prometheus scrapes the application metrics and Node Exporter. Grafana reads Prometheus.

## Prerequisites

1. AWS account and an IAM identity permitted to create EC2, IAM, ECR, VPC security groups and related resources.
2. Terraform 1.5+, AWS CLI v2, Git, Docker Engine and Docker Compose plugin.
3. A GitHub repository.
4. An SSH key pair in the same AWS region selected in Terraform.
5. Jenkins running on an existing workstation/build server (recommended by the assignment), with Git, Docker, AWS CLI and the Jenkins SSH Agent plugin.
6. Set an AWS budget alert before provisioning.

## 1. Run locally first

From the project root:

```bash
cp .env.example .env
# Edit .env. Set ECR_REGISTRY to a placeholder for local use, and choose a strong Grafana password.
docker compose config
docker compose up -d --build
docker compose ps
```

Test:

```bash
curl http://localhost/api/users/health
curl http://localhost/api/products/health
curl http://localhost/api/orders/health
curl http://localhost/api/users
curl http://localhost/api/products
curl http://localhost/api/orders
```

Open Grafana at `http://localhost:3000` and Prometheus at `http://localhost:9090` only on your own machine. Default Grafana username is `admin`; set the password in `.env`.

Stop local containers:

```bash
docker compose down
```

## 2. Push the source to GitHub

```bash
git init
git add .
git commit -m "Initial microservices and DevOps configuration"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/aws-microservices-devops.git
git push -u origin main
```

Create a `develop` branch for development work:

```bash
git checkout -b develop
git push -u origin develop
```

Use pull requests from `develop` to `main` for release changes. Do not commit `.env`, AWS keys, SSH private keys, Terraform state, or passwords.

## 3. Provision AWS using Terraform

Go to the Terraform folder:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- `aws_region`: your chosen AWS region.
- `admin_cidr`: your public IP in CIDR form, e.g. `203.0.113.10/32` (find it from a trusted IP-check service).
- `key_name`: existing EC2 key pair name in that region.
- `instance_type`: default `t3.medium`; consider cost before applying.
- `monitoring_cidr`: normally the same restricted CIDR as `admin_cidr`.

Then run:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Save the outputs: EC2 public IP, ECR registry and repository URLs. Do not commit `terraform.tfstate`, `terraform.tfstate.backup`, `.terraform/`, `terraform.tfvars`, or `tfplan`.

The instance bootstrap installs Docker, the Docker Compose plugin and AWS CLI. Wait for cloud-init to finish before connecting.

## 4. Prepare the EC2 host

```bash
ssh -i /path/to/YOUR_KEY.pem ubuntu@EC2_PUBLIC_IP
```

Check installation:

```bash
cloud-init status --wait
docker --version
docker compose version
aws --version
```

The EC2 instance role grants ECR pull access. Test:

```bash
aws sts get-caller-identity
aws ecr get-login-password --region YOUR_REGION | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com
```

Create deployment folder and environment file:

```bash
sudo mkdir -p /opt/microservices
sudo chown -R ubuntu:ubuntu /opt/microservices
cd /opt/microservices
```

Copy `docker-compose.yml`, the `nginx/`, `prometheus/`, and `grafana/` folders from your workstation/repository to `/opt/microservices` (the Jenkins pipeline also copies the deployment configuration).

Create `/opt/microservices/.env`:

```dotenv
AWS_REGION=ap-south-1
ECR_REGISTRY=YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
IMAGE_TAG=latest
GRAFANA_ADMIN_PASSWORD=REPLACE_WITH_A_LONG_UNIQUE_PASSWORD
```

Replace the region and account ID with your actual values. Keep this file private:

```bash
chmod 600 .env
```

## 5. Build and push images manually (first deployment / fallback)

On a machine with Docker and AWS CLI configured:

```bash
export AWS_REGION=ap-south-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
export IMAGE_TAG=manual-1

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker build -t "$ECR_REGISTRY/user-service:$IMAGE_TAG" services/user-service
docker build -t "$ECR_REGISTRY/product-service:$IMAGE_TAG" services/product-service
docker build -t "$ECR_REGISTRY/order-service:$IMAGE_TAG" services/order-service

docker push "$ECR_REGISTRY/user-service:$IMAGE_TAG"
docker push "$ECR_REGISTRY/product-service:$IMAGE_TAG"
docker push "$ECR_REGISTRY/order-service:$IMAGE_TAG"
```

Update `.env` on EC2 so `ECR_REGISTRY` and `IMAGE_TAG` match the pushed images. Then on EC2:

```bash
cd /opt/microservices
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=100
```

## 6. Configure Jenkins

### Jenkins machine requirements

Install Git, Docker Engine, AWS CLI v2 and the Jenkins SSH Agent plugin. Ensure the Jenkins agent user can run Docker. Configure AWS credentials on the Jenkins build machine using an instance role or a least-privilege AWS profile/credential mechanism. Do not put access keys in the Jenkinsfile or Git.

Create a Jenkins credential:
- Kind: **SSH Username with private key**
- ID: `ec2-deploy-key`
- Username: `ubuntu`
- Private key: the private key matching the EC2 key pair.

Create a Pipeline job:
1. Pipeline definition: **Pipeline script from SCM**.
2. SCM: Git.
3. Repository URL: your GitHub repository.
4. Branch: `*/main`.
5. Script path: `Jenkinsfile`.
6. Configure a GitHub webhook to `https://YOUR_JENKINS_URL/github-webhook/` if Jenkins is reachable securely, or use SCM polling.
7. Set the Jenkins job environment variables/parameters documented at the top of `Jenkinsfile`: `AWS_REGION`, `AWS_ACCOUNT_ID`, `EC2_HOST`, and `SSH_CREDENTIALS_ID`.

The Jenkins build machine's AWS identity needs ECR push permissions for the three repositories and `ecr:GetAuthorizationToken`. The EC2 role only needs ECR pull permissions.

## 7. Validate deployment

From your workstation:

```bash
curl http://EC2_PUBLIC_IP/api/users/health
curl http://EC2_PUBLIC_IP/api/products/health
curl http://EC2_PUBLIC_IP/api/orders/health
```

Expected JSON includes `"status":"ok"` and the service name.

On EC2:

```bash
cd /opt/microservices
docker compose ps
docker compose logs user-service
docker compose logs product-service
docker compose logs order-service
docker compose logs nginx
```

Monitoring dashboards are bound to localhost on the EC2 host to avoid public exposure. Use SSH tunnels from your workstation:

```bash
ssh -i /path/to/YOUR_KEY.pem -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 ubuntu@EC2_PUBLIC_IP
```

Then open:
- Grafana: `http://localhost:3000` (user `admin`, password from `.env`)
- Prometheus: `http://localhost:9090`

Grafana has a provisioned Prometheus data source. Import a Node Exporter dashboard from Grafana's dashboard catalogue if you want a richer host dashboard; also build/save a dashboard showing `up`, CPU, memory and disk metrics.

## 8. Failure simulation and recovery

Simulate an application container failure:

```bash
docker stop microservices-user-service-1
docker compose ps
docker compose logs user-service
```

Compose restart policy should bring the container back. If it does not:

```bash
docker compose up -d user-service
curl http://localhost/api/users/health
```

For a failed release, set `IMAGE_TAG` in the EC2 `.env` back to the previous known-good tag and run:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Keep at least one previous working image tag in ECR. Do not rely only on `latest`.

## 9. Evidence checklist for the assignment

Capture screenshots of:
- GitHub repository structure, branches, commits and webhook configuration.
- EC2 instance and security group inbound rules.
- `docker --version`, `docker compose version`, `aws --version`.
- Terraform `validate`, `plan`, `apply`, and outputs.
- Three ECR repositories with versioned images.
- Jenkins successful pipeline stages and console output.
- `docker compose ps` showing all containers healthy/running.
- Three service health endpoints through Nginx.
- Prometheus targets showing UP.
- Grafana data source and dashboard panels.
- Failure simulation, logs, recovery and successful health check.
- Terraform destroy after evidence collection.

## 10. Cleanup (avoid ongoing AWS charges)

After taking evidence and confirming the assignment is complete:

```bash
cd terraform
terraform destroy
```

ECR repositories are configured with `force_delete = true`, so Terraform can remove repositories and images. Confirm the plan before approving destruction. Also delete any manually created AWS resources not managed by this Terraform configuration.

## Notess

- This package is a learning/demo implementation with in-memory sample data. Data resets when a service container is recreated.
- The app does not require a database because the assignment only asks for three services and Docker Compose.
- Do not expose Grafana/Prometheus publicly. Use the SSH tunnel.
- Restrict SSH to your own approved IP. Avoid `0.0.0.0/0` for SSH.
- Use your organisation's approved security policies and AWS account limits.
