# 로컬 kind + ArgoCD GitOps k9s 실습 환경 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** kind 로컬 클러스터 위에 ArgoCD GitOps로 Spring Boot 4(Kotlin) 데모 API를 배포하고, k9s로 관찰·조작하는 실습 환경을 자동 구축한다.

**Architecture:** Docker Desktop 런타임 → kind 클러스터(+로컬 레지스트리 localhost:5001) → ArgoCD를 Helm으로 부트스트랩 → app-of-apps Helm 차트가 GitHub 저장소의 workload Helm 차트를 동기화. 모든 리소스는 Helm 차트로 선언. `git push` → ArgoCD auto-sync 루프.

**Tech Stack:** kind, Docker Desktop, Helm, ArgoCD(argo/argo-cd chart), Kotlin + Spring Boot 4.0(Gradle Kotlin DSL), k9s, kubectl.

## Global Constraints

- 저장소: `https://github.com/Joon9750/k9s-demo.git`, 기본 브랜치 `main`
- 클러스터 이름: `k9s-demo`
- 로컬 레지스트리: `localhost:5001` (컨테이너명 `kind-registry`)
- 데모 이미지: `localhost:5001/demo-api:0.1.0`
- 네임스페이스: ArgoCD=`argocd`, 워크로드=`demo`
- 런타임: Docker Desktop (context `desktop-linux`, 사용자가 기동함)
- 버전 핀: Spring Boot `4.0.0`, Kotlin `2.2.0`, io.spring.dependency-management `1.1.7`, Java toolchain `21`, Gradle wrapper `8.14`, 런타임 이미지 `eclipse-temurin:21-jre`
- **보안**: GitHub PAT는 어떤 파일에도 커밋하지 않는다. push 시 환경변수 `$GH_TOKEN`으로만 사용하고 macOS keychain에 시드한다. `.gitignore`로 빌드산출물/시크릿 제외.
- 작업 디렉터리: `~/k9s-demo` (이미 `git init -b main` + origin 설정 완료)

---

### Task 1: 프로젝트 스캐폴딩 & 도구 설치

**Files:**
- Create: `~/k9s-demo/.gitignore`
- Create: `~/k9s-demo/README.md`
- Create: 디렉터리 `apps/demo-api/`, `charts/`, `clusters/local/`, `bootstrap/`, `scripts/`, `docs/`

**Interfaces:**
- Produces: 설치된 CLI `kind`, `k9s`, `argocd`; 저장소 디렉터리 골격.

- [ ] **Step 1: 필요한 CLI 설치 (Gradle 포함 — 래퍼 생성용)**

Run:
```bash
brew install kind k9s argocd gradle
```
Expected: 각 formula 설치 완료 (이미 있으면 "already installed").

- [ ] **Step 2: 설치 검증**

Run:
```bash
kind version && k9s version && argocd version --client --short && gradle --version | head -3
```
Expected: kind/k9s/argocd 버전 문자열 출력, Gradle 8.x.

- [ ] **Step 3: 디렉터리 골격 생성**

Run:
```bash
cd ~/k9s-demo && mkdir -p apps/demo-api charts clusters/local bootstrap scripts docs
```
Expected: 에러 없음.

- [ ] **Step 4: `.gitignore` 작성**

`~/k9s-demo/.gitignore`:
```gitignore
# Gradle / Kotlin build outputs
apps/demo-api/.gradle/
apps/demo-api/build/
**/*.class

# Secrets / local overrides
*.local
.env
*.token

# OS / editor
.DS_Store
```

- [ ] **Step 5: `README.md` 작성**

