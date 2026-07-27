#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> [1/5] Docker 데몬 확인"
docker info >/dev/null || { echo "Docker Desktop을 먼저 실행하세요"; exit 1; }

echo "==> [2/5] kind 클러스터 + 로컬 레지스트리"
"${ROOT}/scripts/kind-with-registry.sh"

echo "==> [3/5] demo-api 빌드 & 레지스트리 push"
"${ROOT}/scripts/build-and-push.sh" 0.1.0

echo "==> [4/5] ArgoCD 설치 (Helm)"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f "${ROOT}/bootstrap/argocd-values.yaml" --wait --timeout 5m

echo "==> [5/5] app-of-apps 배선"
helm upgrade --install root "${ROOT}/charts/app-of-apps" -n argocd --wait

echo
echo "==> 완료. 상태 확인:"
kubectl -n argocd get applications
echo
PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo '(secret 없음)')
cat <<EOF

ArgoCD 대시보드: kubectl port-forward svc/argocd-server -n argocd 8080:80  → http://localhost:8080
  admin / ${PW}
데모 API:       kubectl port-forward svc/demo-app -n demo 8081:80         → http://localhost:8081/api/hello
k9s 실습:       docs/k9s-practice.md
EOF
