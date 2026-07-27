# k9s 실습 시나리오

전제: `./scripts/up.sh` 완료. 우측 터미널에서 아래 실행 후 손으로 조작한다.

```bash
k9s --context kind-k9s-demo
```

## 기본 조작 (외우면 편한 키)

- `:` 명령 프롬프트 (`:ns`, `:pod`, `:deploy`, `:svc`, `:applications`)
- `/` 필터, `esc` 취소, `?` 도움말, `:q` 종료
- 리소스 위에서: `d` describe, `y` YAML, `l` 로그, `ctrl-d` 삭제, `enter` 파고들기
  - Pod 위에서 `s` = 컨테이너 shell / Deployment 위에서 `s` = scale
  - `shift-f` = 포트포워드

## 1. 탐색

1. `:ns` → `argocd`, `demo`, `kube-system` 확인
2. `:pod` 후 `/demo` 필터 → demo-app 파드 확인
3. `0` 을 눌러 all-namespace 토글

## 2. 관찰

1. `:pod` → demo 네임스페이스의 demo-app 파드 선택 → `l` 로그 (Spring Boot 기동 로그)
2. `d` describe → 이미지 `localhost:5001/demo-api:0.1.0`, readiness/liveness probe 확인
3. `y` 로 렌더된 YAML 확인
4. `s` 로 컨테이너 shell 진입 → `curl -s localhost:8080/api/hello` (없으면 `wget -qO- ...`) → `exit`

## 3. 조작

1. `:deploy` → demo-app 선택 → `s`(scale) → replicas `3` 입력 → `:pod`에서 파드 3개로 늘어나는 것 관찰
2. `:pod` → demo-app 파드 하나 선택 → `ctrl-d` 삭제 → Deployment가 즉시 새 파드로 재스케줄하는 것 관찰
3. `:deploy` → demo-app → `s` → 다시 `1`로 축소
   - 참고: ArgoCD `selfHeal: true`라 수동 scale 변경은 잠시 후 git 상태(replicas 1)로 **자동 복원**될 수 있음 → 이 자체가 GitOps를 체감하는 좋은 관찰거리
4. `:svc` → demo-app → `shift-f` 포트포워드 → 로컬 포트로 `curl`

## 4. ArgoCD 리소스 관찰

1. `:applications` → `demo-app` Application → `enter`로 리소스 트리 → sync/health 상태
   - `:applications` 가 안 열리면 전체 이름 `:applications.argoproj.io`
2. `argocd` 네임스페이스 파드(`:pod` + `/argocd`) 로그도 열어보기
3. 웹 대시보드도 함께:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
   kubectl port-forward svc/argocd-server -n argocd 8080:80
   ```
   → http://localhost:8080 (admin / 위 비밀번호)

## 5. GitOps 루프 체험 (핵심)

1. 앱 코드 수정: `apps/demo-api/src/main/kotlin/com/example/demoapi/HelloController.kt` 의 message 문구 변경
2. 새 태그로 빌드/푸시:
   ```bash
   ./scripts/build-and-push.sh 0.2.0
   ```
3. `charts/demo-app/values.yaml` 의 `image.tag` 를 `0.2.0` 으로 수정
4. 커밋 & 푸시:
   ```bash
   git commit -am "feat: demo-api 0.2.0" && git push
   ```
5. k9s에서 관찰: `:applications` → demo-app 이 `OutOfSync`→`Syncing`→`Synced`,
   `:pod`에서 롤링 업데이트(새 파드 Running, 옛 파드 Terminating) 실시간 확인
   - ArgoCD 기본 폴링은 ~3분. 즉시 반영을 원하면 대시보드 Sync 버튼

## 6. 두 관점 비교

- 한쪽 터미널: `k9s --context kind-k9s-demo`
- 브라우저: ArgoCD 대시보드 (위 4번 참고)
- 같은 배포 상태를 TUI와 웹 대시보드로 나란히 비교

---

## 정리

```bash
./scripts/down.sh   # 클러스터 + 레지스트리 삭제 (Docker Desktop은 유지)
```
