# Tart helpers for the clean-VM runs (test/vm.sh). ADR 0005.

# Vanilla Sequoia from Cirrus Labs, pinned by digest. User admin, password admin.
VM_IMAGE=ghcr.io/cirruslabs/macos-sequoia-vanilla@sha256:57a83b1b52f928f5b11b0963927178fd6c4cac52c315279f227c27cc5ab81587
VM_USER="admin"
VM_PASSWORD="admin"
# SSH key for the test VMs, kept outside the repo and reused across runs.
VM_KEY=$HOME/.cache/vizion-2-test/id_ed25519
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)

# vm_ssh <ip> <command…>: runs a command in the VM with the test key, no terminal.
vm_ssh() {
  local ip=$1
  shift
  ssh -i "$VM_KEY" "${SSH_OPTS[@]}" -o BatchMode=yes "$VM_USER@$ip" "$@"
}

# vm_boot <name> <log> [--window]: clones the image and starts the VM, headless unless --window
# (the guided steps need its screen); prints its IP once SSH answers.
vm_boot() {
  local name=$1 log=$2 ip graphics=--no-graphics
  [ "${3:-}" = --window ] && graphics=
  tart list --quiet | grep -qxF "$VM_IMAGE" || tart pull "$VM_IMAGE" >> "$log" 2>&1 || return 1
  tart clone "$VM_IMAGE" "$name" >> "$log" 2>&1 || return 1
  tart run $graphics "$name" >> "$log" 2>&1 &
  ip=$(tart ip "$name" --wait 300) || return 1
  for _ in $(seq 60); do nc -z "$ip" 22 2>/dev/null && break; sleep 2; done
  echo "$ip"
}

# vm_authorize <ip>: installs the test key (password login once; generates the key on first use).
vm_authorize() {
  local ip=$1
  mkdir -p "$(dirname "$VM_KEY")"
  [ -f "$VM_KEY" ] || ssh-keygen -q -t ed25519 -N "" -C vizion-2-test -f "$VM_KEY" || return 1
  "$REPO/test/lib/ssh-password.exp" "$VM_USER@$ip" "$VM_PASSWORD" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$(cat "$VM_KEY.pub")' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" &&
    vm_ssh "$ip" true
}

# vm_make_clean <ip>: makes the image look like a new Mac: no Command Line Tools (so no git), and
# sudo asks for the password.
vm_make_clean() {
  vm_ssh "$1" 'sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --reset &&
    sudo rm -f /etc/sudoers.d/admin-nopasswd && ! sudo -n true 2>/dev/null && ! xcode-select -p >/dev/null 2>&1'
}

# vm_delete <name>
vm_delete() {
  tart stop "$1" > /dev/null 2>&1
  tart delete "$1" > /dev/null 2>&1
}
