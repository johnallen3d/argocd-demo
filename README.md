# Kubernetes Setup

## Build a Cluster with

- Ingress Nginx
- ArgoCD

### Multipass

For local development, we can use [Multipass](https://multipass.run/).

```bash
brew install multipass helm
```

#### Setup

##### Bootstrap VM

```bash
export OP_SERVICE_ACCOUNT_TOKE=...

multipass stop k3s \
  && multipass delete k3s \
  && multipass purge \
  && multipass launch --name k3s --cpus 6 --memory 8G --disk 60G --timeout 3000 \
  && multipass exec k3s -- bash -c 'curl -sfL https://get.k3s.io -o install.sh && sh install.sh' \
  && multipass exec k3s -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config \
  && sed -i '' "s/127\.0\.0\.1/$(multipass info k3s | grep IPv4: | awk '{print $2}')/g" ~/.kube/config \
  && k cluster-info \
  && ./bin/create-secret-onepassword \
  && kubectl create namespace argocd \
  && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  && sleep 2 \
  && kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s \
  && kubectl apply -f apps-local.yaml \
  && kubectl rollout restart deployment argocd-server --namespace argocd \
  && kubectl rollout status deployment/argocd-server -n argocd
```

##### Bootstrap k3s

Set the `kubectl` context to the cluster we are setting up.

```bash
kubectl config use-context default
# or
kubectl config use-context proxmox-01-control-01
```

```bash
./bin/create-secret-onepassword
```

### ArgoCD

#### Install

```bash
kubectl create namespace argocd \
  && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  && sleep 2 \
  && kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

#### Expose

```bash
# on local machine with k3s
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### CLI Login

```bash
# grab default password
set ARGOCD_PASSWORD $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
# export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD | pbcopy
# argocd repo add https://github.com/johnallen3d/argocd-demo --name argocd-demo
argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure \
  --plaintext
```

#### Web UI

```bash
open https://localhost:8080
```

#### App of Apps

```bash
kubectl apply -f apps-local.yaml \
  && kubectl rollout restart deployment argocd-server --namespace argocd \
  && kubectl rollout status deployment/argocd-server -n argocd
```

## Teardown

### Multipass

```bash
multipass stop k3s \
  && multipass delete k3s \
  && multipass purge
```

## Environments

| name         | locaction     | description                                      |
| ------------ | ------------- | ------------------------------------------------ |
| local        | local machine | a local testing cluster (eg. k3s)                |
| dev          | trashcan-01   | an instance of k3s running on the trashcan       |
| xcel-on-prem | trashcan-01   | Talos cluster running in Proxmox on the trashcan |
