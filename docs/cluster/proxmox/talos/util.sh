#! /usr/bin/env bash

cluster_name() {
  template_id="${1}"
  name=$(qm config "${template_id}" | grep name | awk '{print $2}')
  echo "$name"
}

get_vm_ip() {
  local vm_id=$1
  local max_attempts=30
  local sleep_interval=5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    local ip
    ip=$(
      qm guest cmd "$vm_id" network-get-interfaces |
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

    if [ -n "$ip" ]; then
      echo "$ip"
      return 0
    fi

    echo "Attempt $attempt: No IP found. Retrying in $sleep_interval seconds..." >&2
    sleep $sleep_interval
    ((attempt++))
  done

  echo "Failed to get IP after $max_attempts attempts" >&2
  return 1
}
