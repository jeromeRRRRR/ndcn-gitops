#!/bin/bash
# --- 1. Création du Cluster physique ---
kind create cluster --config cluster/kind-config.yaml --name ndcn-cilium

# --- 2. Installation du réseau eBPF (Cilium) ---
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.15.5 \
  --namespace kube-system \
  --set operator.replicas=1

# --- 3. Restauration de la Souveraineté des Secrets ---
# On installe le contrôleur puis on injecte TA clé privée (Master Key) 
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.2/controller.yaml
echo "Attente du contrôleur de secrets..."
sleep 20
kubectl apply -f ../040-git-secret-kubeseal/ndcn-sealed-secrets-master-key.yaml.PRIVATE_KEY_to_be_protected

# --- 4. Installation du Plan de Contrôle ArgoCD ---
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# --- 5. Lancement de la Synchronisation GitOps ---
echo "Injection de la stack NDCN..."
sleep 30
kubectl apply -f argoCD-app/ndcn-stack-app.yaml
kubectl apply -f argoCD-app/prometheus-stack-app.yaml
kubectl apply -f argoCD-app/metrics-server-app.yaml

echo "Le Nœud NDCN est en cours de déploiement automatique."

