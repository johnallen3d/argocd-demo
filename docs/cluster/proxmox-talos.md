# Talos Linux on Proxmox

## Proxmox

• open-source virtualization management platform
• combines kvm and lxc technologies
• web-based interface for administration
• supports clustering and live migration

## Talos Linux

- minimal linux-based operating system
- designed for kubernetes clusters
- immutable and secure by default
- api-driven configuration and management

## Bootstrap

### Image Factory

Generate an ISO image for Talos Linux:

- https://factory.talos.dev/
- Bare-metal Machine
- Latest version
- `amd64` (typically)
- System Extensions : https://longhorn.io/docs/1.7.0/advanced-resources/os-distro-specific/talos-linux-support/#system-extensions
  - `qemu-guest-agent`
  - `iscsi-tools`
  - `util-linux-tools`
- Customizations (leave default)
- Capture two URLs:
  - ISO Download : eg. https://factory.talos.dev/image/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b/v1.7.6/metal-amd64.iso
  - Initial Install : eg. factory.talos.dev/installer/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b:v1.7.6

### ISO

Download the ISO image into the default path on Proxmox machine:

```bash
ssh root@prooxmox-01.taila14c2.ts.net

TALOS_VERSION=v1.7.6
SHA=88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b
ISO_URL="https://factory.talos.dev/image/$SHA/$TALOS_VERSION/metal-amd64.iso"
ISO_FILENAME="talos-$TALOS_VERSION-metal-amd64.iso"
wget -O /var/lib/vz/template/iso/$ISO_FILENAME $ISO_URL
```

### Template

```bash
ssh root@prooxmox-01.taila14c2.ts.net

ISO_FILENAME=talos-v1.7.6-metal-amd64.iso
VM_ID=1000
qm create $VM_ID              \
  --name talos-template       \
  --memory 8192               \
  --cores 2                   \
  --net0 virtio,bridge=vmbr0  \
  --cpu cputype=x86-64-v2-AES \
  --scsihw virtio-scsi-single

qm set $VM_ID --ide2 local:iso/talos-v1.7.6-metal-amd64.iso,media=cdrom
qm set $VM_ID --agent enabled=1
qm set $VM_ID --scsi0 local-lvm:100
qm template $VM_ID
```

### Utility

```bash
get_vm_ip() {
    local VM_ID=$1
    local MAX_ATTEMPTS=30
    local SLEEP_INTERVAL=5
    local attempt=1

    while [ $attempt -le $MAX_ATTEMPTS ]; do
        local IP=$(qm guest cmd $VM_ID network-get-interfaces |
            jq -r '
                .[]
                | select(.name != "lo" and ."ip-addresses")
                | ."ip-addresses"[]
                | select(
                    ."ip-address-type" == "ipv4" and
                    ."ip-address" != "127.0.0.1"
                )
                | ."ip-address"
            ' |
            head -n1
        )

        if [ -n "$IP" ]; then
            echo "$IP"
            return 0
        fi

        echo "Attempt $attempt: No IP found. Retrying in $SLEEP_INTERVAL seconds..." >&2
        sleep $SLEEP_INTERVAL
        ((attempt++))
    done

    echo "Failed to get IP after $MAX_ATTEMPTS attempts" >&2
    return 1
}
```

### Create Control Plane Node

```bash
ssh root@prooxmox-01.taila14c2.ts.net

VM_ID=1001
TEMPLATE_ID=1000
VM_NAME=talos-control-01
TALOS_CONFIG_DIR="/root/.config/talos/"

TALOS_VERSION=v1.7.6
SHA=88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b
INSTALL_URL="factory.talos.dev/installer/$SHA:$TALOS_VERSION"

qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME --full
qm start $VM_ID
qm status $VM_ID
CONTROL_PLANE_IP=$(get_vm_ip $VM_ID)
echo $CONTROL_PLANE_IP

talosctl gen config talos-proxmox-cluster https://$CONTROL_PLANE_IP:6443 \
  --force \
  --output-dir $TALOS_CONFIG_DIR \
  --install-image $INSTALL_URL

talosctl apply-config \
  --insecure \
  --nodes $CONTROL_PLANE_IP \
  --file $TALOS_CONFIG_DIR/controlplane.yaml
```

### Create Worker Node

```bash
ssh root@prooxmox-01.taila14c2.ts.net

TALOS_CONFIG_DIR="/root/.config/talos/"
TEMPLATE_ID=1000

for NODE_NUMBER in 1 2 3; do
  VM_ID=101$NODE_NUMBER
  VM_NAME=talos-worker-0$NODE_NUMBER

  qm clone $TEMPLATE_ID $VM_ID --name $VM_NAME --full
  qm start $VM_ID
  qm status $VM_ID

  WORKER_IP=$(get_vm_ip $VM_ID)
  echo $WORKER_IP

  talosctl apply-config \
    --insecure \
    --nodes $WORKER_IP \
    --file "$TALOS_CONFIG_DIR/worker.yaml"
done
```

### Using the Cluster

```bash
TALOS_CONFIG_DIR="/root/.config/talos/"
export TALOSCONFIG="$TALOS_CONFIG_DIR/talosconfig"
VM_ID=1001

CONTROL_PLANE_IP=$(get_vm_ip $VM_ID)

talosctl config endpoint $CONTROL_PLANE_IP
talosctl config node $CONTROL_PLANE_IP

talosctl bootstrap
```

### Kubeconfig

Add Cloudflare Tunnel proxy URL to the `certSANs` list. This will generate valid certs for this url in `kubeconfig`.

```bash
talosctl patch mc \
  --nodes $CONTROL_PLANE_IP \
  --patch '[{"op": "add", "path": "/cluster/apiServer/certSANs/-", "value": "proxmox-01-control-01.threedogconsulting.com" }]'
```

Generate a new `kubeconfig` file.

```bash
talosctl kubeconfig --force /root/.kube/proxmox-01-cluster-01.yaml
```

Copy `kubeconfig` file to local machine.

```bash
scp root@proxmox-01.taila14c2.ts.net:/root/.kube/proxmox-01-cluster-01.yaml ~/.kube/proxmox-01-cluster-01.yaml
```

Include proxy information in `kubeconfig`.

```yaml
# under clusters.cluster[0]
proxy-url: socks5://127.0.0.1:1234
server: https://proxmox-01-control-01.threedogconsulting.com
```

Ensure that the ip address in the [tunnel configuration for `proxmox-01-control-01.threedogconsulting.com`](https://one.dash.cloudflare.com/c60a9b2426e2d250307a67e4937bb55c/networks/tunnels/471afade-c949-4b76-8dc9-ff8359d67caa/public-hostname/proxmox-01-control-01.threedogconsulting.com/1) matches the current `$CONTROL_PLANE_IP`.

Start up a [proxy locally](https://developers.cloudflare.com/cloudflare-one/tutorials/kubectl/#connect-from-a-client-machine) in a separate terminal.

```bash
cloudflared access tcp \
  --hostname proxmox-01-control-01.threedogconsulting.com \
  --url 127.0.0.1:1234
```

Test cluster connection

```bash
k --kubeconfig ~/.kube/proxmox-01-cluster-01.yaml get nodes
```

Merge new config with local config.

```fish
set -x KUBECONFIG "$HOME/.kube/k3s-local.yaml:$HOME/.kube/proxmox-01-cluster-01.yaml"
kubectl config view --flatten > ~/.kube/config
```

### Tear Down VMs

```bash
for VM_ID in 1001 1011 1012 1013; do
  VM_ID=$VM_ID qm stop $VM_ID && qm destroy $VM_ID
done
```
