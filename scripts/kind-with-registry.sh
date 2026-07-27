#!/usr/bin/env bash
set -euo pipefail
CLUSTER="k9s-demo"
REG_NAME="kind-registry"
REG_PORT="5001"
CONFIG="$(cd "$(dirname "$0")/../clusters/local" && pwd)/kind-config.yaml"

# 1. 레지스트리 컨테이너
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
  docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" \
    --network bridge --name "${REG_NAME}" registry:2
fi

# 2. 클러스터 생성 (없을 때만)
if ! kind get clusters | grep -qx "${CLUSTER}"; then
  kind create cluster --config "${CONFIG}"
fi

# 3. 각 노드에 registry hosts.toml 주입
REG_DIR="/etc/containerd/certs.d/localhost:${REG_PORT}"
for node in $(kind get nodes --name "${CLUSTER}"); do
  docker exec "${node}" mkdir -p "${REG_DIR}"
  echo "[host.\"http://${REG_NAME}:5000\"]" | docker exec -i "${node}" cp /dev/stdin "${REG_DIR}/hosts.toml"
done

# 4. 레지스트리를 kind 네트워크에 연결
if [ "$(docker inspect -f '{{json .NetworkSettings.Networks.kind}}' "${REG_NAME}")" = 'null' ]; then
  docker network connect "kind" "${REG_NAME}"
fi

# 5. 로컬 레지스트리 문서화 ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "==> kind '${CLUSTER}' + registry localhost:${REG_PORT} ready"
