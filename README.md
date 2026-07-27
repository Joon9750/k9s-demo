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
