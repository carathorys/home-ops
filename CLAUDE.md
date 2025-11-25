# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a GitOps-managed Kubernetes cluster configuration using Talos Linux as the OS and Flux for continuous deployment. The repository is structured to deploy applications on bare-metal or VM infrastructure with a focus on home operations.

## Key Commands

### Development Environment Setup
```bash
# Install tools via mise
mise trust && mise install

# Generate initial configuration files
task init

# Template out Kubernetes and Talos configs
task configure
```

### Cluster Operations
```bash
# Bootstrap Talos cluster
task bootstrap:talos

# Bootstrap applications into cluster
task bootstrap:apps

# Force Flux reconciliation
task reconcile

# Check cluster status
flux check
kubectl get pods --all-namespaces
cilium status
```

### Talos Management
```bash
# Generate Talos configuration
task talos:generate-config

# Apply config to specific node
task talos:apply-node IP=<node-ip>

# Upgrade Talos on a node
task talos:upgrade-node IP=<node-ip>

# Upgrade Kubernetes version
task talos:upgrade-k8s

# Reset cluster (destructive)
task talos:reset
```

## Architecture

### Directory Structure
- `kubernetes/apps/` - Application manifests organized by namespace
- `kubernetes/components/` - Common components and configurations
- `kubernetes/flux/` - Flux system configuration
- `talos/` - Talos Linux configuration files
- `bootstrap/` - Bootstrap scripts and initial configurations
- `.taskfiles/` - Task automation files

### GitOps Workflow
The cluster uses Flux v2 for GitOps with the following pattern:
1. **Kustomization manifests** (`ks.yaml`) define how Flux should apply resources
2. **HelmRelease manifests** manage Helm chart deployments
3. **Components** provide shared configurations across namespaces
4. **SOPS encryption** secures sensitive data (look for `.sops.yaml` files)

### Secret Management
- Secrets are encrypted with SOPS using age keys
- Age key located at `age.key` (do not commit this file)
- All `.sops.yaml` files contain encrypted secrets
- External Secrets Operator can manage secrets from external sources

### Networking
- **Cilium CNI** with Gateway API support
- **Cloudflare Tunnel** for external access
- **Internal gateway** for cluster-local services
- **External gateway** for public internet access

## Important Files

### Configuration Templates
- `cluster.sample.yaml` - Main cluster configuration template
- `nodes.sample.yaml` - Node-specific configuration template
- `talenv.yaml` - Talos and Kubernetes version definitions

### Bootstrap Files
- `bootstrap/helmfile.d/` - Contains CRDs and initial applications
- `scripts/bootstrap-apps.sh` - Application bootstrap automation

### Environment
- `.mise.toml` - Development tool versions and environment
- `Taskfile.yaml` - Main task automation definitions
- `.sops.yaml` - SOPS encryption configuration

## Development Workflow

1. **Configuration Changes**: Edit YAML manifests in `kubernetes/apps/`
2. **Template Updates**: Run `task configure` after modifying configuration templates
3. **Secret Management**: Use `sops` to edit encrypted files
4. **Testing**: Use `kubectl diff` or `flux diff ks <name>` before applying
5. **Deployment**: Changes are automatically deployed via Flux GitOps

## Troubleshooting

### Common Commands
```bash
# Check Flux status
flux get sources git -A
flux get ks -A
flux get hr -A

# Check application logs
kubectl -n <namespace> logs <pod-name> -f

# Describe resources for issues
kubectl -n <namespace> describe <resource> <name>

# Check namespace events
kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
```

### Secret Decryption
```bash
# View encrypted secret
sops -d path/to/secret.sops.yaml

# Edit encrypted secret
sops path/to/secret.sops.yaml
```

## Key Dependencies
- **Talos Linux** - Immutable Kubernetes OS
- **Flux v2** - GitOps continuous deployment
- **Cilium** - Container networking (CNI)
- **SOPS** - Secret encryption
- **Cloudflare** - DNS and tunnel services
- **External Secrets** - External secret management
- **cert-manager** - TLS certificate automation