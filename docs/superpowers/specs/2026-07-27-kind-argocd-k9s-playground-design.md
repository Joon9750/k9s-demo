# 로컬 kind + ArgoCD GitOps 플레이그라운드 (k9s 실습용)

- **작성일**: 2026-07-27
- **저장소**: https://github.com/Joon9750/k9s-demo
- **상태**: 설계 확정 (구현 대기)

## 1. 목적 (Why)

**이 프로젝트의 최우선 목적은 k9s를 손에 익히는 것.** kind 로컬 쿠버네티스 클러스터
위에 ArgoCD 기반 GitOps 파이프라인을 구성하고, 실제 워크로드(Spring Boot 4 + Kotlin
REST API)를 배포한 뒤, 그 위에서 k9s로 리소스를 관찰·조작하는 실습을 한다.

부가 목표:
- 모든 리소스를 **Helm 차트로 선언적 관리** (ArgoCD 자체, app-of-apps 루트, 워크로드 전부)
- `git push` → ArgoCD 자동 동기화의 **GitOps 루프**를 눈으로 체험
- `kubectl`과 `k9s`로 조회/조작

## 2. 역할 분담 (핵심 결정)

- **자동 (Claude가 스크립트로 수행)**: colima 기동 → kind 클러스터 + 로컬 레지스트리 →
  ArgoCD(Helm) → app-of-apps → demo-api 빌드·푸시 → 배포 및 동작 검증까지 전부.
- **수동 (사용자가 직접)**: 이미 떠 있는 클러스터에서 우측 터미널에 `k9s`를 실행하고,
  `docs/k9s-practice.md`의 실습 시나리오를 손으로 조작하며 연습.

> 즉 결과물의 무게중심은 "자동 부트스트랩" + "잘 짜인 k9s 실습 가이드"다.

## 3. 환경 전제 (확인 완료)

| 항목 | 상태 |
|------|------|
| macOS (Darwin 23.6.0, arm64) | ✅ |
| Docker CLI 28.1.1 | ✅ (데몬은 colima로 제공) |
| kubectl v1.33.4, helm v3.18.3 | ✅ 설치됨 |
| JDK 21 (Corretto, sdkman) | ✅ Spring Boot 4 baseline(Java 17+) 충족 |
| Homebrew 6.0.11 | ✅ |
| colima / Docker Desktop / Rancher Desktop | 모두 설치됨 → **colima 사용** |
| kind, k9s, argocd CLI | ❌ 미설치 → brew로 설치 |
| GitHub repo Joon9750/k9s-demo | 존재하나 비어 있음 → 채워 넣음 |

## 4. 아키텍처

### 4.1 런타임 & 클러스터
- 컨테이너 런타임: **colima** (`colima start`, 순수 CLI, 재현 가능)
- 클러스터: **kind**, 이름 `k9s-demo`, 단일 control-plane 노드
- **로컬 레지스트리**: `registry:2` 컨테이너를 `localhost:5001`에 기동하고 kind 노드의
  containerd에 endpoint 매핑(kind-with-registry 표준 패턴). 데모 이미지는
  `localhost:5001/demo-api:<tag>`로 참조.

### 4.2 GitOps (모든 것을 Helm으로)
- **ArgoCD**: 공식 Helm 차트 `argo/argo-cd`로 **부트스트랩 설치** (닭-달걀 문제로
  ArgoCD 자기 자신만 로컬 `helm install`).
- **app-of-apps 루트**: ArgoCD `Application` CRD들을 렌더하는 **Helm 차트**
  (`charts/app-of-apps`). 부트스트랩 시 로컬에서 `helm install`로 한 번 심고, 이후
  이 루트가 git repo를 소스로 하위 앱들을 동기화.
- **워크로드**: `charts/demo-app` — Spring 데모 앱의 Deployment + Service를 렌더하는
  Helm 차트.
- 공개 저장소이므로 ArgoCD가 읽는 데 자격증명 불필요. `git push`만 토큰 필요.

### 4.3 데모 앱: Spring Boot 4 + Kotlin
- 위치: `apps/demo-api/`
- 빌드: Gradle (Kotlin DSL), Gradle Wrapper 사용
- 프레임워크: **Spring Boot 4.0**, Kotlin, `spring-boot-starter-web`
- 엔드포인트: `GET /api/hello` → JSON (예: `{"message":"hello","app":"demo-api",...}`),
  헬스체크용 actuator(`/actuator/health`) 포함
- 이미지: `./gradlew bootJar`로 jar 생성 후 슬림 JRE 런타임 Dockerfile로 패키징

## 5. 저장소 구조

