# GCP Security Suite Deployment

Secure your applications with **SonarQube**, **DefectDojo**, and a centralized **Dependency Check NVD Database**—all deployed on a cost-optimized GCP `e2-custom-4-8192` instance.

---

## 🚀 Key Features

- ✅ **SonarQube (SAST)**: Automated code analysis for 10+ languages.
- ✅ **DefectDojo (Vulnerability Hub)**: Consolidate findings from all your tools in one place.
- ✅ **Centralized NVD Database**: Skip the slow 250MB downloads in your CI/CD pipelines. All apps scan against a local cached copy on the server.
- ✅ **GCP Optimized**: Deployed on a single `e2-custom-4-8192` instance (4 vCPU, 8GB RAM) with a 16GB swapfile configured by Ansible.
- ✅ **Automated CI/CD**: One-click deployment from GitHub Actions using static Service Account keys.

---

## 🏗 Architecture

- **Provider**: Google Cloud Platform (GCP)
- **Instance**: `e2-custom-4-8192` (Ubuntu 22.04)
- **Orchestration**: Docker Compose
- **Reverse Proxy**: Nginx (Path-based routing: `/sonar`, `/dojo`)
- **Database**: PostgreSQL 15 (Shared across all services)

---

## 🛠 Setup & Deployment

### 1. GCP Preparation (One-time Setup)
Run this **single command** in your **GCP Cloud Shell** to enable APIs and generate the required access key for the lab. The key content will be printed to your terminal:

```bash
# Enable APIs and print the Key for the Default Service Account
gcloud services enable cloudresourcemanager.googleapis.com compute.googleapis.com && \
gcloud iam service-accounts keys create lab-master-key.json --iam-account=$(gcloud iam service-accounts list --filter="name:compute@developer.gserviceaccount.com" --format="value(email)") && \
cat lab-master-key.json
```

### 2. GitHub Secrets
Add the following secrets to your repository:
- `GCP_SA_KEY`: The content of the JSON key printed above.
- `GCP_PROJECT_ID`: Your GCP Project ID.
- `DB_PASSWORD`: Password for the shared PostgreSQL instance.
- `SONAR_ADMIN_PASSWORD`: Secure password for the SonarQube `admin` user.
- `NVD_API_KEY`: (Recommended) Get a free key from NIST to speed up the initial NVD sync.

### 3. Deploy
Push to the `DevSecOps-CI-CD-Pipeline` branch or manually trigger the **"Deploy to GCP"** workflow.

---

## 📖 Integrating your Apps

### SonarQube (SAST)
In your application's GitHub Actions:
```yaml
- name: SonarQube Scan
  uses: sonarsource/sonarqube-scan-action@master
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_HOST_URL: http://<INSTANCE_IP>/sonar
```

### Dependency Check (SCA)
Perform lightning-fast scans using the centralized database on your server:
```bash
dependency-check.sh --project "MyProject" --scan . \
  --dbDriverName org.postgresql.Driver \
  --connectionString "jdbc:postgresql://<INSTANCE_IP>:5432/dependency_check" \
  --dbUser scanner_user --dbPassword ${{ secrets.SCANNER_DB_PASSWORD }}
```

---

## 🔒 Security Summary
- **Postgres (5432)**: Exposed to allow external CI/CD scanners to talk to the NVD cache.
- **Nginx (80)**: Reverse proxy for web dashboards.
- **SSH (22)**: Management access.
