# GCP Cloud Run V2Ray Multi-Protocol Deployment

This project provides a simple, automated deployment script for running XRay (V2Ray-compatible) on Google Cloud Run. It supports multiple protocols (VLESS over WebSocket, VLESS over gRPC, and Trojan) in a single configuration, making it flexible for VPN/proxy setups. The setup uses a lightweight Alpine-based Docker image and deploys serverlessly on Cloud Run for auto-scaling and cost efficiency.

## Features
- **Multi-Protocol Support**: VLESS-WS, VLESS-gRPC, and Trojan on a single port (8080).
- **Interactive Setup**: Bash script guides you through protocol, region, CPU/memory, and Telegram notifications.
- **Auto-Configuration**: Generates UUIDs, updates config.json, and creates client share links.
- **Health Checks**: Built-in HTTP fallback for Cloud Run readiness probes.
- **Telegram Integration**: Optional notifications for deployment success/failure.
- **Resource Flexibility**: Supports up to 16 CPU cores and 32Gi memory (note: Cloud Run quotas may limit to 8 vCPU; request increases if needed).

**Note on Trojan**: Trojan requires raw TCP/TLS, which Cloud Run does not fully support (HTTP/WS/gRPC only). It may work partially but is not recommended—use VLESS for reliability.

## Prerequisites
- Google Cloud SDK (`gcloud`) installed and authenticated: [Install gcloud](https://cloud.google.com/sdk/docs/install).
- Git installed.
- A GCP project with billing enabled.
- Enable required APIs: Cloud Run, Cloud Build, IAM (script handles this).
- Docker (optional, for local testing).

## Quick Start
   **Clone the Repo**
   https://github.com/ahlflk/GCP-V2RAY.git

Made with ❤️ by [AHLFLK2025channel](https://t.me/AHLFLK2025channel)

---

## #Crd

---

## 🚀 Cloud Run One-Click GCP-V2RAY

Run this script directly in **Google Cloud Shell**:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ahlflk/GCP-V2RAY/refs/heads/main/gcp-v2ray.sh)
Run this script directly in **Google Cloud Shell**:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ahlflk/GCP-VLESS/refs/heads/main/gcp-vless-sh)