```
k9s-demo/
├── clusters/local/kind-config.yaml        # kind 클러스터 + 레지스트리 containerd 패치
├── bootstrap/argocd-values.yaml           # ArgoCD Helm values (insecure/기타 설정)
├── apps/demo-api/                         # Spring Boot 4 + Kotlin 소스
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradlew, gradle/wrapper/…
│   ├── src/main/kotlin/com/example/demoapi/
│   │   ├── DemoApiApplication.kt
│   │   └── HelloController.kt
│   ├── src/main/resources/application.yaml
│   └── Dockerfile
├── charts/
│   ├── app-of-apps/                       # 루트 Helm 차트 (Application CRD 렌더)
│   │   ├── Chart.yaml
│   │   ├── values.yaml                    # 관리할 앱 목록
│   │   └── templates/application.yaml
│   └── demo-app/                          # 워크로드 Helm 차트
│       ├── Chart.yaml
│       ├── values.yaml                    # image repo/tag, replicas, service port
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
├── scripts/
│   ├── up.sh                              # 전체 부트스트랩(자동)
│   ├── down.sh                            # 클러스터/레지스트리 정리
│   └── build-and-push.sh                  # demo-api 빌드→푸시(→태그 bump 안내)
└── docs/
    ├── k9s-practice.md                    # ★ k9s 실습 시나리오
    └── superpowers/specs/2026-07-27-…-design.md
```

## 6. 부트스트랩 흐름 (`scripts/up.sh`)

1. 필요한 도구 확인/설치 (`kind`, `k9s`, `argocd` — brew)
2. `colima start` (미실행 시) 및 docker context 확인
3. 로컬 레지스트리 컨테이너 기동 (`localhost:5001`)
4. `kind create cluster --config clusters/local/kind-config.yaml`
5. 레지스트리를 kind 네트워크에 연결 + registry 힌트 ConfigMap 적용
6. `helm repo add argo …` → `helm install argocd argo/argo-cd -n argocd --create-namespace -f bootstrap/argocd-values.yaml`
7. `scripts/build-and-push.sh` — demo-api 빌드 후 `localhost:5001/demo-api:0.1.0` 푸시
8. `helm install root ./charts/app-of-apps -n argocd` → ArgoCD가 git repo의
   `charts/app-of-apps` → `charts/demo-app`를 동기화하여 demo-api 배포
9. 배포 검증: 파드 Ready, `GET /api/hello` 응답 확인
10. 접근 정보 출력 (ArgoCD admin 비번, port-forward 명령)

## 7. 접근 방법

- **ArgoCD 대시보드**: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
  → `https://localhost:8080` (초기 비번: 스크립트가 출력)
- **데모 API**: `kubectl port-forward svc/demo-app -n demo 8081:80`
  → `http://localhost:8081/api/hello`
- **조회/조작**: `kubectl`, `k9s`

## 8. 개발 루프 (GitOps)

```
apps/demo-api 코드 수정
  → ./gradlew bootJar
  → docker build -t localhost:5001/demo-api:<new-tag> .
  → docker push localhost:5001/demo-api:<new-tag>
  → charts/demo-app/values.yaml 의 image.tag 를 <new-tag> 로 수정
  → git commit && git push
  → ArgoCD auto-sync (기본 폴링 ~3분, 즉시 원하면 UI Sync 또는 `argocd app sync`)
  → rolling update  ← k9s에서 실시간 관찰
```

## 9. ★ k9s 실습 시나리오 (`docs/k9s-practice.md`)

사용자가 우측 터미널에서 `k9s` 실행 후 직접 수행:

1. **탐색**: `:ns`로 네임스페이스 전환, `:pod`/`:deploy`/`:svc`, `/`필터, `argocd`·`demo` 관찰
2. **관찰**: demo-api 파드 로그(`l`), describe(`d`), YAML(`y`), 컨테이너 shell(`s`)
3. **조작**: Deployment 스케일(`s`), 파드 삭제 후 재스케줄 관찰(`ctrl-d`), 포트포워드(`shift-f`)
4. **ArgoCD 관찰**: `:application`(CRD) 또는 `argocd` 네임스페이스 리소스, sync/health 상태
5. **GitOps 루프 체험**: 이미지 태그 bump → `git push` → k9s에서 롤링 업데이트 실시간 관찰
6. **비교**: ArgoCD 대시보드(`https://localhost:8080`)와 k9s를 나란히 놓고 같은 상태를 두 관점으로

각 항목은 문서에 "무엇을 / 어떤 키로 / 무엇을 관찰" 형태로 구체적 키바인딩과 함께 기술.

## 10. 보안 & 자격증명

- GitHub PAT는 **저장소에 절대 커밋하지 않음**. git push 인증 시 macOS keychain
  credential helper 또는 로컬 환경변수로만 사용. `.gitignore`에 민감 파일 패턴 포함.
- 세팅 완료 후 사용자에게 **해당 PAT 폐기(revoke) 및 재발급** 권고 (대화에 평문 노출됨).

## 11. 정리 (`scripts/down.sh`)

- `kind delete cluster --name k9s-demo`
- 로컬 레지스트리 컨테이너 제거
- (선택) `colima stop`

## 12. 범위 밖 (YAGNI)

- Ingress/LoadBalancer 노출 (port-forward로 충분)
- 관찰 스택(Prometheus/Grafana), 멀티 노드, 멀티 앱
- ArgoCD 웹훅 기반 즉시 동기화 (로컬 폴링으로 충분)
- CI 파이프라인 (로컬 스크립트로 빌드)
