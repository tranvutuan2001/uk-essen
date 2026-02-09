# Kubernetes GitOps Demo Environment

> **Note:** This repository is intended for **demonstration purposes only** and is not production-ready. It provisions a local Kubernetes cluster using `kind` and manages applications via Argo CD in a GitOps fashion.

## Overview

This project provides a fully automated local Kubernetes environment demonstrating a modern cloud-native stack. It uses **Argo CD** to manage the lifecycle of all applications. The core architecture follows the "App of Apps" pattern, where a root application acts as the entry point to manage other manifest definitions located in the `apps/` directory.

Any changes committed to the `apps/` folder are automatically synchronized to the cluster by the root Argo CD application.

### Key Components

The cluster hosts the following integrated stack:

1.  **S3 Storage:** [MinIO](https://min.io/) (Object storage)
2.  **PostgreSQL Database:** High-availability cluster managed by [CloudNativePG (CNPG)](https://cloudnative-pg.io/)
3.  **Secrets Management:** [OpenBao](https://openbao.org/) (Vault fork)
4.  **API Gateway:** Envoy Gateway with Gateway API configuration
5.  **Debugging & Transport:** BusyBox and a dummy Nginx server for connectivity testing

---

## Repository Structure

- **`bootstraps/`**: The entry point for cluster initialization. Contains the Argo CD installation manifests, the `root-app` definition, and scripts for initializing secrets.
- **`apps/`**: Argo CD Application definitions. This directory serves as the source of truth for what is deployed in the cluster.
- **`infra/`**: The detailed Kubernetes manifests (Deployments, Services, ConfigMaps, CRDs) referenced by the applications in `apps/`.
- **`kind/`**: Configuration and scripts to provision the local Kubernetes cluster using `kind`.

---

## Getting Started

### Prerequisites

*   **Docker Desktop** (or a compatible container runtime)
*   **[kind](https://kind.sigs.k8s.io/)** (Kubernetes in Docker)
*   **kubectl** CLI tool
*   **Hardware:** Minimum **8 GB RAM** recommended due to the number of components.

### Installation

Follow these steps to spin up the environment:

#### 1. Provision the Cluster
Navigate to the `kind` directory and execute the creation script:

```bash
cd kind
chmod +x ./create-cluster.sh
./create-cluster.sh
```

#### 2. Initialize Applications
Navigate to the `bootstraps` directory and initialize Argo CD and the root application:

```bash
cd bootstraps
chmod +x ./init.sh
./init.sh
```

> ⏳ **Wait:** Allow a few minutes for the `argocd` and other namespaces (like `postgres`, `openbao`) to be created and for the CRDs to be registered.

#### 3. Initialize Secrets
Once the namespaces exist, apply the necessary secrets:

```bash
chmod +x ./init-secret.sh
./init-secret.sh
```

> **Tip:** If `./init-secret.sh` fails with a "namespace not found" error, wait a few more minutes for the Argo CD sync to create the namespaces, then retry.

#### 4. Access OpenBao
To login to OpenBao UI, you'll need the root token. You can retrieve it using the provided script:

```bash
chmod +x ./get-openbao-token.sh
./get-openbao-token.sh
```

### 5. Access User Interfaces (Port Forwarding)

Due to current gateway limitations, you need to use port forwarding to access the web interfaces of the deployed components.

#### MinIO (Object Storage)
*   **Command:** `kubectl port-forward svc/minio-application-console -n minio 9001:9001`
*   **URL:** [http://localhost:9001](http://localhost:9001)
*   **Credentials:**
    *   **Username:** `admin`
    *   **Password:** `admin123456`

#### OpenBao (Secrets Management)
*   **Command:** `kubectl port-forward svc/openbao -n openbao 8200:8200`
*   **URL:** [http://localhost:8200](http://localhost:8200)
*   **Credentials:**
    *   **Method:** Token authentication.
    *   **Token:** Run `./bootstraps/get-openbao-token.sh` to retrieve the root token.

#### Argo CD (GitOps)
*   **Command:** `kubectl port-forward svc/argocd-server -n argocd 8080:443`
*   **URL:** [https://localhost:8080](https://localhost:8080)
*   **Credentials:**
    *   **Username:** `admin`
    *   **Password:** Follow the [official documentation](https://argo-cd.readthedocs.io/en/stable/getting_started/) to retrieve the initial admin password.

---

## Architecture & Design Decisions

### 1. Kind vs. Minikube
**Kind (Kubernetes in Docker)** was selected over Minikube primarily due to better compatibility with Persistent Volume Claims (PVCs) on macOS environments. Kind provides a multi-node cluster simulation using Docker containers, which closely mirrors a real node topology for testing scheduling constraints.

### 2. Database High Availability & Topology Constraints
The Postgres cluster utilizes the **CloudNativePG (CNPG)** operator to manage lifecycle and high availability.
- **Cluster Topology:** The Kind cluster is configured with **4 nodes** (1 Control Plane, 3 Workers).
- **Replica Configuration:** The Postgres cluster requests **6 replicas**.
- **Scheduling Constraints:** `podAntiAffinity` is configured to `required`, enforcing one database pod per node.

**Outcome:** You will observe only **3 replicas** running (one per worker node). The remaining requested replicas will stay pending.
- **Node Failure:** If a node fails, CNPG attempts to handle failover.
- **Promotions:** If the node running the Primary pod fails, a Standby on another node is promoted.
- **Rescheduling:** In a more capable environment with sufficient nodes, failed pods would be rescheduled elsewhere. In this constrained 3-worker environment, we have reached physical capacity, preserving the "one replica per node" rule to ensure data integrity and true HA.

### 3. Backup & Disaster Recovery Strategy
**MinIO** acts as the S3-compatible backend for database backups, demonstrating a self-contained backup loop within the cluster.
- **Frequency:** Backups are scheduled to run hourly.
- **Retention:** Policy is set to one day.
- **Method:** The current setup performs standard object store backups (barmanObjectStore). This is **not a WAL (Write-Ahead Log) archive** backup.
    - **Implication:** Point-in-Time Recovery (PITR) to the exact second before a crash is not possible; restoration is limited to the last successful snapshot.
- **Restoration:** To restore, update the cluster manifest to use `.bootstrap.recover` instead of `.bootstrap.initdb`.
- **Production Note:** In a real production scenario, the S3 bucket should inevitably reside **outside** the cluster (e.g., AWS S3, Google Cloud Storage) across multiple regions to survive a total cluster failure. WAL archiving should be enabled for critical systems to allow full PITR.

### 4. TLS & Certificate Management
This demo uses a simplified TLS setup appropriate for a local (no-DNS) environment.

- **Current Implementation (Self-Signed):**
    - High-level DNS resolution does not exist for the local `kind` cluster.
    - HTTPS traffic is terminated at the Envoy Gateway using a manual Kubernetes Secret (`gateway-tls`) containing a **self-signed wildcard certificate**.
    - **How it works:** The Gateway listener is hardcoded to reference this secret. Since the certificate is not issued by a known public Certificate Authority (CA), browsers will flag connections as insecure. For local testing, these warnings can be safely ignored or bypassed.

- **Production Strategy (ACME & cert-manager):**
    - A production environment would utilize cert-manager to automate certificate issuance and renewal.
    - Certificates would be obtained from a trusted CA (e.g., Let's Encrypt) using the ACME protocol.
    - DNS challenges would be employed to validate domain ownership, requiring proper DNS records.

### 5. Secrets Management
**Important:** For this demonstration, secrets (e.g., database credentials, TLS certificates) are checked directly into the repository in the `bootstraps/secret/` folder. This is strictly for demo purposes to simplify setup and avoid external dependencies.

---

## Limitations

This setup has several critical limitations that make it unsuitable for production use:

1.  **Colocated Backups:** As mentioned earlier, since MinIO also resides inside the cluster, if a disaster occurs to the cluster causing data loss in both the PostgreSQL DB and MinIO, the database data is permanently lost.
2.  **OpenBao Auto-Unseal Risks:** OpenBao is configured to work with an auto-unseal mechanism using a transit server running in dev mode. This imposes two critical vulnerabilities:
    -   **Security Breach:** The transit server running in dev mode is a security risk.
    -   **Data Loss Risk:** The transit server (in dev mode) uses in-memory storage. If the transit server is completely deleted for any reason, the main OpenBao pods cannot be unsealed anymore. In this scenario, the data stored in the sealed OpenBao is considered lost. To restore functionality, both the transit server and the main OpenBao cluster must be deleted and re-initialized.
3.  **API Gateway Connectivity:** Gateway does not work correctly and needs further development to be able to expose the component to localhost. For now, you have to perform port forwarding on services you need such as OpenBao, MinIO, Argo Server, to be able to see their UI.