`~/k9s-demo/README.md`:
```markdown
# k9s-demo

로컬 kind + ArgoCD GitOps 실습 환경. 목적은 **k9s를 손에 익히는 것**.

Spring Boot 4(Kotlin) REST API를 ArgoCD(app-of-apps, 모든 것을 Helm으로)로 배포한다.

## Quickstart
```bash
./scripts/up.sh        # 클러스터 + 레지스트리 + ArgoCD + 앱 전체 부트스트랩
```
- ArgoCD 대시보드: `kubectl port-forward svc/argocd-server -n argocd 8080:80` → http://localhost:8080
- 데모 API:       `kubectl port-forward svc/demo-app -n demo 8081:80` → http://localhost:8081/api/hello
- 정리:            `./scripts/down.sh`

## k9s 실습
`docs/k9s-practice.md` 참고.
```

- [ ] **Step 6: 커밋**

```bash
cd ~/k9s-demo && git add .gitignore README.md && git commit -m "chore: 스캐폴딩 및 도구 설치"
```

---

### Task 2: Spring Boot 4 + Kotlin 데모 API

**Files:**
- Create: `apps/demo-api/settings.gradle.kts`, `apps/demo-api/build.gradle.kts`
- Create: `apps/demo-api/src/main/kotlin/com/example/demoapi/DemoApiApplication.kt`
- Create: `apps/demo-api/src/main/kotlin/com/example/demoapi/HelloController.kt`
- Create: `apps/demo-api/src/main/resources/application.yaml`
- Create: `apps/demo-api/src/test/kotlin/com/example/demoapi/HelloControllerTest.kt`
- Create: Gradle wrapper (`gradlew`, `gradle/wrapper/*`)

**Interfaces:**
- Produces: `GET /api/hello` → `{"message":"hello","app":"demo-api","version":"0.1.0"}`; `/actuator/health` → `{"status":"UP"}`; bootJar 산출물 `build/libs/demo-api-0.1.0.jar`.

- [ ] **Step 1: `settings.gradle.kts`**

`apps/demo-api/settings.gradle.kts`:
```kotlin
rootProject.name = "demo-api"
```

- [ ] **Step 2: `build.gradle.kts`**

`apps/demo-api/build.gradle.kts`:
```kotlin
plugins {
    kotlin("jvm") version "2.2.0"
    kotlin("plugin.spring") version "2.2.0"
    id("org.springframework.boot") version "4.0.0"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.example"
version = "0.1.0"

java {
    toolchain { languageVersion.set(JavaLanguageVersion.of(21)) }
}

repositories { mavenCentral() }

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

// bootJar만 산출 (plain jar 비활성화 → COPY build/libs/*.jar 안전)
tasks.named<Jar>("jar") { enabled = false }

kotlin {
    compilerOptions { freeCompilerArgs.add("-Xjsr305=strict") }
}
```

- [ ] **Step 3: 애플리케이션 클래스**

`apps/demo-api/src/main/kotlin/com/example/demoapi/DemoApiApplication.kt`:
```kotlin
package com.example.demoapi

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class DemoApiApplication

fun main(args: Array<String>) {
    runApplication<DemoApiApplication>(*args)
}
```

- [ ] **Step 4: 컨트롤러**

`apps/demo-api/src/main/kotlin/com/example/demoapi/HelloController.kt`:
```kotlin
package com.example.demoapi

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

data class HelloResponse(val message: String, val app: String, val version: String)

@RestController
@RequestMapping("/api")
class HelloController {
    @GetMapping("/hello")
    fun hello(): HelloResponse =
        HelloResponse(message = "hello", app = "demo-api", version = "0.1.0")
}
```

- [ ] **Step 5: `application.yaml`**

`apps/demo-api/src/main/resources/application.yaml`:
```yaml
server:
  port: 8080
spring:
  application:
    name: demo-api
management:
  endpoints:
    web:
      exposure:
        include: health,info
```

- [ ] **Step 6: 실패하는 테스트 작성**

`apps/demo-api/src/test/kotlin/com/example/demoapi/HelloControllerTest.kt`:
```kotlin
package com.example.demoapi

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.http.HttpStatus

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class HelloControllerTest(@Autowired val rest: TestRestTemplate) {

    @Test
    fun `GET api hello returns 200 with hello message`() {
        val resp = rest.getForEntity("/api/hello", String::class.java)
        assertThat(resp.statusCode).isEqualTo(HttpStatus.OK)
        assertThat(resp.body).contains("\"message\":\"hello\"")
        assertThat(resp.body).contains("\"app\":\"demo-api\"")
    }
}
```

