kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f ./install.yaml