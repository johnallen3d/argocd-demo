# Talos on Proxmox VM's

## Tasks

### refresh-metadata

Inputs: VERSION
Environment: VERSION=v1.7.6
Environment: METADATA_FILE=talos-metadata.sh

```bash
config=$(
  cat <<-EOF
	customization:
	  systemExtensions:
	    officialExtensions:
	      - siderolabs/qemu-guest-agent
	      - siderolabs/iscsi-tools
	      - siderolabs/util-linux-tools
	EOF
)

sha=$(
  echo "$config" |
    curl --request POST \
      --data-binary @- \
      --silent \
      --show-error \
      --fail \
      https://factory.talos.dev/schematics |
    jq -r .id
)

iso_url="https://factory.talos.dev/image/$sha/$VERSION/metal-amd64.iso"
install_url="factory.talos.dev/installer/$sha:$VERSION"

cat << EOF > "$METADATA_FILE"
export TALOS_VERSION="$VERSION"
export TALOS_CONFIG_DIR="/root/.config/talos/"
export SHA="$sha"
export INSTALL_URL="$install_url"
export ISO_FILENAME=talos-$VERSION-metal-amd64.iso
export ISO_URL="$iso_url"
EOF
```

### get-ip

Inputs: VM_ID
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"

echo $(get_vm_ip "$VM_ID")
```

### download-iso

Inputs: DOWNLOAD_PATH
Environment: METADATA_FILE=talos-metadata.sh
Environment: DOWNLOAD_PATH=/var/lib/vz/template/iso

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/$METADATA_FILE"

wget "$ISO_URL" \
  --quiet \
  --output-document "$DOWNLOAD_PATH/$ISO_FILENAME"
```

### create-template

Inputs: VM_ID
Inputs: MEMORY
Inputs: CORES
Environment: MEMORY=8192
Environment: CORES=2
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/$METADATA_FILE"

qm create "$VM_ID" \
  --name talos-template \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --net0 virtio,bridge=vmbr0 \
  --cpu cputype=x86-64-v2-AES \
  --scsihw virtio-scsi-single

qm set "$VM_ID" --ide2 local:iso/"$ISO_FILENAME",media=cdrom
qm set "$VM_ID" --agent enabled=1
qm set "$VM_ID" --scsi0 local-lvm:100
qm template "$VM_ID"
```

### create-control-plane-node

Inputs: NAME
Inputs: PREFIX
Inputs: NODE_NUMBER
Inputs: TEMPLATE_ID
Inputs: IS_FIRST_NODE
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"
source "$current_dir/$METADATA_FILE"

VM_ID="${PREFIX}00${NODE_NUMBER}"
VM_NAME="${NAME}-control-0${NODE_NUMBER}"

qm clone "$TEMPLATE_ID" "$VM_ID" --name "$VM_NAME" --full
qm start "$VM_ID"
qm status "$VM_ID"

CONTROL_PLANE_IP="$(get_vm_ip "$VM_ID")"
echo "$CONTROL_PLANE_IP"

if [ "$IS_FIRST_NODE" = "y" ]; then
  talosctl gen config "${NAME}-cluster" "https://$CONTROL_PLANE_IP:6443" \
    --force \
    --output-dir "$TALOS_CONFIG_DIR/$NAME" \
    --install-image "$INSTALL_URL"
fi

talosctl apply-config \
  --insecure \
  --nodes "$CONTROL_PLANE_IP" \
  --file "$TALOS_CONFIG_DIR/$NAME/controlplane.yaml"
```

### create-worker-nodes

Inputs: NAME
Inputs: PREFIX
Inputs: NODE_NUMBER
Inputs: TEMPLATE_ID
Inputs: COUNT
Environment: COUNT=1
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"
source "$current_dir/$METADATA_FILE"

for NODE_NUMBER in $(seq "$NODE_NUMBER" $((NODE_NUMBER + COUNT - 1))); do
  VM_ID="${PREFIX}0${NODE_NUMBER}"
  VM_NAME="${NAME}-worker-${NODE_NUMBER}"

  qm clone "$TEMPLATE_ID" "$VM_ID" --name "$VM_NAME" --full
  qm start "$VM_ID"
  qm status "$VM_ID"

  WORKER_IP=$(get_vm_ip "$VM_ID")
  echo "$WORKER_IP"

  talosctl apply-config \
    --insecure \
    --nodes "$WORKER_IP" \
    --file "$TALOS_CONFIG_DIR/$NAME/worker.yaml"
