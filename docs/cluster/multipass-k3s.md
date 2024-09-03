# k3s in a Multipass VM (Ubuntu)

## Multipass

For local development [Multipass](https://multipass.run/).

- lightweight vm management tool
- quick virtual environments creation
- ubuntu-based instances by default
- cross-platform compatibility (mac, windows, linux)

## k3s

- lightweight kubernetes distribution
- single binary under 100mb
- easy to install
- ideal for edge computing

## Bootstrap VM

```bash
set OP_SERVICE_ACCOUNT_TOKEN ...

multipass stop k3s \
  && multipass delete k3s \
  && multipass purge \
  && multipass launch --name k3s --cpus 6 --memory 8G --disk 60G --timeout 3000 \
  && multipass exec k3s -- bash -c 'curl -sfL https://get.k3s.io -o install.sh && sh install.sh' \
  && multipass exec k3s -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-local.yaml \
  && sed -i '' "s/127\.0\.0\.1/$(multipass info k3s | grep IPv4: | awk '{print $2}')/g" ~/.kube/k3s-local.yaml \
  && set -x KUBECONFIG "$HOME/.kube/k3s-local.yaml:$HOME/.kube/proxmox-01-cluster-01.yaml" \
  && kubectl config view --flatten > ~/.kube/config \
  && kubectl cluster-info \
  && kubectl config use-context default \
  && ./bin/create-secret-onepassword \
  && kubectl create namespace argocd \
  && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  && sleep 5 \
  && kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s \
  && kubectl apply -f apps/local.yaml \
  && sleep 5 \
  && kubectl rollout restart deployment argocd-server --namespace argocd \
  && kubectl rollout status deployment/argocd-server -n argocd \
  && set ARGOCD_PASSWORD $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \
  && echo $ARGOCD_PASSWORD | pbcopy
```

## Tear Down VM

```bash
multipass stop k3s \
  && multipass delete k3s \
  && multipass purge
```
