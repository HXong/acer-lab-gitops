#!/usr/bin/env bash
set -euo pipefail

APP_NAME=""
NAMESPACE=""
IMAGE_REPOSITORY=""
IMAGE_TAG="latest"
CONTAINER_PORT="80"
SERVICE_PORT="80"
NODE_PORT=""
HEALTH_PATH="/"
CPU_REQUEST="25m"
MEMORY_REQUEST="32Mi"
CPU_LIMIT="100m"
MEMORY_LIMIT="128Mi"
PULL_SECRET=""

usage() {
  cat <<EOF
Usage:
  $0 --name APP_NAME --namespace NAMESPACE --image IMAGE_REPOSITORY --node-port NODE_PORT [options]

Required:
  --name             App name, e.g. demo-web
  --namespace        Kubernetes namespace, e.g. demo-web
  --image            Image repository, e.g. nginx or ghcr.io/hxong/my-app
  --node-port        NodePort in range 30000-32767

Options:
  --tag              Image tag, default: latest
  --container-port   Container port, default: 80
  --service-port     Service port, default: 80
  --health-path      HTTP health path, default: /
  --cpu-request      CPU request, default: 25m
  --memory-request   Memory request, default: 32Mi
  --cpu-limit        CPU limit, default: 100m
  --memory-limit     Memory limit, default: 128Mi
  --pull-secret      Image pull secret name, e.g. ghcr-creds

Example:
  $0 --name demo-web-2 --namespace demo-web-2 --image nginx --tag alpine --node-port 30091

Private GHCR example:
  $0 --name my-api --namespace my-api --image ghcr.io/hxong/my-api --tag latest --node-port 30092 --pull-secret ghcr-creds
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) APP_NAME="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --image) IMAGE_REPOSITORY="$2"; shift 2 ;;
    --tag) IMAGE_TAG="$2"; shift 2 ;;
    --container-port) CONTAINER_PORT="$2"; shift 2 ;;
    --service-port) SERVICE_PORT="$2"; shift 2 ;;
    --node-port) NODE_PORT="$2"; shift 2 ;;
    --health-path) HEALTH_PATH="$2"; shift 2 ;;
    --cpu-request) CPU_REQUEST="$2"; shift 2 ;;
    --memory-request) MEMORY_REQUEST="$2"; shift 2 ;;
    --cpu-limit) CPU_LIMIT="$2"; shift 2 ;;
    --memory-limit) MEMORY_LIMIT="$2"; shift 2 ;;
    --pull-secret) PULL_SECRET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$APP_NAME" || -z "$NAMESPACE" || -z "$IMAGE_REPOSITORY" || -z "$NODE_PORT" ]]; then
  echo "Missing required argument."
  usage
  exit 1
fi

DNS_REGEX='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'

if [[ ! "$APP_NAME" =~ $DNS_REGEX ]]; then
  echo "Invalid app name: $APP_NAME"
  echo "Use lowercase DNS-safe names, e.g. demo-web."
  exit 1
fi

if [[ ! "$NAMESPACE" =~ $DNS_REGEX ]]; then
  echo "Invalid namespace: $NAMESPACE"
  echo "Use lowercase DNS-safe names, e.g. demo-web."
  exit 1
fi

if ! [[ "$NODE_PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid NodePort: $NODE_PORT"
  exit 1
fi

if (( NODE_PORT < 30000 || NODE_PORT > 32767 )); then
  echo "Invalid NodePort: $NODE_PORT"
  echo "NodePort must be between 30000 and 32767."
  exit 1
fi

APP_DIR="apps/$APP_NAME"
VALUES_FILE="$APP_DIR/values.yaml"
ARGO_APP_FILE="platform/argocd/apps/$APP_NAME.yaml"
ARGO_KUSTOMIZATION="platform/argocd/apps/kustomization.yaml"

if [[ -e "$APP_DIR" ]]; then
  echo "App directory already exists: $APP_DIR"
  exit 1
fi

if [[ -e "$ARGO_APP_FILE" ]]; then
  echo "ArgoCD app file already exists: $ARGO_APP_FILE"
  exit 1
fi

if kubectl get svc -A 2>/dev/null | grep -q ":$NODE_PORT/"; then
  echo "NodePort $NODE_PORT appears to already be in use."
  kubectl get svc -A | grep ":$NODE_PORT/" || true
  exit 1
fi

mkdir -p "$APP_DIR"
mkdir -p "platform/argocd/apps"

if [[ -n "$PULL_SECRET" ]]; then
  IMAGE_PULL_SECRETS_BLOCK=$(cat <<EOF
imagePullSecrets:
  - name: $PULL_SECRET
EOF
)
else
  IMAGE_PULL_SECRETS_BLOCK="imagePullSecrets: []"
fi

cat > "$VALUES_FILE" <<EOF
app:
  name: $APP_NAME
  namespace: $NAMESPACE
  partOf: acer-lab

replicaCount: 1
revisionHistoryLimit: 3

image:
  repository: $IMAGE_REPOSITORY
  pullPolicy: IfNotPresent
  tag: $IMAGE_TAG

$IMAGE_PULL_SECRETS_BLOCK

container:
  port: $CONTAINER_PORT

service:
  type: NodePort
  port: $SERVICE_PORT
  nodePort: $NODE_PORT

livenessProbe:
  httpGet:
    path: $HEALTH_PATH
    port: http
  initialDelaySeconds: 10
  periodSeconds: 20

readinessProbe:
  httpGet:
    path: $HEALTH_PATH
    port: http
  initialDelaySeconds: 3
  periodSeconds: 10

resources:
  requests:
    cpu: $CPU_REQUEST
    memory: $MEMORY_REQUEST
  limits:
    cpu: $CPU_LIMIT
    memory: $MEMORY_LIMIT

autoscaling:
  enabled: false
EOF

cat > "$ARGO_APP_FILE" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
  labels:
    app.kubernetes.io/name: $APP_NAME
    app.kubernetes.io/part-of: acer-lab
spec:
  project: default

  source:
    repoURL: https://github.com/hxong/acer-lab-gitops.git
    targetRevision: main
    path: charts/basic-web-app
    helm:
      valueFiles:
        - ../../apps/$APP_NAME/values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

if [[ ! -f "$ARGO_KUSTOMIZATION" ]]; then
  cat > "$ARGO_KUSTOMIZATION" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
EOF
fi

if ! grep -qx "  - $APP_NAME.yaml" "$ARGO_KUSTOMIZATION"; then
  echo "  - $APP_NAME.yaml" >> "$ARGO_KUSTOMIZATION"
fi

echo
echo "Generated Helm app onboarding files:"
echo "  Values:       $VALUES_FILE"
echo "  ArgoCD app:   $ARGO_APP_FILE"
echo "  Registry:     $ARGO_KUSTOMIZATION"
echo
echo "Validate with:"
echo "  helm lint charts/basic-web-app"
echo "  helm template $APP_NAME charts/basic-web-app -f $VALUES_FILE"
echo
echo "Next steps:"
echo "  git status"
echo "  git add scripts/new-helm-web-app.sh $VALUES_FILE $ARGO_APP_FILE $ARGO_KUSTOMIZATION"
echo "  git commit -m \"add $APP_NAME helm app\""
echo "  git push origin main"
