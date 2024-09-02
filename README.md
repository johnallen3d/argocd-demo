# Kubernetes Setup

## Build a Cluster with

- [multipass + k3s](./docs/cluster/multipass-k3s.md) or [talos + proxmox](./docs/cluster/proxmox-talos.md)
- [argocd](https://argo-cd.readthedocs.io/en/stable/) gitops continuous delivery for k8s
- [onepassword-operator](https://developer.1password.com/docs/k8s/k8s-operator/) via their helm chart for managing secrets
- [superset](https://superset.apache.org/) via their helm chart for building dashboards etc.
- [minio-operator](https://min.io/docs/minio/kubernetes/upstream/operations/installation.html) via their helm chart for providing object storage
- [eck-operator](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-overview.html) via there helm chart for standing up elasticsearch
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack/) via their helm chart for monitoring
- [longhorn](https://longhorn.io/) providing storage for the cluster
- [cloudflare zero trust tunnels](https://www.cloudflare.com/products/tunnel/) exposing services externally (in lieu of ingress etc)

### Bootstrap Cluster

Set the `kubectl` context to the cluster we are setting up.

```bash
set context_name default
# or
set context_name admin@talos-proxmox-cluster
kubectl config use-context $context_name
```

```bash
./bin/create-secret-onepassword
```

### ArgoCD

#### Install

```bash
kubectl create namespace argocd \
  && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  && sleep 5 \
  && kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

#### App of Apps

```bash
set env xcel-on-prem
kubectl apply -f apps-$env.yaml \
  && kubectl rollout restart deployment argocd-server --namespace argocd \
  && kubectl rollout status deployment/argocd-server --namespace argocd
```

#### Default ArgoCD Password

```bash
set ARGOCD_PASSWORD $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD | pbcopy
```

## Environments

| name         | locaction     | cluster type | host      | description                                      |
| ------------ | ------------- | ------------ | --------- | ------------------------------------------------ |
| local        | local machine | k3s          | multipass | a local testing cluster (eg. k3s)                |
| dev          | trashcan-01   | k3s          | direct    | an instance of k3s running on the trashcan       |
| xcel-on-prem | trashcan-01   | talos        | proxmox   | Talos cluster running in Proxmox on the trashcan |
