
raw
Readme · MD
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
- [Deployment](#deployment)
- [Future Sprints](#future-sprints)
---
 
## Project Goals
 
**Functional:**
 
- Deploy a Flask REST API on Kubernetes running on Amazon EKS
- Store container images in Amazon ECR with lifecycle management and scanning
- Expose health-check endpoints for Kubernetes probe integration
- Integrate with DynamoDB for persistent payment storage (Sprint 2)
**Non-Functional:**
 
- Infrastructure provisioned entirely through Terraform — no manual console operations
- Kubernetes-native deployment model with proper resource isolation
- Secure networking: workloads in private subnets, no public node exposure
- Pod-level IAM access through IRSA — no static AWS credentials (Sprint 2)
- Horizontal scalability through HPA (Sprint 5)
- Full observability through Prometheus and Grafana (Sprint 6)
---
 
## Architecture
 
```
                        ┌─────────────────────────────────────────────┐
                        │              AWS eu-central-1               │
                        │                                             │
                        │   ┌──────────────────────────────────────┐  │
                        │   │           VPC 10.0.0.0/16            │  │
                        │   │                                      │  │
                        │   │  ┌─────────────┐ ┌───────────────┐   │  │
                        │   │  │  Public A   │ │   Public B    │   │  │
  kubectl / CI/CD ──────┼───┼──│ 10.0.1.0/24 │ │ 10.0.2.0/24   │   │  │
                        │   │  │  (future    │ │  (future ALB) │   │  │
                        │   │  │   ALB)      │ │               │   │  │
                        │   │  └──────┬──────┘ └───────────────┘   │  │
                        │   │         │ NAT Gateway                │  │
                        │   │  ┌──────▼──────┐ ┌───────────────┐   │  │
                        │   │  │  Private A  │ │   Private B   │   │  │
                        │   │  │10.0.11.0/24 │ │10.0.12.0/24   │   │  │
                        │   │  │             │ │               │   │  │
                        │   │  │  EKS Node   │ │   EKS Node    │   │  │
                        │   │  │  Pod: API   │ │   Pod: API    │   │  │
                        │   │  └─────────────┘ └───────────────┘   │  │
                        │   │                                      │  │
                        │   │  EKS Control Plane (AWS Managed)     │  │
                        │   └──────────────────────────────────────┘  │
                        │                                             │
                        │   ┌──────────┐   ┌──────────┐               │
                        │   │   ECR    │   │ DynamoDB │               │
                        │   │ (images) │   │ Sprint 2 │               │
                        │   └──────────┘   └──────────┘               │
                        └─────────────────────────────────────────────┘
```
 
**Traffic flow (current — Sprint 1):**
 
| Source | Destination | Method |
|---|---|---|
| Developer | EKS API Server | `kubectl` via AWS IAM token |
| EKS Nodes | ECR | Pull via NAT Gateway |
| EKS Nodes | AWS APIs | Outbound via NAT Gateway |
| Developer | Application | `kubectl port-forward` (temporary) |
 
Public ingress via ALB will be introduced in Sprint 4.
 
---
 
## Project Structure
 
```
eks-platform/
├── terraform/
│   ├── bootstrap/              # Sprint 0 — S3 + DynamoDB state backend
│   └── infrastructure/         # Sprint 1 — VPC + EKS + ECR
│       ├── backend.tf
│       ├── provider.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── modules/
│           ├── vpc/
│           ├── eks/
│           └── ecr/
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── .github/
    └── workflows/              # Sprint 3 — GitHub Actions CI/CD
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
 
#### Infrastructure Decisions
 
**VPC Design**
 
Worker nodes are deployed in private subnets with no public IP addresses. Public subnets are reserved for future load balancers (Sprint 4). This separation is not cosmetic — it means that even if a node is misconfigured, it cannot be reached directly from the internet.
 
A single NAT Gateway was deployed in `eu-central-1a`. The trade-off here is explicit: a single NAT Gateway is a potential availability bottleneck, but for a dev environment it reduces cost significantly. In a production multi-AZ setup, each private subnet would have its own NAT Gateway.
 
Public and private subnets are tagged with `kubernetes.io/role/elb` and `kubernetes.io/role/internal-elb` respectively. These tags are not optional — without them, the AWS Load Balancer Controller introduced in Sprint 4 cannot discover which subnets to use when creating ALB resources.
 
**EKS Cluster**
 
The Kubernetes control plane is fully managed by AWS. It is not accessible via SSH — all interactions go through the EKS API server using IAM-authenticated tokens generated by the AWS CLI. This is fundamentally different from self-managed Kubernetes clusters and was one of the first concepts to internalize during this sprint.
 
The OIDC provider was configured at cluster creation time, even though it is not used until Sprint 2. The trade-off: configuring it now avoids having to patch the cluster later, and it is a zero-cost addition that unblocks IRSA without any infrastructure change.
 
**Managed Node Group vs. EKS Auto Mode**
 
Managed Node Group was chosen over EKS Auto Mode deliberately. Auto Mode abstracts away node lifecycle entirely, which is convenient but reduces visibility into how worker infrastructure behaves. For a project focused on demonstrating Kubernetes knowledge, understanding node provisioning, instance types, and scaling configuration is more valuable than the operational convenience Auto Mode provides. Auto Mode is a reasonable production choice — Managed Node Group is a better learning choice.
 
Node instances use `t3.medium`. This is the minimum size that comfortably runs the application alongside system pods (CoreDNS, kube-proxy, VPC CNI) and leaves capacity for the Prometheus stack added in Sprint 6. `t3.small` was considered and ruled out due to memory pressure under monitoring workloads.
 
**ECR Repository**
 
ECR was configured with `scan_on_push = true` and a lifecycle policy that retains only the last 10 images. The lifecycle policy is often omitted in portfolio projects — it matters in practice because unmanaged ECR repositories accumulate images and eventually generate unexpected storage costs.
 
#### Security Decisions
 
Every security decision in this sprint was intentional rather than incidental:
 
- Worker nodes run in private subnets — no public IP exposure
- Container runs as non-root (`USER 1000` in Dockerfile, `runAsUser: 1000` in pod spec)
- `endpoint_private_access = true` on the EKS cluster — kubectl traffic stays within the VPC when possible
- No static AWS credentials anywhere — kubeconfig uses IAM token authentication
- ECR `scan_on_push` enabled — basic CVE detection before images run on the cluster
IRSA (pod-level IAM) is the remaining critical security piece, introduced in Sprint 2 when the application needs actual AWS service access.
 
#### Kubernetes Workload
 
**Namespace**
 
All resources are deployed in a dedicated `payment-api` namespace rather than `default`. This is a foundational practice — it enables RBAC scoping, resource quota enforcement, and network policy targeting. Using `default` in a real cluster is considered an anti-pattern.
 
**Deployment**
 
The Deployment runs two replicas with a `RollingUpdate` strategy (`maxSurge: 1`, `maxUnavailable: 0`). Setting `maxUnavailable: 0` means Kubernetes will never reduce capacity below the desired replica count during an update — new pods must become ready before old ones are terminated. This guarantees zero-downtime deployments even at this early stage.
 
Resource `requests` and `limits` are set on every container. This is not optional for production workloads — without requests, the Kubernetes scheduler cannot make informed placement decisions, and without limits, a misbehaving container can starve other pods on the same node.
 
**Health Checks**
 
Both `livenessProbe` and `readinessProbe` target the `/health` endpoint:
 
- The readiness probe controls traffic routing. If it fails, Kubernetes removes the pod from the Service endpoints — the pod keeps running but receives no traffic. This is essential for safe rolling updates.
- The liveness probe controls pod lifecycle. If it fails, Kubernetes restarts the container. This handles scenarios where the process is running but has entered a broken state it cannot recover from.
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
 
The fix was straightforward — upgrade `kubectl` to 1.31 and regenerate kubeconfig with `aws eks update-kubeconfig`. The lesson: `kubectl` version and cluster version do not need to be identical, but they must be close enough that the authentication API versions overlap. A gap of more than one minor version frequently causes this class of error.
 
**ECR Authentication Failure**
 
Initial `docker push` to ECR failed silently. The root cause was that Docker Desktop was not running — the Docker daemon was unavailable, so the ECR credential helper had nothing to authenticate to.
 
This is a trivial fix (start Docker Desktop), but it highlights a non-obvious dependency: ECR authentication requires both valid AWS credentials *and* a running Docker daemon. The AWS CLI side succeeds, but the Docker side fails — and the error messages from both tools point in different directions.
 
**Understanding EKS Control Plane Access**
 
The initial expectation was that cluster management would require SSH access to control plane nodes — the same mental model as self-managed Kubernetes. Amazon EKS abstracts the control plane entirely: there are no control plane nodes to SSH into.
 
`kubectl` is a client that communicates with the EKS API server endpoint over HTTPS. Authentication happens through an IAM token generated by the AWS CLI and embedded in the kubeconfig. There is no need for — and no way to achieve — direct access to the machines running the Kubernetes control plane. This is a fundamental shift in operational model compared to self-managed clusters.
 
#### Validation
 ![Validation](docs/sprint-01-validation.png)

 
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
 
### Build and Push Image
 
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
kubectl apply -f k8s/
kubectl get pods -n payment-api
```
 
---
 
## Future Sprints
 
| Sprint | Focus | Key Additions |
|---|---|---|
| Sprint 2 | DynamoDB + IRSA | Pod-level IAM, persistent storage, zero access keys |
| Sprint 3 | CI/CD | GitHub Actions, OIDC auth, Trivy scan, automated deploy |
| Sprint 4 | Public Ingress | AWS Load Balancer Controller, ALB, public endpoint |
| Sprint 5 | Production Readiness | HPA, PDB, Helm chart, RBAC hardening |
| Sprint 6 | Observability | Prometheus, Grafana, Alertmanager, PVC |
| Upgrade 1 | NetworkPolicy | Namespace isolation, deny-all default |
| Upgrade 2 | ArgoCD | GitOps flow, separate config repo |
| Upgrade 3 | Multi-Environment | Helm overlays, dev/prod separation |
| Upgrade 4 | Loki | Log aggregation, correlated metrics and logs |
 
---
 
[⬆ Back to top](#cloud-native-payment-api-on-amazon-eks)