- [ ] **Step 7: Gradle 래퍼 생성**

Run:
```bash
cd ~/k9s-demo/apps/demo-api && gradle wrapper --gradle-version 8.14
```
Expected: `gradlew`, `gradle/wrapper/gradle-wrapper.{jar,properties}` 생성.

- [ ] **Step 8: 테스트 실행 (통과 확인)**

Run:
```bash
cd ~/k9s-demo/apps/demo-api && ./gradlew test
```
Expected: BUILD SUCCESSFUL, `HelloControllerTest` 통과.
(만약 `4.0.0` 의존성 해석 실패 시: `./gradlew dependencies` 로 확인 후 최신 `4.0.x` 로 조정하고 필요하면 `repositories`에 `maven { url = uri("https://repo.spring.io/milestone") }` 추가.)

- [ ] **Step 9: bootJar 빌드 및 로컬 스모크 테스트**

Run:
```bash
cd ~/k9s-demo/apps/demo-api && ./gradlew bootJar && ls build/libs/
java -jar build/libs/demo-api-0.1.0.jar &
sleep 8 && curl -s localhost:8080/api/hello && echo && curl -s localhost:8080/actuator/health
kill %1
```
Expected: `demo-api-0.1.0.jar` 존재, `/api/hello` JSON 응답, health `{"status":"UP"}`.

- [ ] **Step 10: 커밋**

```bash
cd ~/k9s-demo && git add apps/demo-api && git commit -m "feat: Spring Boot 4 + Kotlin 데모 API"
```

---

### Task 3: Dockerfile & 이미지 빌드

**Files:**
- Create: `apps/demo-api/Dockerfile`
- Create: `scripts/build-and-push.sh`

**Interfaces:**
- Consumes: `apps/demo-api/build/libs/demo-api-0.1.0.jar` (Task 2)
- Produces: 로컬 이미지 `demo-api:0.1.0`; 스크립트 `build-and-push.sh [tag]` (기본 tag `0.1.0`) — bootJar → docker build → registry push.

- [ ] **Step 1: `Dockerfile` (jar 복사형 런타임 이미지)**

`apps/demo-api/Dockerfile`:
```dockerfile
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

- [ ] **Step 2: `build-and-push.sh`**

`scripts/build-and-push.sh`:
```bash
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
```

Run:
```bash
chmod +x ~/k9s-demo/scripts/build-and-push.sh
```

- [ ] **Step 3: 로컬 이미지 빌드/실행 검증 (레지스트리 없이 이미지 자체만)**

Run:
```bash
cd ~/k9s-demo/apps/demo-api && ./gradlew bootJar -q
docker build -t demo-api:0.1.0 .
docker run --rm -d -p 8090:8080 --name demo-api-smoke demo-api:0.1.0
sleep 8 && curl -s localhost:8090/api/hello && echo
docker rm -f demo-api-smoke
```
Expected: 컨테이너에서 `/api/hello` JSON 응답. (레지스트리 push는 Task 4에서 클러스터/레지스트리 기동 후 수행.)

- [ ] **Step 4: 커밋**

```bash
cd ~/k9s-demo && git add apps/demo-api/Dockerfile scripts/build-and-push.sh && git commit -m "feat: demo-api Dockerfile 및 빌드/푸시 스크립트"
```

---

### Task 4: kind 클러스터 + 로컬 레지스트리 기동

**Files:**
- Create: `clusters/local/kind-config.yaml`
- Create: `scripts/kind-with-registry.sh`

**Interfaces:**
- Consumes: `scripts/build-and-push.sh` (Task 3)
- Produces: 실행 중인 kind 클러스터 `k9s-demo`, 레지스트리 컨테이너 `kind-registry`(localhost:5001), 클러스터 내부에서 `localhost:5001/...` pull 가능. kubeconfig context `kind-k9s-demo`.

- [ ] **Step 1: `kind-config.yaml`**

`clusters/local/kind-config.yaml`:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k9s-demo
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
nodes:
  - role: control-plane
```

