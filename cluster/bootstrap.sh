#!/bin/bash
set -e # Arrête le script en cas d'erreur

# --- 1. Vérification des outils locaux ---
command -v helm >/dev/null 2>&1 || { echo >&2 "ERREUR: Helm n'est pas installé. Installation requise."; exit 1; }
command -v kind >/dev/null 2>&1 || { echo >&2 "ERREUR: Kind n'est ZZpas installé."; exit 1; }

# --- 2. Création du Cluster ---
# Utilisation du fichier de config défini précédemment [cite: 63]
kind create cluster --config cluster/kind-config.yaml --name ndcn-cilium 

# --- 3. Installation de Cilium (Réseau eBPF) ---
echo "Installation de Cilium..."
helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1
helm install cilium cilium/cilium --version 1.15.5 \
  --namespace kube-system \
  --set operator.replicas=1

# ATTENTE : On attend que les nœuds passent au statut Ready
echo "Attente de la disponibilité des nœuds (CNI)..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# --- 4. Sécurité (Sealed Secrets) ---
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.2/controller.yaml
echo "Injection de la Master Key..."
# Utilisation du chemin corrigé par rapport à l'arborescence [cite: 62]
kubectl apply -f ../../040-git-secret-kubeseal/ndcn-sealed-secrets-master-key.yaml.PRIVATE_KEY_to_be_protected

# --- 5. ArgoCD (Le Plan de Contrôle) ---
kubectl create namespace argocd || true
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ATTENTE : On attend que le serveur ArgoCD soit opérationnel
echo "Attente d'ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# --- 6. Déploiement GitOps ---
echo "Synchronisation des applications NDCN..."
# Application des manifests normalisés [cite: 52, 53, 54]
kubectl apply -f argoCD-app/metrics-server-app.yaml
kubectl apply -f argoCD-app/cert-manager-app.yaml
kubectl apply -f argoCD-app/ndcn-stack-app.yaml
kubectl apply -f argoCD-app/prometheus-stack-app.yaml

echo "Félicitations Jérôme : Reconstruction terminée et vérifiée."