done
```

### switch-cluster

Inputs: NAME
Inputs: CONTROL_PLANE_VM_ID
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"
source "$current_dir/$METADATA_FILE"

CONTROL_PLANE_IP=$(get_vm_ip "$CONTROL_PLANE_VM_ID")

export TALOSCONFIG="$TALOS_CONFIG_DIR/$NAME/talosconfig"
talosctl config endpoint "$CONTROL_PLANE_IP"
talosctl config node "$CONTROL_PLANE_IP"

echo "
source ./util.sh
export NAME=$NAME
export TALOSCONFIG=\"\$TALOS_CONFIG_DIR/\$NAME/talosconfig\"
"
```

### bootstrap-cluster

Inputs: NAME
Inputs: CONTROL_PLANE_VM_ID
Inputs: EXTERNAL_DOMAIN
Environment: METADATA_FILE=talos-metadata.sh
Requires: switch-cluster

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"

CONTROL_PLANE_IP=$(get_vm_ip "$CONTROL_PLANE_VM_ID")

talosctl bootstrap

# allow certs to be generated for external url
talosctl patch mc \
  --nodes "$CONTROL_PLANE_IP" \
  --patch "[{\"op\": \"add\", \"path\": \"/cluster/apiServer/certSANs/-\", \"value\": \"k8s.$EXTERNAL_DOMAIN\" }]"

export KUBECONFIG="/root/.kube/${NAME}.yaml"
talosctl kubeconfig --force $KUBECONFIG
```

### install-metrics-server

Once the cluster is available.

Inputs: NAME

```bash
export KUBECONFIG="/root/.kube/${NAME}.yaml"

# install metrics server : https://www.talos.dev/v1.7/kubernetes-guides/configuration/deploy-metrics-server/#install-after-bootstrap
kubectl apply -f https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### remove-node-from-cluster

Inputs: NAME
Inputs: VM_ID
Inputs: NODE_NAME
Environment: METADATA_FILE=talos-metadata.sh

```bash
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "$current_dir/util.sh"
source "$current_dir/$METADATA_FILE"

NODE_IP=$(get_vm_ip "$VM_ID")

export TALOSCONFIG="$TALOS_CONFIG_DIR/$NAME/talosconfig"
talosctl -n $NODE_IP reset

export KUBECONFIG="/root/.kube/${NAME}.yaml"
kubectl delete node $NODE_NAME
```

### destroy-node

Inputs: VM_ID

```bash
qm stop $VM_ID
qm destroy $VM_ID
```

### copy-kubeconfig-to-local

Inputs: NAME
Inputs: EXTERNAL_DOMAIN

```bash
scp root@proxmox-01:/root/.kube/${NAME}.yaml ~/.kube/${NAME}.yaml

sed -i '' '/certificate-authority-data:/a\
    proxy-url: socks5://127.0.0.1:1234\
' ~/.kube/${NAME}.yaml

sed -i '' \
  "s|server: https://[^:]*:6443|server: https://k8s.${EXTERNAL_DOMAIN}|" \
  ~/.kube/${NAME}.yaml

echo "Ensure that the ip address in the tunnel configuration for 'k8s.$EXTERNAL_DOMAIN' matches the current '\$CONTROL_PLANE_IP'."
echo ""
echo "https://one.dash.cloudflare.com/c60a9b2426e2d250307a67e4937bb55c/networks/tunnels/cfd_tunnel/471afade-c949-4b76-8dc9-ff8359d67caa/edit?tab=publicHostname"
```

### merge-kubeconfig-files

```bash
export KUBECONFIG=$(find ~/.kube -maxdepth 1 -name '*.yaml' -not -name 'config' | tr '\n' ':' | sed 's/:$//')
echo $KUBECONFIG

kubectl config view --flatten > ~/.kube/config
```