- [ ] **Step 2: `kind-with-registry.sh` (kind 공식 로컬 레지스트리 패턴)**

`scripts/kind-with-registry.sh`:
```bash
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
```

Run:
```bash
chmod +x ~/k9s-demo/scripts/kind-with-registry.sh
```

- [ ] **Step 3: 클러스터 + 레지스트리 기동**

Run:
```bash
~/k9s-demo/scripts/kind-with-registry.sh
kubectl cluster-info --context kind-k9s-demo
kubectl get nodes
```
Expected: control-plane 노드 `Ready`, cluster-info 정상.

- [ ] **Step 4: demo-api 이미지 push + 레지스트리 왕복 검증**

Run:
```bash
~/k9s-demo/scripts/build-and-push.sh 0.1.0
curl -s http://localhost:5001/v2/_catalog
```
Expected: `docker push` 성공, catalog에 `{"repositories":["demo-api"]}` 포함.

- [ ] **Step 5: 클러스터가 레지스트리 이미지를 pull 하는지 확인**

Run:
```bash
kubectl run reg-test --image=localhost:5001/demo-api:0.1.0 --restart=Never \
  --command -- sleep 30
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/reg-test --timeout=60s
kubectl delete pod reg-test --now
```
Expected: 파드가 `Running` 도달(= 클러스터 내부에서 localhost:5001 이미지 pull 성공).

- [ ] **Step 6: 커밋**

```bash
cd ~/k9s-demo && git add clusters/local/kind-config.yaml scripts/kind-with-registry.sh && git commit -m "feat: kind 클러스터 + 로컬 레지스트리 부트스트랩"
```

---

### Task 5: Helm 차트 (demo-app + app-of-apps)

**Files:**
- Create: `charts/demo-app/{Chart.yaml,values.yaml,templates/deployment.yaml,templates/service.yaml}`
- Create: `charts/app-of-apps/{Chart.yaml,values.yaml,templates/application.yaml}`

**Interfaces:**
- Consumes: 이미지 `localhost:5001/demo-api:0.1.0` (Task 4)
- Produces: `charts/demo-app` — `demo-app` Deployment(1 replica) + Service(ClusterIP :80→8080); `charts/app-of-apps` — `demo-app` ArgoCD Application(namespace `argocd`, repo=GitHub, path=`charts/demo-app`, dest ns=`demo`, automated sync).

- [ ] **Step 1: `charts/demo-app/Chart.yaml`**

```yaml
apiVersion: v2
name: demo-app
description: Spring Boot 4 demo API
type: application
version: 0.1.0
appVersion: "0.1.0"
```

- [ ] **Step 2: `charts/demo-app/values.yaml`**

```yaml
replicaCount: 1

image:
  repository: localhost:5001/demo-api
  tag: "0.1.0"
  pullPolicy: IfNotPresent

service:
  port: 80
  targetPort: 8080

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

- [ ] **Step 3: `charts/demo-app/templates/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 20
            periodSeconds: 10
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

- [ ] **Step 4: `charts/demo-app/templates/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: ClusterIP
  selector:
    app: {{ .Chart.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
```

- [ ] **Step 5: `charts/app-of-apps/Chart.yaml`**

```yaml
apiVersion: v2
name: app-of-apps
description: ArgoCD app-of-apps 루트 차트
type: application
version: 0.1.0
```

- [ ] **Step 6: `charts/app-of-apps/values.yaml`**

```yaml
spec:
  repoURL: https://github.com/Joon9750/k9s-demo.git
  targetRevision: main
  destinationServer: https://kubernetes.default.svc

apps:
  - name: demo-app
    path: charts/demo-app
    namespace: demo
```

- [ ] **Step 7: `charts/app-of-apps/templates/application.yaml`**

