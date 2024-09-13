# Manage K8s Apps

## Tasks

### install-argocd

```bash
kubectl create namespace argocd
kubectl apply \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### port-forward-argocd

```bash
kubectl port-forward svc/argocd-server \
  --namespace argocd 8080:443
```

### extract-password-argocd

```bash
pass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $pass | pbcopy
```

### launch-web-argocd

```bash
open https://localhost:8080
```

### install-app-of-apps

Inputs: ENVIRONMENT
Inputs: SECRET_STORE

```bash
# environments=($(ls ../../apps/*.yaml 2>/dev/null | xargs -n1 basename | cut -d'-' -f1 | sort -u))
# secret_stores=($(ls ../../apps/*.yaml 2>/dev/null | xargs -n1 basename | rev | cut -d'-' -f1 | rev | cut -d'.' -f1 | sort -u))

# echo $environments

# contains() {
#   local e match="$1"
#   shift
#   for e; do [[ "$e" == "$match" ]] && return 0; done
#   return 1
# }

# TODO
# if ! contains "$ENVIRONMENT" "${environments[@]}"; then
#   echo ""
#   echo "Error: Invalid environment '$ENVIRONMENT'" >&2
#   echo "Valid environments are: ${environments[*]}" >&2
#   exit 1
# fi

# if ! contains "$SECRET_STORE" "${secret_stores[@]}"; then
#   echo ""
#   echo "Error: Invalid secret store '$SECRET_STORE'" >&2
#   echo "Valid secret stores are: ${secret_stores[*]}" >&2
#   exit 1
# fi

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
kubectl apply -f ../../apps/${ENVIRONMENT}-${SECRET_STORE}.yaml
sleep 5
kubectl rollout restart deployment argocd-server --namespace argocd
kubectl rollout status deployment/argocd-server -n argocd
```
