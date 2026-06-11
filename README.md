# Cloud-Native Payment API on Amazon EKS

![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple?logo=terraform)
![AWS](https://img.shields.io/badge/AWS-EKS-orange?logo=amazon-aws)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-blue?logo=kubernetes)
![Docker](https://img.shields.io/badge/Docker-containerized-2496ED?logo=docker)

A production-oriented DevOps project demonstrating end-to-end deployment of a containerized application on Amazon EKS — covering Infrastructure as Code, Kubernetes operations, security, CI/CD automation, and observability.

> This project is built incrementally through sprints. Each sprint leaves the system in a fully functional, deployable state. The goal is not just a working application — it is a platform that reflects real production thinking.

---

## Table of Contents

- [Project Goals](#project-goals)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Sprint Documentation](#sprint-documentation)
  - [Sprint 0 — Terraform Backend Bootstrap](#sprint-0--terraform-backend-bootstrap)
  - [Sprint 1 — EKS Foundation and First Workload](#sprint-1--eks-foundation-and-first-workload)
  - [Sprint 2 — CI/CD Pipeline with GitHub Actions](#sprint-2--cicd-pipeline-with-github-actions)
- [Deployment](#deployment)
- [Future Sprints](#future-sprints)

---

## Project Goals

**Functional:**

- Deploy a Flask REST API on Kubernetes running on Amazon EKS
- Store container images in Amazon ECR with lifecycle management and scanning
- Expose health-check endpoints for Kubernetes probe integration
- Integrate with DynamoDB for persistent payment storage (Sprint 3)

**Non-Functional:**

- Infrastructure provisioned entirely through Terraform — no manual console operations
- Kubernetes-native deployment model with proper resource isolation
- Secure networking: workloads in private subnets, no public node exposure
- Pod-level IAM access through IRSA — no static AWS credentials (Sprint 3)
- Automated CI/CD pipeline with security gate — no manual deployments (Sprint 2)
- Horizontal scalability through HPA (Sprint 5)
- Full observability through Prometheus and Grafana (Sprint 6)

---

## Architecture

```
                        ┌─────────────────────────────────────────────┐
                        │              AWS eu-central-1                │
                        │                                              │
                        │   ┌──────────────────────────────────────┐  │
                        │   │           VPC 10.0.0.0/16            │  │
                        │   │                                      │  │
                        │   │  ┌─────────────┐ ┌───────────────┐  │  │
                        │   │  │  Public A   │ │   Public B    │  │  │
  kubectl / CI/CD ──────┼───┼──│ 10.0.1.0/24 │ │ 10.0.2.0/24  │  │  │
                        │   │  │  (future    │ │ (future ALB)  │  │  │
                        │   │  │   ALB)      │ │               │  │  │
                        │   │  └──────┬──────┘ └───────────────┘  │  │
                        │   │         │ NAT Gateway                │  │
                        │   │  ┌──────▼──────┐ ┌───────────────┐  │  │
                        │   │  │  Private A  │ │   Private B   │  │  │
                        │   │  │10.0.11.0/24 │ │10.0.12.0/24   │  │  │
                        │   │  │  EKS Node   │ │   EKS Node    │  │  │
                        │   │  │  Pod: API   │ │   Pod: API    │  │  │
                        │   │  └─────────────┘ └───────────────┘  │  │
                        │   │                                      │  │
                        │   │  EKS Control Plane (AWS Managed)     │  │
                        │   └──────────────────────────────────────┘  │
                        │                                              │
                        │   ┌──────────┐   ┌──────────────────────┐   │
                        │   │   ECR    │   │  DynamoDB (Sprint 3) │   │
                        │   │ (images) │   └──────────────────────┘   │
                        │   └──────────┘                               │
                        └─────────────────────────────────────────────┘
```

**Traffic flow (current — Sprint 2):**

| Source | Destination | Method |
|---|---|---|
| Developer | EKS API Server | `kubectl` via AWS IAM token |
| GitHub Actions | AWS STS | OIDC token → temporary credentials |
| GitHub Actions | ECR | Docker push via pipeline |
| GitHub Actions | EKS | `kubectl apply` via pipeline |
| EKS Nodes | ECR | Image pull via NAT Gateway |
| Developer | Application | `kubectl port-forward` (temporary) |

Public ingress via ALB will be introduced in Sprint 4.

---

## Project Structure

```
eks-platform/
├── terraform/
│   ├── bootstrap/                    # Sprint 0 — S3 + DynamoDB state backend
│   └── infrastructure/               # Sprint 1 — VPC + EKS + ECR + IAM
│       ├── backend.tf
│       ├── provider.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── modules/
│           ├── vpc/
│           ├── eks/
│           ├── ecr/
│           └── github-actions-iam/   # Sprint 2 — OIDC auth for pipeline
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── docs/
│   └── screenshots/                  # Sprint validation screenshots
└── .github/
    └── workflows/
        └── ci-cd.yml                 # Sprint 2 — GitHub Actions pipeline
```

---

## Sprint Documentation

---

### Sprint 0 — Terraform Backend Bootstrap

#### Objective

Before provisioning any infrastructure, a centralized and secure Terraform state backend was established. Using local state files in team or multi-sprint environments leads to state drift, accidental overwrites, and loss of infrastructure history. Solving this first — before any real resources exist — is the correct order of operations.

#### Components Implemented

**S3 Remote State**

An S3 bucket with versioning enabled stores all Terraform state files for the project. Versioning provides a recovery path in case of accidental state corruption or destructive operations.

**DynamoDB State Locking**

A DynamoDB table provides state locking — ensuring only one Terraform operation can execute at a time. Without locking, concurrent `terraform apply` runs can corrupt the state file in ways that are difficult to recover from.

#### Design Decisions

**Why a dedicated bootstrap module?**

The bootstrap resources (S3 bucket, DynamoDB table) cannot be managed by the same Terraform backend they are creating. They are provisioned once using local state, and from that point forward all other infrastructure uses the remote backend. This is the standard pattern for Terraform on AWS — the chicken-and-egg problem solved by explicit separation.

**Why S3 + DynamoDB instead of Terraform Cloud?**

This project runs entirely on AWS. Keeping state in S3 avoids introducing an external dependency, keeps all access control within IAM, and reflects the setup used in most AWS-based production environments.

#### Sprint Outcome

Terraform remote state operational. All subsequent infrastructure modules use the S3 backend with DynamoDB locking. Zero local state files exist outside the `bootstrap/` directory.

---

### Sprint 1 — EKS Foundation and First Workload

#### Objective

Provision a production-style Kubernetes platform on AWS and deploy the first application workload. The focus was on getting the infrastructure right — not just running pods, but understanding the decisions behind every layer.

This sprint establishes the foundation everything else builds on: networking, compute, container registry, and the first running workload. Every decision made here has consequences in later sprints.

#### Infrastructure Decisions

**VPC Design**

Worker nodes are deployed in private subnets with no public IP addresses. Public subnets are reserved for future load balancers (Sprint 4). This separation is not cosmetic — it means that even if a node is misconfigured, it cannot be reached directly from the internet. This is not a Security Group rule that can be accidentally changed — it is a routing decision with no path from the internet to a node in a private subnet.

A single NAT Gateway was deployed in `eu-central-1a`. The trade-off here is explicit: a single NAT Gateway is a potential availability bottleneck, but for a dev environment it reduces cost significantly. In a production multi-AZ setup, each private subnet would have its own NAT Gateway.

Public and private subnets are tagged with `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb` respectively. These tags are not optional — without them, the AWS Load Balancer Controller introduced in Sprint 4 cannot discover which subnets to use when creating ALB resources. Configuring them now avoids having to modify subnets later.

**EKS Cluster**

The Kubernetes control plane is fully managed by AWS. It is not accessible via SSH — all interactions go through the EKS API server using IAM-authenticated tokens generated by the AWS CLI. This is fundamentally different from self-managed Kubernetes clusters and was one of the first concepts to internalize during this sprint.

The OIDC provider was configured at cluster creation time, even though it is not used until Sprint 3. Configuring it now costs nothing and avoids modifying cluster configuration later. Without it, Sprint 3 (IRSA) would require an infrastructure change to an already-running cluster.

`endpoint_private_access = true` ensures that traffic between nodes and the API Server stays inside the VPC and does not traverse the public internet.

`enabled_cluster_log_types = ["api", "audit"]` — API logs capture all Kubernetes API calls for debugging. Audit logs record who did what on the cluster — useful when debugging IRSA issues in Sprint 3.

**Managed Node Group vs. EKS Auto Mode**

Managed Node Group was chosen over EKS Auto Mode deliberately. Auto Mode abstracts away node lifecycle entirely, which is convenient but reduces visibility into how worker infrastructure behaves. For a project focused on demonstrating Kubernetes knowledge, understanding node provisioning, instance types, and scaling configuration is more valuable than the operational convenience Auto Mode provides. Auto Mode is a reasonable production choice — Managed Node Group is a better learning choice.

Node instances use `t3.medium`. This is the minimum size that comfortably runs the application alongside system pods (CoreDNS, kube-proxy, VPC CNI) and leaves capacity for the Prometheus stack added in Sprint 6. `t3.small` was considered and ruled out due to memory pressure under monitoring workloads.

**IAM Roles**

Two IAM roles are required before a single node can join the cluster.

The cluster role is assumed by the EKS control plane itself — allows AWS to manage load balancers, security groups, and networking resources on behalf of the cluster.

The node role is assumed by every EC2 worker node at boot. Three policies are attached, each serving a distinct purpose:

| Policy | Purpose |
|---|---|
| `AmazonEKSWorkerNodePolicy` | Allows the node to register with the EKS control plane. Without this, the node cannot join the cluster. |
| `AmazonEKS_CNI_Policy` | Allows the VPC CNI plugin to manage network interfaces and IP addresses for pods. Without this, pods cannot get IP addresses. |
| `AmazonEC2ContainerRegistryReadOnly` | Allows the node to pull container images from ECR. The node pulls images before pods start — IRSA cannot be used at that point. |

All three policies are required. Removing any one breaks a different part of the cluster.

**ECR Repository**

ECR was configured with `scan_on_push = true` and a lifecycle policy that retains only the last 10 images. The lifecycle policy is often omitted in portfolio projects — it matters in practice because unmanaged ECR repositories accumulate images and eventually generate unexpected storage costs.

#### Security Decisions

Every security decision in this sprint was intentional rather than incidental:

- Worker nodes run in private subnets — no public IP exposure
- Container runs as non-root (`USER 1000` in Dockerfile, `runAsUser: 1000` in pod spec)
- `endpoint_private_access = true` on the EKS cluster — kubectl traffic stays within the VPC when possible
- No static AWS credentials anywhere — kubeconfig uses IAM token authentication
- ECR `scan_on_push` enabled — basic CVE detection before images run on the cluster

IRSA (pod-level IAM) is the remaining critical security piece, introduced in Sprint 3 when the application needs actual AWS service access.

#### Application

The Flask API exposes three endpoints: `GET /health`, `POST /payments`, and `GET /payments/{id}`. In Sprint 1 the application uses in-memory storage — payments are stored in a Python dictionary and lost on pod restart. This is intentional: DynamoDB integration comes in Sprint 3 once IRSA is configured. Building the data layer before the IAM layer would mean deploying the application with static AWS credentials — the wrong approach.

**Dockerfile layer ordering** — `requirements.txt` is copied and installed before `app.py`. Docker caches each layer independently. `app.py` changes on every commit. `requirements.txt` changes rarely. With this order, `pip install` uses the cache on every build where requirements have not changed — significantly faster builds.

#### Kubernetes Workload

**Namespace**

All resources are deployed in a dedicated `payment-api` namespace rather than `default`. This is a foundational practice — it enables RBAC scoping, resource quota enforcement, and network policy targeting. Using `default` in a real cluster is considered an anti-pattern.

**ServiceAccount**

A dedicated `payment-api` ServiceAccount is created and assigned to all pods. In Sprint 1 it has no annotations and no AWS permissions. It exists because pods should never run under the `default` ServiceAccount, and because in Sprint 3 a single annotation will be added to give it DynamoDB access through IRSA — no changes to the Deployment will be needed at that point.

**Deployment**

The Deployment runs two replicas with a `RollingUpdate` strategy (`maxSurge: 1`, `maxUnavailable: 0`). Setting `maxUnavailable: 0` means Kubernetes will never reduce capacity below the desired replica count during an update — new pods must become ready before old ones are terminated. This guarantees zero-downtime deployments even at this early stage.

Resource `requests` and `limits` are set on every container. Without requests, the Kubernetes scheduler cannot make informed placement decisions. Without limits, a misbehaving container can starve other pods on the same node. CPU limit causes throttling; memory limit causes OOMKill.

**Health Checks**

Both `livenessProbe` and `readinessProbe` target the `/health` endpoint:

- The readiness probe controls traffic routing. If it fails, Kubernetes removes the pod from the Service endpoints — the pod keeps running but receives no traffic. This is essential for safe rolling updates.
- The liveness probe controls pod lifecycle. If it fails three consecutive times, Kubernetes restarts the container. This handles scenarios where the process is running but has entered a broken state it cannot recover from.

The distinction between these two probes is frequently tested in Kubernetes interviews and misunderstood in practice. Configuring both correctly from the start reflects production thinking.

**Service**

A `ClusterIP` Service was used intentionally. Exposing the application directly via `NodePort` or `LoadBalancer` at this stage would work, but would bypass the proper ingress layer introduced in Sprint 4. `ClusterIP` keeps the application internal until a production-grade ALB Ingress is in place.

#### Challenges Encountered

**kubectl Authentication Failure**

After provisioning the cluster, all `kubectl` commands failed with:

```
exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

The root cause was a mismatch between the local `kubectl` binary (an older version) and the authentication mechanism expected by EKS 1.31. EKS moved from `v1alpha1` to `v1beta1` for the exec credential API in newer cluster versions.

The fix was upgrading `kubectl` to 1.31 and regenerating kubeconfig with `aws eks update-kubeconfig`. The lesson: `kubectl` version and cluster version do not need to be identical, but they must be close enough that the authentication API versions overlap. A gap of more than one minor version frequently causes this class of error.

**ECR Authentication Failure**

Initial `docker push` to ECR failed silently. The root cause was that Docker Desktop was not running — the Docker daemon was unavailable, so the ECR credential helper had nothing to authenticate to.

This highlights a non-obvious dependency: ECR authentication requires both valid AWS credentials and a running Docker daemon. The AWS CLI side succeeds and produces a token. The Docker side fails because there is no daemon to receive it — and the error messages from both tools point in different directions.

**Understanding EKS Control Plane Access**

The initial expectation was that cluster management would require SSH access to control plane nodes — the same mental model as self-managed Kubernetes. Amazon EKS abstracts the control plane entirely: there are no control plane nodes to SSH into.

`kubectl` is a client that communicates with the EKS API server endpoint over HTTPS. Authentication happens through an IAM token generated by the AWS CLI and embedded in the kubeconfig. This is a fundamental shift in operational model compared to self-managed clusters — control plane logs are accessed through CloudWatch rather than directly.

**Initial kubectl apply failed due to manifest ordering**

```
Error from server (NotFound): namespaces "payment-api" not found
```

`kubectl apply -f k8s/` applies manifests in alphabetical order. `deployment.yaml` is processed before `namespace.yaml`. The fix was applying the namespace first. The long-term fix is Helm (Sprint 5), which handles resource ordering automatically.

#### Validation

![Validation](docs/sprint-01-validation.png)  
*Two worker nodes in Ready state, two application pods Running, health check returning 200 via port-forward.*



#### Key Lessons Learned

**Private subnets provide a harder security boundary than Security Groups.** A Security Group rule can be changed accidentally. A missing route cannot be traversed regardless of any other configuration — there is simply no path from the internet to a node in a private subnet.

**Node IAM roles and pod IAM roles serve different purposes.** Nodes need broad permissions to function: join the cluster, manage pod networking, pull images. Pods need narrow permissions scoped to exactly what the application does. IRSA (Sprint 3) solves this by giving each pod its own scoped role.

**Dockerfile layer ordering is a performance decision.** Copying dependencies before application code exploits Docker's layer cache. Stable layers first, volatile layers last.

**Configure prereqs before they are needed.** The OIDC provider is unused in Sprint 1 but configured anyway. The ServiceAccount has no annotations in Sprint 1 but is created with the correct name. These decisions cost nothing and avoid modifying running infrastructure later.

---

### Sprint 2 — CI/CD Pipeline with GitHub Actions

#### Objective

The objective of Sprint 2 was to eliminate all manual deployment steps introduced in Sprint 1 and replace them with a fully automated, security-first CI/CD pipeline.

Before this sprint, every code change required a manual sequence: local Docker build, manual ECR authentication, manual image push, and manual `kubectl apply`. This approach does not scale, is error-prone, and — critically — requires long-lived AWS credentials stored somewhere accessible to the operator. Sprint 2 solves all of these problems at once.

The pipeline is built around three principles: no static AWS credentials anywhere, a security gate that blocks vulnerable images before they reach the cluster, and a clean separation between the build phase and the deploy phase.

#### Architecture

```
Developer
    │
    │  git push → main
    ▼
GitHub Actions Runner
    │
    ├── 1. OIDC token request → AWS STS
    │       └── STS validates token against GitHub OIDC provider
    │       └── Returns temporary credentials (15 min TTL)
    │
    ├── 2. CI Job
    │       ├── docker build
    │       ├── Trivy scan → CRITICAL CVE? → pipeline fails, nothing pushed
    │       └── docker push → ECR (only if scan passes)
    │
    └── 3. CD Job (only on push to main, not on PR)
            ├── aws eks update-kubeconfig
            ├── sed IMAGE_PLACEHOLDER → actual ECR URL:SHA tag
            ├── kubectl apply -f k8s/
            └── kubectl rollout status → verify deploy succeeded
```

#### Components Implemented

**IAM Role for GitHub Actions**

A dedicated IAM Role was created through Terraform in a new module `modules/github-actions-iam`.

**ECR policy** — scoped to the specific ECR repository ARN, not `*`. Allows only the operations needed for image push: layer upload, image put, authorization token.

**EKS policy** — allows only `eks:DescribeCluster` on the specific cluster ARN. This is the minimum required for `aws eks update-kubeconfig` to work. GitHub Actions cannot list clusters, cannot modify the cluster, cannot access other clusters in the account.

**OIDC Trust Policy**

The IAM Role trust policy uses two conditions:

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
},
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:adrian-cloud-devops/cloud-native-payment-api-eks:*"
}
```

The `aud` condition ensures the token was intended for AWS STS, not another service. The `sub` condition scopes the trust to a specific GitHub repository — even if another repository in the same GitHub organization tries to assume this role, it will be denied.

![IAM Trust Policy](docs/sprint-02-iam-trust-policy.png)
*IAM Role trust policy scoped to the specific GitHub repository — only this repo can assume the role*

**GitHub OIDC Provider in AWS**

A separate `aws_iam_openid_connect_provider` resource was created for GitHub's OIDC endpoint. This is distinct from the EKS OIDC provider created in Sprint 1 — that one is for pod-level IAM (IRSA), this one is for GitHub Actions authentication. Same protocol, different token issuers, different use cases:

| Provider | Authority | Purpose |
|---|---|---|
| EKS OIDC | AWS | Issues tokens for pods — enables IRSA |
| GitHub OIDC | GitHub | Issues tokens for pipeline runs — enables keyless auth |

The thumbprint `6938fd4d98bab03faadb97b34396831e3780aea1` is the SHA1 fingerprint of GitHub's OIDC certificate. AWS uses this to verify that tokens claiming to come from GitHub actually do — the same way a browser verifies an HTTPS certificate against a known CA.

**EKS Access Entry**

GitHub Actions needs not just AWS credentials but also Kubernetes RBAC permissions to deploy. EKS Access Entries were used to grant the GitHub Actions role the `AmazonEKSEditPolicy` scoped to the `payment-api` namespace only. GitHub Actions cannot touch `kube-system`, cannot read secrets from other namespaces, and cannot modify cluster-level resources.

#### Pipeline Design Decisions

**Why two separate jobs (ci and cd)?**

The `cd` job runs only when `github.event_name == 'push'` and `github.ref == 'refs/heads/main'`. Pull requests trigger only the `ci` job. This means every PR gets a build and security scan, but nothing gets deployed until code is merged to main.

**Why commit SHA as image tag?**

```yaml
echo "tag=${GITHUB_SHA::8}" >> $GITHUB_OUTPUT
```

The first 8 characters of the commit SHA are used as the image tag — traceability, immutability, auditability. The `:latest` tag is also pushed for convenience but the deployment always uses the SHA tag. Using `:latest` in a Deployment spec makes rollbacks ambiguous.

**Why Trivy before push?**

```
build → scan → (fail here if CRITICAL) → push
```

An image with a known critical vulnerability never reaches ECR and never reaches the cluster. `ignore-unfixed: true` means Trivy only fails on CVEs that have a known fix available.

**Why `kubectl rollout status` at the end?**

`kubectl apply` returns success as soon as the API server accepts the manifest — not when pods are actually running. `kubectl rollout status` blocks until pods are Ready or the 5-minute timeout is reached. Green pipeline means the application is actually running, not just that the manifest was accepted.

#### Security Model

| What | Old approach | This sprint |
|---|---|---|
| AWS auth in pipeline | IAM User + access key in GitHub Secrets | OIDC → temporary STS credentials (15 min TTL) |
| ECR permissions | Full ECR access or AdministratorAccess | Scoped to single repository, push operations only |
| EKS permissions | Full cluster access or cluster-admin | Edit policy scoped to `payment-api` namespace only |
| Vulnerable images | No gate | Trivy blocks CRITICAL CVEs before push |
| Credentials rotation | Manual | Not needed — credentials are ephemeral |

#### Workflow Structure

```yaml
on:
  push:
    branches: [main]      # triggers ci + cd
  pull_request:
    branches: [main]      # triggers ci only

jobs:
  ci:                     # runs on push AND pull_request
    - Configure AWS (OIDC)
    - Login to ECR
    - Generate image tag (SHA-based)
    - Docker build
    - Trivy scan (exit-code: 1 on CRITICAL)
    - Docker push (only if scan passes)

  cd:
    needs: ci             # waits for ci to complete successfully
    if: push to main      # skipped on pull_request
    - Configure AWS (OIDC)
    - Configure kubectl
    - Deploy (sed IMAGE_PLACEHOLDER + kubectl apply)
    - Verify rollout
```

#### Challenges Encountered

**OIDC authentication failing — wrong repository name**

```
Error: Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The root cause was a mismatch between the GitHub repository name in `terraform.tfvars` (`eks-platform`) and the actual repository name on GitHub (`cloud-native-payment-api-eks`). The IAM trust policy `StringLike` condition is case-sensitive — any mismatch causes an immediate denial.

The fix was correcting `github_repository` in `terraform.tfvars` and running `terraform apply` to update only the trust policy. Terraform did not rebuild any infrastructure — it only modified the IAM role's trust relationship document.

**EKS authentication mode incompatible with Access Entries**

```
InvalidRequestException: The cluster's authentication mode must be set
to one of [API, API_AND_CONFIG_MAP] to perform this operation.
```

The EKS cluster was created with the default `CONFIG_MAP` only authentication mode, which does not support the Access Entries API. The cluster authentication mode was updated without rebuilding:

```bash
aws eks update-cluster-config \
  --name payment-api-eks \
  --region eu-central-1 \
  --access-config authenticationMode=API_AND_CONFIG_MAP
```

Going forward, the EKS Terraform module explicitly sets `authentication_mode = "API_AND_CONFIG_MAP"` to avoid this on future cluster builds.

**Hardcoded image URL masked a silent pipeline misconfiguration**

`deployment.yaml` initially contained a hardcoded ECR URL with `:latest` instead of `IMAGE_PLACEHOLDER`. The pipeline appeared to work — pods were running, health checks passed. However, the `sed` substitution step was silently doing nothing because `IMAGE_PLACEHOLDER` was not present in the file. Every deploy was using whatever image was already tagged `:latest` in ECR, not the SHA-tagged image built by the current run.

The pipeline's core feature — traceability via SHA tags — was not functioning. A deploy would show green even if the ECR push had failed.

The fix was replacing the hardcoded URL with `IMAGE_PLACEHOLDER` in `deployment.yaml`. The lesson: a passing pipeline is not proof the pipeline does what you think. Validating the actual outcome — checking the image tag on the running pod after deploy — is a necessary verification step.

**Two OIDC providers, one protocol — initial confusion**

During implementation it was initially unclear why the project has two separate OIDC providers. Both use the same OIDC protocol but serve entirely different purposes. The EKS OIDC provider authenticates pods (IRSA) — AWS is the authority. The GitHub OIDC provider authenticates pipeline runs — GitHub is the authority. Keeping them mentally separate is important when debugging authentication failures: an OIDC error in the pipeline is always a GitHub provider issue, never an EKS provider issue.

#### Validation

![Pipeline Success](docs/sprint-02-pipeline-success.png)
*Both CI and CD jobs completed successfully — total duration 1m 4s.*

![Trivy Scan](docs/sprint-02-trivy-scan.png)
*Zero vulnerabilities detected. Pipeline proceeded to push only after this gate passed.*

![ECR Images](docs/sprint-02-ecr-images.png)
*Image tagged with commit SHA `4561ca0e` alongside `:latest` — full traceability from pod to commit.*

#### Key Lessons Learned

**OIDC is the correct authentication pattern for CI/CD on AWS.** OIDC tokens are ephemeral by design — issued per-run, scoped to the specific repository, expire automatically. There is no credential to rotate, no secret to leak, and no manual intervention required.

**A green pipeline is not proof the pipeline does what you think.** Silent failures are harder to catch than loud ones. The hardcoded image URL showed that a pipeline can appear healthy while a core feature is not functioning.

**Two OIDC providers, one protocol.** EKS OIDC authenticates pods, GitHub OIDC authenticates pipeline runs. Same protocol, different token issuers — keeping them mentally separate avoids confusion when debugging.

**Namespace isolation compounds across the stack.** GitHub Actions role scoped to `payment-api` namespace, ECR policy scoped to `payment-api` repository, application running in `payment-api` namespace — each layer independently enforces the same boundary.

#### Sprint Outcome

From this sprint forward, the deployment workflow is:

```
git push → pipeline runs → image built and scanned → deployed to EKS → rollout verified
```

No manual steps. No AWS credentials on any developer machine. No unscanned images reaching the cluster. Every deployment traceable to a specific commit SHA.

---

## Deployment

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate permissions
- kubectl >= 1.28
- Docker

### Bootstrap (first time only)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### Infrastructure

```bash
cd terraform/infrastructure
terraform init
terraform validate
terraform plan
terraform apply
```

### Configure kubectl

```bash
aws eks update-kubeconfig \
  --region eu-central-1 \
  --name payment-api-eks
```

### Initial image push (first time only)

```bash
ECR_URL=$(cd terraform/infrastructure && terraform output -raw ecr_repository_url)

aws ecr get-login-password --region eu-central-1 \
  | docker login --username AWS --password-stdin $ECR_URL

docker build -t payment-api ./app
docker tag payment-api:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### Deploy to Kubernetes

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
kubectl get pods -n payment-api
```

> From Sprint 2 onwards all deployments are handled automatically by the CI/CD pipeline on every push to `main`.

---

## Future Sprints

| Sprint | Focus | Key Additions |
|---|---|---|
| Sprint 3 | DynamoDB + IRSA | Pod-level IAM, persistent storage, zero access keys |
| Sprint 4 | Public Ingress | AWS Load Balancer Controller, ALB, public endpoint |
| Sprint 5 | Production Readiness | HPA, PDB, Helm chart, RBAC hardening |
| Sprint 6 | Observability | Prometheus, Grafana, Alertmanager, PVC |
| Upgrade 1 | External Secrets | AWS Secrets Manager → k8s Secret |
| Upgrade 2 | NetworkPolicy | Namespace isolation, deny-all default |
| Upgrade 3 | ArgoCD | GitOps flow, separate config repo |
| Upgrade 4 | Multi-Environment | Helm overlays, dev/prod separation |
| Upgrade 5 | Loki | Log aggregation, correlated metrics and logs |

---

[⬆ Back to top](#cloud-native-payment-api-on-amazon-eks)