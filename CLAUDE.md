# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

GitOps-managed single-cluster home-ops setup. Talos Linux runs Kubernetes; Flux v2 reconciles manifests from this Git repo; SOPS (age) encrypts secrets; Cloudflare Tunnel + external-dns expose chosen services. The repo was generated from `carathorys/cluster-template` (a `makejinja` template), so the working tree contains only rendered output — `cluster.sample.yaml` / `nodes.sample.yaml` referenced by README live in the upstream template, not here.

Tools are pinned in `.mise.toml` — run `mise trust && mise install` before any task.

## Common Commands

All workflows are driven through `task` (Taskfile.yaml + `.taskfiles/`). `task` with no args lists everything.

```bash
# Bootstrap (one-time)
task bootstrap:talos          # genconfig → apply --insecure → bootstrap → fetch kubeconfig
task bootstrap:apps           # runs scripts/bootstrap-apps.sh (helmfile sync of CRDs + flux)

# Day-2 cluster ops
task reconcile                                  # flux reconcile ks flux-system --with-source
task talos:apply-node IP=<node-ip>              # MODE defaults to "auto"
task talos:upgrade-node IP=<node-ip>            # image+version pulled from talconfig.yaml/talenv.yaml
task talos:upgrade-k8s                          # version pulled from talenv.yaml
task talos:reset                                # destructive; prompts before wiping
```

`task encrypt-secrets` / `decrypt-secrets` are marked `internal: true` — invoke via the dependent tasks rather than directly. They walk `bootstrap/`, `kubernetes/`, `talos/` for `*.sops.*` and toggle encryption based on `sops filestatus`.

Required env (set automatically by `mise` and Taskfile):
- `KUBECONFIG=./kubeconfig`
- `SOPS_AGE_KEY_FILE=./age.key`
- `TALOSCONFIG=./talos/clusterconfig/talosconfig`

## Flux Layering — Read This Before Editing Manifests

The cluster has exactly **one** Flux entrypoint Kustomization (`flux-system`, bootstrapped by `task bootstrap:apps`). It points at `kubernetes/flux/cluster/ks.yaml`, which declares two Kustomizations:

1. `cluster-meta` → `./kubernetes/flux/meta` — Helm/OCI repos, the SOPS-encrypted `cluster-secrets` Secret, and other shared deps. Must reconcile first (`wait: true`).
2. `cluster-apps` → `./kubernetes/apps` — `dependsOn: cluster-meta`. Recursively kustomizes everything under `kubernetes/apps/<namespace>/`. A patch is applied here that injects `decryption.provider: sops` and `postBuild.substituteFrom: cluster-secrets` into **every** child Kustomization, so individual app `ks.yaml` files don't need to repeat that.

### Per-app convention

Each app under `kubernetes/apps/<namespace>/<app>/` follows:

```
<app>/
  ks.yaml           # Flux Kustomization: name=<app>, path=./kubernetes/apps/<ns>/<app>/app, targetNamespace=<ns>
  app/
    kustomization.yaml   # kustomize.config.k8s.io — lists helmrelease.yaml, secret.sops.yaml, etc.
    helmrelease.yaml
    secret.sops.yaml     # SOPS-encrypted; decrypted at reconcile time
    ...
```

`ks.yaml` may set `dependsOn` to gate ordering across apps in the same namespace (e.g. an app waiting on its database). Variables substituted from `cluster-secrets` are referenced as `${VAR}` inside any manifest under `app/`.

`kubernetes/components/common/` provides reusable kustomize components (`repos/`, `sops/cluster-secrets.sops.yaml`) — referenced via `components:` in `kustomization.yaml` rather than copy-paste.

### App namespaces present

`auth`, `cert-manager`, `dbms`, `default`, `flux-system`, `games`, `home-assistant`, `immich`, `jobs`, `kube-system`, `media`, `network`, `observability`, `secrets`, `system`. Each has its own `kustomization.yaml` enumerating apps.

## Talos Configuration

Source of truth is `talos/talconfig.yaml` (consumed by `talhelper`). Versions live in `talos/talenv.yaml` (Renovate-managed via `# renovate: datasource=docker depName=...` comments). `talos/clusterconfig/` is generated output — regenerate with `task talos:generate-config`, never hand-edit. `talsecret.sops.yaml` is created on first bootstrap and committed encrypted.

`talos/patches/` holds machine-config patches included from `talconfig.yaml`.

## Secret Management

- Age key: `./age.key` (gitignored). `.sops.yaml` configures recipients and the `path_regex` rules.
- Convention: filename suffix `.sops.yaml` / `.sops.json` etc. — encryption status is detected via `sops filestatus`, not by suffix alone.
- `cluster-secrets` (in `kubernetes/components/common/sops/`) is the global substitution Secret — add a key here to make it available as `${KEY}` to any app.
- External Secrets Operator is deployed under the `secrets` namespace for syncing from external stores; use it instead of inlining a `secret.sops.yaml` when a store is appropriate.

## Renovate

`.renovaterc.json5` runs on weekends, manages Flux/Helmfile/Kustomize/Kubernetes/Docker deps, and ignores `**/*.sops.*`. Linuxserver images use a custom regex versioning scheme. When adding a new image, add a `# renovate:` comment if it isn't auto-detected.

## Quick Sanity Checks

```bash
flux get ks -A                 # any NotReady? check the failing Kustomization first
flux get hr -A
flux diff ks <name> --path ./kubernetes/apps/<ns>/<app>     # preview before push
kubectl -n <ns> get events --sort-by='.metadata.creationTimestamp'
sops -d path/to/secret.sops.yaml          # view; use `sops path/to/secret.sops.yaml` to edit
```
