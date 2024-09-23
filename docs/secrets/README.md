# Secrets

## Managed Secrets

| name                        | namespace                    | description                                                                   |
| --------------------------- | ---------------------------- | ----------------------------------------------------------------------------- |
| `op-credentials`            | `1password`                  | `1password-credentials.json` access to 1Password from Connect server          |
| `onepassword-token`         | `1password`                  | access 1Password Connect server                                               |
| `superset-secret-key`       | `superset`                   | a session cookie signing key for superset                                     |
| `minio-configuration--xcel` | `minio-tenant-0`             | console login and minio storage configuration including root user credentials |
| `cloudflare--3d`            | `cloudflare-operator-system` | access token for Cloudflare Zero Trust tunnels                                |

## Current State

- secrets are stored in a 1Password vault in my account named `k8s`
- there is a 1Password connect server defined named `argocd-dev`
- this connect server provides:
  - `1password-credentials.json` - used to authenticate from the connect server to 1Password
  - access token - used for clients to authenticate to the connect server
- the connect server is deployed via the `1password/connect` helm chart

## Future State

- secrets generated by [External Secrets Operator](https://external-secrets.io/latest/)
- secrets retrieved from external provider depending on environment(?):
  - `local` - 1Password
  - `xcel-on-prem` - AWS Secrets Manager

## Migration

```text
cloudflare--3d            -> K8S/Local/Cloudflare.CLOUDFLARE_TUNNEL_CREDENTIAL_SECRET_LOCAL
minio-configuration--xcel -> K8S/Local/MinIO.config.env
minio-configuration--xcel -> K8S/Local/MinIO.CONSOLE_ACCESS_KEY
minio-configuration--xcel -> K8S/Local/MinIO.CONSOLE_SECRET_KEY
superset-secret-key       -> K8S/Local/Superset.credential

cloudflare--3d            -> K8S/OnPrem/Cloudflare.CLOUDFLARE_TUNNEL_CREDENTIAL_SECRET_XCEL_ON_PREM
minio-configuration--xcel -> K8S/OnPrem/MinIO.config.env
minio-configuration--xcel -> K8S/OnPrem/MinIO.CONSOLE_ACCESS_KEY
minio-configuration--xcel -> K8S/OnPrem/MinIO.CONSOLE_SECRET_KEY
superset-secret-key       -> K8S/OnPrem/Superset.credential
```

## Tasks

### create-secret-1password

Inputs: OP_SERVICE_ACCOUNT_TOKEN

```bash
secret_prefix=ref+op://k8s
namespace="1password"

credentials=$(vals get "$secret_prefix/1password-connect--credentials-file--argocd-dev/contents")
token=$(vals get "$secret_prefix/1password-connect--access-token--argocd-dev/credential")

# kubectl create namespace $namespace

kubectl create secret generic op-credentials \
  --namespace $namespace \
  --from-literal=1password-credentials.json="$credentials"

kubectl create secret generic onepassword-token \
  --namespace $namespace \
  --from-literal=token="$token"
```

### update-secret-1password-token

Inputs: OP_SERVICE_ACCOUNT_TOKEN

```bash
secret_prefix=ref+op://k8s
namespace="1password"
token=$(vals get "$secret_prefix/1password-connect--access-token--argocd-dev/credential")
encoded_token=$(echo -n "$token" | base64 | tr -d '\n')

kubectl patch secret onepassword-token \
  --namespace $namespace \
  --type 'json' \
  --patch "[{\"op\": \"replace\", \"path\": \"/data/token\", \"value\":\"${encoded_token}\"}]"
```

### create-secret-aws

Environment: AWS_ACCESS_KEY_ID
Environment: AWS_SECRET_ACCESS_KEY
Environment: AWS_SESSION_TOKEN

```bash
#! /usr/bin/env bash

secret_prefix=ref+awssecrets://K8S
namespace="external-secrets"

secret=$(vals get "$secret_prefix/OnPrem/ReadSecrets")

aws_access_key_id=$(echo $secret | jq -r '.aws_access_key_id')
aws_secret_access_key=$(echo $secret | jq -r '.aws_secret_access_key')
creds=$(echo $secret | jq -r '.creds')

kubectl create namespace $namespace

kubectl create secret generic aws-credential \
  --namespace $namespace \
  --from-literal=aws_access_key_id="$aws_access_key_id" \
  --from-literal=aws_secret_access_key="$aws_secret_access_key" \
  --from-literal=creds="$creds"
```