```yaml
{{- range .Values.apps }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ $.Values.spec.repoURL }}
    targetRevision: {{ $.Values.spec.targetRevision }}
    path: {{ .path }}
  destination:
    server: {{ $.Values.spec.destinationServer }}
    namespace: {{ .namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
{{- end }}
```

- [ ] **Step 8: 렌더링 검증 (lint + template)**

Run:
```bash
cd ~/k9s-demo
helm lint charts/demo-app charts/app-of-apps
helm template demo-app charts/demo-app | grep -E "kind: (Deployment|Service)"
helm template root charts/app-of-apps | grep -E "kind: Application|path: charts/demo-app|namespace: demo"
```
Expected: lint 통과(에러 0). demo-app에서 Deployment/Service 렌더. app-of-apps에서 Application + path/namespace 렌더.

- [ ] **Step 9: 커밋**

```bash
cd ~/k9s-demo && git add charts && git commit -m "feat: demo-app 및 app-of-apps Helm 차트"
```

---

### Task 6: ArgoCD 부트스트랩 (Helm)

**Files:**
- Create: `bootstrap/argocd-values.yaml`

**Interfaces:**
- Consumes: 실행 중인 kind 클러스터 (Task 4)
- Produces: `argocd` 네임스페이스에 ArgoCD 설치, `argocd-server`는 insecure(HTTP) 모드; 초기 admin 비밀번호는 `argocd-initial-admin-secret`.

- [ ] **Step 1: `bootstrap/argocd-values.yaml`**

```yaml
# argocd-server를 HTTP(insecure)로 → port-forward 8080:80 로 단순 접근
configs:
  params:
    server.insecure: true
```

- [ ] **Step 2: Helm repo 추가 및 설치**

Run:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f ~/k9s-demo/bootstrap/argocd-values.yaml \
  --wait --timeout 5m
