#!/bin/bash
# Script to install Kubeadm, Kubelet, and Kubectl for Kubernetes cluster setup

# --- Configure Kernel Modules ---
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
  br_netfilter # Load the module needed for bridge networking
EOF
# Load the module immediately
sudo modprobe br_netfilter

# --- Install Required Packages ---
sudo apt-get update &&  sudo apt-get install -y apt-transport-https ca-certificates curl gpg

sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# --- Add Kubernetes Repository and Key ---
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sleep 2  # Wait for the repository to be updated

# --- Install Kubernetes Components ---
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
# Pin the versions to prevent automatic updates
sudo apt-mark hold kubelet kubeadm kubectl

# --- Disable Swap (Important for Kubernetes) ---
sudo swapoff -a
sudo sed -i 's/\/swap/#\/swap/' /etc/fstab  # Comment out swap in fstab

# --- Set up Iptables Bridging ---
sudo cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system  # Apply sysctl changes


# Configure Containerd as the container runtime
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock

# --- Post-Installation Instructions ---
echo "
After initializing the control plane node with 'kubeadm init', you'll get a 'kubeadm join' command.

1. **Control Plane:**  On the control plane node, install a CNI plugin like Calico:
   'kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml'

2. **Worker Nodes:** On each worker node, run the 'kubeadm join' command you received to add them to the cluster.
"
