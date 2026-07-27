#!/usr/bin/env bash
set -euo pipefail
TAG="${1:-0.1.0}"
REG="localhost:5001"
IMAGE="${REG}/demo-api:${TAG}"
APP_DIR="$(cd "$(dirname "$0")/../apps/demo-api" && pwd)"

echo "==> bootJar"
( cd "$APP_DIR" && ./gradlew bootJar -q )

echo "==> docker build ${IMAGE}"
docker build -t "demo-api:${TAG}" -t "${IMAGE}" "$APP_DIR"

echo "==> docker push ${IMAGE}"
docker push "${IMAGE}"

echo "==> done: ${IMAGE}"
echo "    charts/demo-app/values.yaml 의 image.tag 를 '${TAG}' 로 맞추세요."