```
Expected: `STATUS: deployed`.

- [ ] **Step 3: ArgoCD 파드 Ready 확인**

Run:
```bash
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
kubectl -n argocd get pods
```
Expected: `argocd-server` Available, 모든 파드 Running/Ready.

- [ ] **Step 4: 대시보드 접근 & 로그인 검증**

Run:
```bash
PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
kubectl -n argocd port-forward svc/argocd-server 8080:80 >/tmp/argocd-pf.log 2>&1 &
sleep 5
argocd login localhost:8080 --username admin --password "$PW" --plaintext --insecure
argocd app list
kill %1 2>/dev/null || true
echo "ArgoCD admin password: $PW"
```
Expected: `argocd login` 성공, `argocd app list`가 (아직 앱 없음이라도) 에러 없이 반환.

- [ ] **Step 5: 커밋**

```bash
cd ~/k9s-demo && git add bootstrap/argocd-values.yaml && git commit -m "feat: ArgoCD Helm 부트스트랩 values"
```

---

### Task 7: GitHub push & app-of-apps 배선 (E2E GitOps)

**Files:**
- 없음 (이전 태스크의 커밋들을 GitHub에 push하고 app-of-apps를 클러스터에 배선)

**Interfaces:**
- Consumes: 커밋된 `charts/*` (Task 5), 실행 중인 ArgoCD (Task 6), 레지스트리에 push된 이미지 (Task 4)
- Produces: GitHub `main`에 저장소 반영; 클러스터에 `root` helm 릴리스 → `demo-app` Application → `demo` 네임스페이스에 demo-api 배포(Healthy/Synced).

- [ ] **Step 1: GitHub 인증 시드 (토큰은 env로만, 파일 미기록)**

> 실행자는 `$GH_TOKEN` 환경변수에 PAT를 넣어 이 스텝을 실행한다. 토큰을 명령 인자/파일에 남기지 않는다.

Run:
```bash
cd ~/k9s-demo
git config --local credential.helper osxkeychain
printf "protocol=https\nhost=github.com\nusername=Joon9750\npassword=%s\n\n" "$GH_TOKEN" \
  | git credential-osxkeychain store
```
Expected: 에러 없음 (keychain에 자격증명 시드).

- [ ] **Step 2: GitHub로 push**

Run:
```bash
cd ~/k9s-demo && git push -u origin main
git ls-remote --heads origin main
```
Expected: push 성공, `main` ref 해시 출력. (이후 GitHub 웹에서 charts/ 확인 가능.)

- [ ] **Step 3: app-of-apps 배선**

Run:
```bash
helm install root ~/k9s-demo/charts/app-of-apps -n argocd --wait
kubectl -n argocd get applications
```
Expected: `demo-app` Application 생성됨.

- [ ] **Step 4: ArgoCD 동기화 & 배포 검증**

Run:
```bash
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/demo-app --timeout=180s
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/demo-app --timeout=180s
kubectl -n demo get deploy,svc,pods
```
Expected: demo-app Application `Synced` + `Healthy`; `demo` 네임스페이스에 demo-app Deployment/Service/Pod(Running).

- [ ] **Step 5: 데모 API 엔드투엔드 호출**

Run:
```bash
kubectl -n demo port-forward svc/demo-app 8081:80 >/tmp/demo-pf.log 2>&1 &
sleep 5
curl -s localhost:8081/api/hello && echo
kill %1 2>/dev/null || true
```
Expected: `{"message":"hello","app":"demo-api","version":"0.1.0"}`.

---

### Task 8: up.sh / down.sh 조립 & 재현성 검증

**Files:**
- Create: `scripts/up.sh`, `scripts/down.sh`

**Interfaces:**
- Consumes: `kind-with-registry.sh`, `build-and-push.sh` (Task 3–4), charts, argocd-values (Task 5–6)
- Produces: `up.sh` — 무(無)에서 전체 스택 부트스트랩; `down.sh` — 클러스터+레지스트리 정리. **전제**: 저장소가 이미 GitHub에 push되어 있음(ArgoCD 소스).

- [ ] **Step 1: `scripts/up.sh`**

`scripts/up.sh`:
```bash
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
helm repo update >/dev/null
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
```

- [ ] **Step 2: `scripts/down.sh`**

`scripts/down.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
echo "==> kind 클러스터 삭제"
kind delete cluster --name k9s-demo || true
echo "==> 로컬 레지스트리 컨테이너 삭제"
docker rm -f kind-registry 2>/dev/null || true
echo "==> 완료 (Docker Desktop 자체는 유지)"
```

Run:
```bash
chmod +x ~/k9s-demo/scripts/up.sh ~/k9s-demo/scripts/down.sh
```

- [ ] **Step 3: 재현성 검증 — 전체 teardown 후 재기동**

Run:
```bash
~/k9s-demo/scripts/down.sh
~/k9s-demo/scripts/up.sh
```
Expected: `up.sh`가 무에서 전체 스택을 다시 세우고, 마지막에 `demo-app` Application 목록 + 접근 안내 출력. (에러 없이 완주.)

- [ ] **Step 4: 재기동 후 최종 검증**

Run:
```bash
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/demo-app --timeout=240s
kubectl -n demo get pods
```
Expected: demo-app `Healthy`, demo 파드 Running.

- [ ] **Step 5: 커밋**

```bash
cd ~/k9s-demo && git add scripts/up.sh scripts/down.sh && git commit -m "feat: up/down 부트스트랩 스크립트 및 재현성 검증"
```

---

### Task 9: k9s 실습 가이드 & 마무리

**Files:**
- Create: `docs/k9s-practice.md`

**Interfaces:**
- Consumes: 실행 중인 전체 스택 (Task 7–8)
- Produces: k9s 실습 시나리오 문서; GitHub에 최종 반영.

- [ ] **Step 1: `docs/k9s-practice.md` 작성**

`docs/k9s-practice.md`:
````markdown
# k9s 실습 시나리오

전제: `./scripts/up.sh` 완료. 우측 터미널에서 아래 실행 후 손으로 조작한다.

```bash
k9s --context kind-k9s-demo
```

## 기본 조작 (외우면 편한 키)
- `:` 명령 프롬프트 (`:ns`, `:pod`, `:deploy`, `:svc`, `:application`)
- `/` 필터, `esc` 취소, `?` 도움말, `:q` 종료
- 리소스 위에서: `d` describe, `y` YAML, `l` 로그, `s` shell/scale(맥락에 따라), `ctrl-d` 삭제, `enter` 파고들기

## 1. 탐색
1. `:ns` → `argocd`, `demo`, `kube-system` 확인
2. `:pod` 후 `/demo` 필터 → demo-app 파드 확인
3. `0` 을 눌러 all-namespace 토글

## 2. 관찰
1. `:pod` → demo 네임스페이스의 demo-app 파드 선택 → `l` 로그 (Spring 기동 로그)
2. `d` describe → 이미지 `localhost:5001/demo-api:0.1.0`, readiness/liveness probe 확인
3. `y` 로 렌더된 YAML 확인
4. `s` 로 컨테이너 shell 진입 → `wget -qO- localhost:8080/api/hello` → `exit`

## 3. 조작
1. `:deploy` → demo-app 선택 → `s` (scale) → replicas 3 입력 → `:pod`에서 파드 3개로 늘어나는 것 관찰
2. `:pod` → demo-app 파드 하나 선택 → `ctrl-d` 삭제 → Deployment가 즉시 새 파드로 재스케줄하는 것 관찰
3. `:deploy` → demo-app → `s` → 다시 1로 축소
   - 참고: ArgoCD `selfHeal: true`라 scale 변경은 잠시 후 git 상태(1)로 되돌아올 수 있음 → 이 자체가 좋은 관찰거리
4. `:svc` → demo-app → `shift-f` 포트포워드 → 로컬 포트로 `curl`

## 4. ArgoCD 리소스 관찰
1. `:application` → `demo-app` Application → `enter`로 리소스 트리 → sync/health 상태
2. `argocd` 네임스페이스 파드(`:pod` + `/argocd`) 로그도 열어보기

## 5. GitOps 루프 체험 (핵심)
1. 앱 코드 수정: `apps/demo-api/.../HelloController.kt` 의 message 문구 변경
2. 새 태그로 빌드/푸시:
   ```bash
   ./scripts/build-and-push.sh 0.2.0
   ```
3. `charts/demo-app/values.yaml` 의 `image.tag` 를 `0.2.0` 으로 수정
4. 커밋 & 푸시:
   ```bash
   git commit -am "feat: demo-api 0.2.0" && git push
   ```
5. k9s에서 관찰: `:application` → demo-app 이 OutOfSync→Syncing→Synced,
   `:pod`에서 롤링 업데이트(새 파드 Running, 옛 파드 Terminating) 실시간 확인
   - 즉시 반영을 원하면 대시보드 Sync 버튼 또는 `argocd app sync demo-app`

## 6. 두 관점 비교
- 한쪽 터미널: `k9s`
- 브라우저: `kubectl port-forward svc/argocd-server -n argocd 8080:80` → http://localhost:8080
- 같은 배포 상태를 TUI와 웹 대시보드로 나란히 비교
````

- [ ] **Step 2: 커밋 & push**

```bash
cd ~/k9s-demo && git add docs/k9s-practice.md && git commit -m "docs: k9s 실습 시나리오" && git push
```

- [ ] **Step 3: 최종 안내 출력**

Run:
```bash
cd ~/k9s-demo && cat <<'EOF'
셋업 완료. 다음으로:
  1) 우측 터미널: k9s --context kind-k9s-demo
  2) docs/k9s-practice.md 따라 실습
  3) 정리: ./scripts/down.sh
EOF
```
Expected: 안내 출력.

---

## 실행 후 사용자 조치 (중요)
- 대화에 평문 노출된 GitHub PAT를 **폐기(revoke)하고 재발급** 권장.
- 이후 `git push`는 keychain에 시드된 자격증명으로 동작.
