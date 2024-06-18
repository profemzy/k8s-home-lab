#!/bin/bash
# Script to install and configure containerd and runc for container runtime support

# --- Install JQ (JSON Processor) ---
sudo apt install -y jq  # Install jq for working with JSON data

# --- Containerd Prerequisites ---
# Load kernel modules needed for container networking and storage
cat <<- EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Immediately load the required kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters for IP forwarding and bridge networking
cat <<- EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1   # Enable iptables for bridges
net.ipv4.ip_forward               = 1   # Enable IP forwarding
net.bridge.bridge-nf-call-ip6tables = 1   # Enable ip6tables for bridges
EOF

# Apply sysctl parameters without rebooting
sudo sysctl --system

# --- Containerd Installation ---
# Get the latest Containerd version from GitHub releases
CONTAINERD_VERSION=$(curl -s https://api.github.com/repos/containerd/containerd/releases/latest | jq -r '.tag_name')
CONTAINERD_VERSION=${CONTAINERD_VERSION#v}  # Remove 'v' prefix from version

# Download the Containerd tarball
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Extract the tarball to the /usr/local directory
sudo tar xvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C /usr/local

# --- Containerd Configuration ---
# Create the configuration directory
sudo mkdir -p /etc/containerd

# Create the config.toml file with basic configuration
cat <<- TOML | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = true # Enable discarding unpacked image layers
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2" 
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true  # Use Systemd cgroups
TOML

# --- Runc Installation ---
# Get the latest Runc version
RUNC_VERSION=$(curl -s https://api.github.com/repos/opencontainers/runc/releases/latest | jq -r '.tag_name')

# Download the Runc binary
wget https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/runc.amd64

# Install the Runc binary with correct permissions
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

# --- Containerd Service Setup ---
# Download the containerd service file
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# Move the service file to the systemd directory
sudo mv containerd.service /usr/lib/systemd/system/

# Reload systemd and enable/start the containerd service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
