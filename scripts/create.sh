#!/bin/bash

# Go to root directory
DIR_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
cd "$DIR_ROOT" || exit 1

# Create the cluster
mkdir -p ~/mnt/kind/ 2> /dev/null
mkdir ./sensitive 2> /dev/null
kind delete cluster
kind create cluster --config ./manifests/kind-cluster.yaml

# Install ingress controller
echo "Installing Nginx controller..."
sleep 5
kubectl apply --server-side -f ./manifests/nginx-controller.yaml
echo "Nginx ingress controller installed. Waiting for the deployment to be up"
sleep 10
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
echo "Nginx ingress controller deployed."

# Install ArgoCD
echo "Deploying ArgoCD..."
kubectl create namespace argocd
kubectl apply --server-side --namespace argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/install.yaml
echo "Waiting for the server to be up and running..."
sleep 10
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=90s
echo "ArgoCD is up"
echo "Updating host file"
grep -v "argocd.local" /etc/hosts | sudo tee /etc/hosts > /dev/null
echo -e "127.0.0.1\targocd.local" | sudo tee -a /etc/hosts > /dev/null
echo "Deploying the ArgoCD ingress"
kubectl apply --server-side -f ./manifests/argocd-ingress.yaml
sleep 5
echo "Check argocd response"
if curl -k https://argocd.local > /dev/null; then
  echo "ArgoCD is accessible from https://argocd.local"
else
  echo "Something went wrong with argoCD deployment"
  exit 1
fi
echo "Storing ArgoCD admin password in a temp file"
kubectl get secret --namespace argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > ./sensitive/argocd-password
echo "Deploy ArgoCD application set and initialize gitops"
kubectl apply --server-side --namespace argocd -f ./manifests/argocd-applicationset-helm-git.yaml
kubectl apply --server-side --namespace argocd -f ./manifests/argocd-applicationset-helm-external.yaml
kubectl apply --server-side --namespace argocd -f ./manifests/argocd-applicationset-manifests.yaml