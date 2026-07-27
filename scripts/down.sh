#!/usr/bin/env bash
set -euo pipefail
echo "==> kind 클러스터 삭제"
kind delete cluster --name k9s-demo || true
echo "==> 로컬 레지스트리 컨테이너 삭제"
docker rm -f kind-registry 2>/dev/null || true
echo "==> 완료 (Docker Desktop 자체는 유지)"
