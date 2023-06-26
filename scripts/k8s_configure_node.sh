#!/usr/bin/env bash

# Made by: Arseni Skobelev (gh: https://github.com/ArseniSkobelev)

# This script allows for simple preparation of a single (on-prem) K8s node.
# It installs all of the required packages and adds all of the settings needed for
# (relatively) simple on-prem K8s deployment.

# Exit script on error
set -e

define_colors() {
# Define text-log colors
ERROR='\033[0;31m'
INFO='\033[0;33m'
SUCCESS='\033[0;32m'
NC='\033[0m'
}

kernel_settings() {
# --------------------------------------------
# |    Add kernel settings and set params    |
# --------------------------------------------
echo $INFO"[Step 2/5 | Kernel] Adding kernel settings"$NC

sudo tee /etc/modules-load.d/containerd.conf >> /dev/null <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay >> /dev/null && sudo modprobe br_netfilter >> /dev/null

sudo tee /etc/sysctl.d/kubernetes.conf >> /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --quiet --system --ignore 2>/dev/null

echo $SUCCESS"[Step 2/5 | Kernel] Kernel settings added successfully!"$NC
}

install_containerd() {
# ----------------------------
# |    Install Containerd    |
# ----------------------------
echo $INFO"[Step 3/5 | Container runtime] Installing Containerd.."

sudo apt-get update >> /dev/null
sudo apt-get install -y ca-certificates curl gnupg software-properties-common >> /dev/null

sudo install -m 0755 -d /etc/apt/keyrings >> /dev/null
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.gpg >> /dev/null

echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian  "$(. /etc/os-release >> /dev/null
echo "$VERSION_CODENAME")" stable" |  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update >> /dev/null
sudo apt-get install -y containerd.io >> /dev/null

containerd config default | sudo tee /etc/containerd/config.toml > /dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml >> /dev/null
sudo systemctl restart containerd >> /dev/null
sudo systemctl enable containerd >> /dev/null

echo $SUCCESS"[Step 3/5 | Container runtime] Containerd installed successfully!"$NC
}

install_k8s() {
# ---------------------------
# |    Install K8s tools    |
# ---------------------------
echo $INFO"[Step 4/5 | Kubernetes] Installing K8s tooling"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --batch --yes --dearmour -o /etc/apt/trusted.gpg.d/kubernetes-xenial.gpg >> /dev/null
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" --yes >> /dev/null

sudo apt-get update >> /dev/null
sudo apt-get install -y kubelet kubeadm kubectl >> /dev/null
sudo apt-mark hold kubelet kubeadm kubectl >> /dev/null

echo $SUCCESS"[Step 4/5 | Kubernetes] All of the required K8s tools installed successfully"$NC
}

display_success_message() {
# -------------------
# |    Summarize    |
# -------------------

host=$(hostname)

echo $SUCCESS"[Step 5/5 | $host] Ready for action"$NC
}

disable_swap() {
# ----------------------
# |    Disable swap    |
# ----------------------
echo $INFO"[Step 1/5 | Swap] Disabling swap"

sudo swapoff -a >> /dev/null
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab >> /dev/null

echo $SUCCESS"[Step 1/5 | Swap] Swap disabled successfully!"$NC
}

# run
define_colors
disable_swap
kernel_settings
install_containerd
install_k8s
display_success_message
