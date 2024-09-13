# K3s on Multipass VM

## Tasks

### create-vm

```bash
multipass launch --name k3s --cpus 6 --memory 8G --disk 60G --timeout 3000
multipass exec k3s -- bash -c 'curl -sfL https://get.k3s.io -o install.sh && sh install.sh'
multipass exec k3s -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-local.yaml
sed -i '' "s/127\.0\.0\.1/$(multipass info k3s | grep IPv4: | awk '{print $2}')/g" ~/.kube/k3s-local.yaml
export KUBECONFIG=$(find ~/.kube -maxdepth 1 -name '*.yaml' -not -name 'config' | tr '\n' ':' | sed 's/:$//')
kubectl config view --flatten > ~/.kube/config
```

### destroy-vm

```bash
multipass stop k3s
multipass delete k3s
multipass purge
```
