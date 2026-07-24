# 🌐 IoT Platform — Production-Grade DevOps Learning Lab

> A hands-on lab project for learning and demonstrating **production-grade DevOps** end-to-end: an IoT-oriented NestJS service deployed on **k3s**, secured, automated with **GitHub Actions**, and continuously delivered via **GitOps (Argo CD)**.

<p>
  <img alt="Runtime" src="https://img.shields.io/badge/runtime-Bun-black">
  <img alt="Framework" src="https://img.shields.io/badge/framework-NestJS-E0234E">
  <img alt="Kubernetes" src="https://img.shields.io/badge/k8s-k3s-326CE5">
  <img alt="GitOps" src="https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
</p>

---

## 🎯 Purpose of This Repo

This project is **not just an app — it's a learning lab**. The goal is to go from "it works on my machine" to a real, production-style DevOps setup, covering:

- 📡 An **IoT-facing backend** (device data ingestion / API layer)
- ☸️ **k3s** — a lightweight Kubernetes distribution, ideal for edge/IoT and homelab clusters
- 🔒 **Security-first deployment** (secrets management, private registry auth, least-privilege, image scanning)
- 🔁 **GitOps with Argo CD** — declarative, git-driven continuous delivery
- ⚙️ **CI/CD with GitHub Actions** — lint, typecheck, test, build, validate, deploy
- 🐳 **Docker** — multi-stage builds for small, secure production images

Every piece is intentionally documented so the repo doubles as **reference material** for the DevOps practices it implements.

---

## 📖 Table of Contents

- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Local Development](#-local-development)
- [Environment Variables & Secrets](#-environment-variables--secrets)
- [Docker](#-docker)
- [k3s Cluster Setup](#-k3s-cluster-setup)
- [Kubernetes Manifests](#-kubernetes-manifests)
- [Security](#-security)
- [CI — GitHub Actions](#-ci--github-actions)
- [CD — GitOps with Argo CD](#-cd--gitops-with-argo-cd)
- [Observability](#-observability)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🏗 Architecture

```
 IoT Devices / Simulators
        │  (HTTP/MQTT)
        ▼
 ┌───────────────────┐        ┌────────────────────┐
 │  NestJS API (Bun)  │──────▶│   Database / Store  │
 └───────────────────┘        └────────────────────┘
        │
        ▼ Docker image
 ┌───────────────────┐
 │  Docker Hub (priv) │
 └───────────────────┘
        │
        ▼ pulled by
 ┌───────────────────────────────────────────────┐
 │                    k3s Cluster                  │
 │  ┌───────────┐   ┌───────────┐   ┌───────────┐ │
 │  │ Deployment│   │  Service  │   │  Secrets  │ │
 │  └───────────┘   └───────────┘   └───────────┘ │
 └───────────────────────────────────────────────┘
        ▲
        │ syncs manifests from Git (GitOps)
 ┌───────────────────┐
 │      Argo CD        │
 └───────────────────┘
        ▲
        │ triggers on merge
 ┌───────────────────┐
 │  GitHub Actions CI  │
 └───────────────────┘
```

**Flow:** code is pushed → CI lints/tests/builds and pushes a Docker image → Kubernetes manifests are updated/validated → Argo CD detects the change in Git and reconciles the cluster state automatically (no manual `kubectl apply` in production).

---

## 🛠 Tech Stack

| Layer              | Technology                          |
|----------------------|--------------------------------------|
| Runtime             | [Bun](https://bun.sh)               |
| Framework           | [NestJS](https://nestjs.com/)       |
| Language            | TypeScript                          |
| Testing             | Jest (unit + coverage)              |
| Linting/Formatting  | ESLint + Prettier                   |
| Containerization    | Docker (multi-stage)                |
| Orchestration       | [k3s](https://k3s.io/) (lightweight Kubernetes) |
| GitOps / CD         | [Argo CD](https://argo-cd.readthedocs.io/) |
| CI                  | GitHub Actions                      |
| Registry            | Docker Hub (private, via imagePullSecrets) |

---

## 📁 Project Structure

```
.
├── .github/workflows/    # CI pipelines: manifest validation, lint/test/build, deploy
├── k8s/                  # Kubernetes manifests (Deployment, Service, Secrets, imagePullSecrets)
├── scripts/              # Helper scripts (e.g. k8s-deploy.sh)
├── src/                  # NestJS application source (IoT API / ingestion logic)
├── test/                 # Unit & e2e tests
├── dockerfile            # Multi-stage Docker build (Bun-based)
├── .dockerignore
├── nest-cli.json
├── jest-unit.json
├── tsconfig*.json
└── package.json
```

> As the GitOps setup matures, an `argocd/` (or a separate `gitops` repo) will hold Argo CD `Application` manifests — see [CD — GitOps with Argo CD](#-cd--gitops-with-argo-cd).

---

## 📋 Prerequisites

| Tool | Purpose |
|------|---------|
| [Bun](https://bun.sh) `>= 1.0` | Run/build the app locally |
| [Docker](https://www.docker.com/) | Build & run containers |
| [k3s](https://k3s.io/) | Lightweight Kubernetes cluster (single or multi-node) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Interact with the cluster |
| [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) *(optional)* | Manage GitOps applications |
| A Docker Hub account | Push/pull private images |

---

## 💻 Local Development

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
bun install
bun run start:dev
```

App runs at `http://localhost:3000` by default.

Common scripts:

| Script              | Description                          |
|----------------------|----------------------------------------|
| `bun run start:dev`  | Dev mode with hot reload              |
| `bun run build`      | Compile TypeScript                     |
| `bun run lint`       | ESLint checks                          |
| `bun run test`       | Unit tests                             |
| `bun run test:cov`   | Coverage (incl. json-summary reporter) |

---

## 🔐 Environment Variables & Secrets

Local development uses a `.env` file (never committed):

```env
PORT=3000
NODE_ENV=development
DATABASE_URL=postgres://user:password@localhost:5432/dbname
JWT_SECRET=change-me
```

In the cluster, secrets are **never hardcoded in manifests**. They're managed as native Kubernetes `Secret` objects (or, ideally, sealed/external secrets — see [Security](#-security)):

```bash
kubectl create secret generic app-secrets \
  --from-literal=DATABASE_URL=postgres://... \
  --from-literal=JWT_SECRET=...
```

---

## 🐳 Docker

Multi-stage `dockerfile` for a small, production-ready image built on Bun:

```bash
docker build -t <dockerhub-username>/<image-name>:latest .
docker run -p 3000:3000 --env-file .env <dockerhub-username>/<image-name>:latest
```

`.dockerignore` keeps the build context lean (excludes `node_modules`, tests, git metadata).

---

## ☸️ k3s Cluster Setup

[k3s](https://k3s.io/) is used because it's lightweight, single-binary, and well suited for **edge/IoT and homelab-style clusters** — a realistic environment for IoT workloads.

Install k3s on a node:

```bash
curl -sfL https://get.k3s.io | sh -
```

Grab the kubeconfig for remote use:

```bash
sudo cat /etc/rancher/k3s/k3s.yaml
```

Export it locally (used by both manual deploys and CI):

```bash
export KUBECONFIG=/path/to/your/k3s.yaml
kubectl get nodes
```

For multi-node setups, additional agents join with:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 K3S_TOKEN=<node-token> sh -
```

---

## ☸️ Kubernetes Manifests

Located in `k8s/`:

- **Deployment** — the app container, replica count, resource requests/limits, probes
- **Service** — internal/external exposure
- **Secret / imagePullSecret** — auth for pulling the private Docker Hub image

### Docker Hub pull secret

```bash
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<your-dockerhub-username> \
  --docker-password=<your-dockerhub-token> \
  --docker-email=<your-email>
```

Reference it in the Deployment spec:

```yaml
spec:
  imagePullSecrets:
    - name: regcred
```

### Manual apply (bypassing GitOps, e.g. for local testing)

```bash
export KUBECONFIG=/path/to/kubeconfig
./scripts/k8s-deploy.sh
# or
kubectl apply -f k8s/
```

---

## 🔒 Security

Security is treated as a first-class concern, not an afterthought:

- **No secrets in Git** — all sensitive values live in Kubernetes Secrets (or a secrets manager), injected at deploy time
- **Private registry auth** — images are pulled via `imagePullSecrets`, never made public
- **Least privilege** — service accounts and RBAC scoped to only what each workload needs
- **Manifest validation in CI** — Kubernetes YAML is validated *before* it ever reaches the cluster, catching misconfigurations early
- **Non-root containers** — the Docker image runs the app as a non-root user
- **Dependency hygiene** — lockfile (`bun.lock`) committed for reproducible, auditable installs
- **Immutable image tags** — deployments reference specific, versioned tags (not floating `latest`) once promoted to production

> 🧩 Planned hardening: image vulnerability scanning (e.g. Trivy) in CI, network policies, and Sealed Secrets / External Secrets Operator for GitOps-safe secret storage.

---

## ⚙️ CI — GitHub Actions

Workflows in `.github/workflows/` cover the full pipeline:

| Stage | What it does |
|-------|---------------|
| **Manifest validation** | Lints/validates Kubernetes YAML before anything touches the cluster |
| **Dependency caching** | Caches Bun dependencies to speed up subsequent runs |
| **Lint & Typecheck** | Enforces code quality and type safety |
| **Unit tests + coverage** | Runs Jest tests, generates coverage (json-summary) |
| **Build & Dockerize** | Builds the multi-stage Docker image |
| **Deploy** | Pushes the image and (where applicable) updates manifests for Argo CD to pick up |

Required repo secrets (**Settings → Secrets and variables → Actions**):

- `KUBECONFIG` — cluster access for direct-deploy workflows
- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` — push access to the private image repo

---

## 🔁 CD — GitOps with Argo CD

Rather than having CI run `kubectl apply` directly against production, the goal is a proper **GitOps loop**:

1. CI builds and pushes a new image, then updates the image tag in a manifest (in this repo's `k8s/` or a dedicated GitOps repo)
2. **Argo CD** continuously watches that Git path
3. Argo CD detects the diff and **automatically syncs** the cluster to match Git — Git is the single source of truth
4. Any manual `kubectl` drift gets self-healed back to the declared state

### Installing Argo CD on k3s

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Example Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: iot-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-org>/<your-repo>.git
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Access the Argo CD UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

> 📌 Status: this repo currently deploys via CI + `kubectl`/`scripts/k8s-deploy.sh`; migrating fully to Argo CD-managed sync is an active learning goal (see [Roadmap](#-roadmap)).

---

## 📊 Observability

Planned/in-progress:

- Liveness & readiness probes on the Deployment
- Centralized logs (e.g. Loki) and metrics (e.g. Prometheus + Grafana) for the k3s cluster
- Basic alerting on pod restarts / failed deployments

---

## 🗺 Roadmap

- [x] Dockerize the NestJS app with Bun
- [x] Deploy to k3s with private image pull secrets
- [x] CI: lint, typecheck, unit tests, coverage
- [x] CI: Kubernetes manifest validation
- [ ] Full GitOps handoff to Argo CD (automated sync + self-heal)
- [ ] Secrets management via Sealed Secrets / External Secrets Operator
- [ ] Image vulnerability scanning in CI (Trivy)
- [ ] Network policies & RBAC hardening
- [ ] Monitoring stack (Prometheus/Grafana/Loki)
- [ ] Simulated IoT device traffic for realistic load testing

---

## 🤝 Contributing

This is a learning repo, so contributions, questions, and "why did you do it this way" issues are welcome:

1. Fork and branch: `git checkout -b feat/my-feature`
2. Follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `ci:`, `docs:` — matches this repo's history)
3. Run `bun run lint` and `bun run test` before pushing
4. Open a Pull Request with context on *what* and *why*

---

## 📄 License

Licensed under the [MIT License](LICENSE).

---

<p align="center">A learning-by-building journey toward production-grade DevOps — IoT, k3s, security, and GitOps, all in one place. 🚀</p>
