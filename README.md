# Kubernetes Setup

## Build a Cluster with

- Ingress Nginx
- ArgoCD

### Multipass

For local development, we can use [Multipass](https://multipass.run/).

```bash
brew install multipass
```

#### Setup

##### Bootstrap VM

```bash
multipass launch --name k3s --memory 4G --disk 40G --timeout 3000 \
  && multipass exec k3s -- bash -c 'curl -sfL https://get.k3s.io -o install.sh && sh install.sh' \
  && multipass exec k3s -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config \
  && sed -i '' "s/127\.0\.0\.1/$(multipass info k3s | grep IPv4: | awk '{print $2}')/g" ~/.kube/config \
  && k cluster-info
```

##### Bootstrap k3s

```bash
# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
# kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/controller.yaml
./bin/generate-tailscale-secret
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

TODO: play with this when we have a working cluster

```bash
kubectl apply -f argocd-ingress.yaml
# grab ip of k8s host, eg. multipass
multipass info | grep IPv4: | awk '{print $2}' | pbcopy
sudo vi /etc/hosts
192... argocd.localhost
```

#### CLI Login

```bash
# grab default password
set ARGOCD_PASSWORD $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD | pbcopy
# login with username admin when prompted
argocd repo add https://github.com/johnallen3d/argocd-demo --name argocd-demo
argocd login localhost:8080 \
  --username admin \
  --password "${ARGOCD_PASSWORD}" \
  --insecure
```

#### Web UI

```bash
open http://localhost:8080
```

## Teardown

### Multipass

```bash
multipass stop k3s \
  && multipass delete k3s \
  && multipass purge
```
