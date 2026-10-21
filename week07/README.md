# 7주차: Docker Compose와 web 3개 유지

Windows PowerShell에서 수행한 Compose 실습 기록이다. 실행 결과와 화면은 사용자 터미널 출력 및 캡처를 근거로 기록했다.

## 구성과 학습 내용

교안의 guestbook 앱을 사용한다. nginx가 호스트 8080으로 요청을 받고 내부 web:5000으로 전달한다. web 3개가 같은 Redis를 사용하므로 동일한 데이터를 공유한다. nginx만 `ports: ["8080:80"]`로 공개하고 web은 내부 포트를 사용한다. web 각각에 동일한 호스트 포트를 지정하면 충돌한다.

`depends_on`의 `service_healthy`는 시작 시 준비 상태를 기다린다. healthcheck는 상태를 확인하는 기능이며 실행 중 장애를 자동 해결하는 기능과는 구분한다.

기존 `guestbook/app.py`와 Dockerfile을 사용하고 `guestbook/compose.yaml`, `nginx.conf`를 추가했다. 앱의 `/readyz`로 web의 준비 상태를 확인한다. Redis 비밀번호는 로컬 `.env`에서 읽으며 `.gitignore`와 `.dockerignore`에서 제외한다. 프로젝트 이름은 `devops-week07`이다.

## 48쪽 문제의 원인

`docker compose up -d --scale web=3`은 실행 시 web 수를 3개로 맞춘다. 이후 `docker stop`으로 하나를 직접 멈추면 `restart: unless-stopped`는 그 컨테이너를 자동으로 살리지 않는다. 남은 web으로 서비스가 가능하더라도 실행 중인 수는 2개이다.

## 배운 내용을 결합한 해결 방법

반복문으로 주기적으로 web의 실행 개수를 세고, 3이 아니면 같은 Compose 프로젝트에 `up -d --scale web=3 web`을 다시 실행한다. 교안의 조건·반복 개념을 Windows PowerShell에 적용했다. 실제 실행한 코드는 다음과 같다. guestbook 폴더에서 실행하며 Ctrl+C로 종료한다.

```powershell
while ($true) {
    $webIds = @(docker compose ps --status running -q web)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "상태 조회 실패"
    } elseif ($webIds.Count -ne 3) {
        Write-Host "현재 web=$($webIds.Count), 3개로 복구"
        docker compose up -d --scale web=3 web
    } else {
        Write-Host "web=3 유지 중"
    }
    Start-Sleep -Seconds 5
}
```

`keep-web3.ps1`은 같은 방식에 복구 명령 실패 기록을 추가한 파일이다. `keep-web3.sh`는 Bash용 대안으로 이번 실습에서는 실행하지 않았다.

프로젝트 이름은 기존 컨테이너가 속한 이름과 같아야 한다. 다른 이름을 지정하면 별도 프로젝트를 만들 수 있다. 스크립트는 Ctrl+C로 종료한다. 실습 종료·정비 전에 먼저 스크립트를 종료해야 컨테이너를 다시 띄우지 않는다.

## 검증할 순서

1. 수업 구성에서 `docker compose config --quiet`로 설정을 검사한다.
2. 기존 프로젝트와 같은 이름으로 `docker compose up -d --scale web=3`을 실행한다.
3. `docker compose ps`에서 web 3개 실행을 확인하고 로그를 저장한다.
4. 스크립트를 실행하고, 다른 터미널에서 해당 프로젝트 web 하나의 정확한 ID를 확인해 `docker stop <ID>`를 실행한다.
5. 2개 상태를 관찰한 뒤 다음 감시 주기와 기동 시간이 지나 3개로 복구되는지 확인한다.
6. nginx 응답, 각 web의 healthy 상태를 별도로 확인한다. 중지·기동 직후에는 일시적인 오류가 가능하다.
7. 감시 스크립트를 종료한 후 실습 환경을 정리한다.

## 한계

- 이 스크립트의 목표는 실행 중인 web 수 3개이다. 응답 가능한 web 3개를 보장하지 않는다.
- running이면서 unhealthy인 컨테이너는 별도 건강 상태 감시와 조치가 필요하다.
- 확인 주기와 재기동 시간이 있으므로 매 순간 3개를 보장하지 않는다.
- 호스트·Docker 엔진·감시 프로세스 자체가 중단되면 복구할 수 없다.
- 명령 실패를 기록하고 다음 주기에 재시도한다. 이미지·설정·자원 문제가 지속되면 원인을 해결해야 한다.

## 실제 결과

- 설정 검사: 사용자 제공 PowerShell 로그에서 `docker compose config --quiet`가 오류 없이 완료되었다.
- 중지 전 web 3개: `docker compose up -d --build --scale web=3` 로그와 `docker compose ps`에서 web-1, web-2, web-3 모두 healthy, Redis healthy, nginx 실행을 확인했다.
- 중지 후 web 2개: 사용자 출력에서 `docker stop devops-week07-web-2` 이후 web-2는 `Exited (137)` 상태였다. 이후 조회에도 web-1과 web-3만 실행 중(healthy)으로 남아 자동 재시작되지 않음을 확인했다. HTTP 응답은 중지 전 2026-10-21 07:25:12 GMT, 중지 후 07:26:20 GMT 모두 `200 OK`였다. 종료 코드 137만으로 원인을 추가 추정하지 않는다.
- 자동 복구 후 web 3개: 감시 코드가 `현재 web=2, 3개로 복구`를 출력했고 Compose가 web-2를 Started로 전환했다. 이후 `web=3 유지 중`이 두 번 출력됐다. Ctrl+C 후 `docker compose ps`에서 web-1·web-3은 Up 6 minutes (healthy), web-2는 Up 15 seconds (healthy)로 확인됐다.
- HTTP 응답·healthy 상태: 중지 전 web 3개 healthy, 중지 후 남은 2개 healthy 및 nginx HTTP 200 확인. 브라우저 화면에는 저장소 Redis가 표시되며 방명록은 비어 있었다. 글 공유·영속성은 아직 검증하지 않았다.

![Redis 모드로 실행 중인 방명록](images/guestbook.png)
- 복구 시간: Compose 로그에 web-2 Started 0.2s가 표시됐다. 이는 시작 작업에 표시된 시간이며 장애 감지부터 healthy까지의 전체 복구 시간은 측정하지 않았다.
- 정리: 3개를 처음 실행하는 명령만으로는 수동 중지 이후의 개수를 유지하지 못했다. 실행 개수를 확인하고 목표 3개와 다를 때 재조정하는 반복 작업으로 복구할 수 있었다. 이번에는 기존 중지 컨테이너를 재시작했으며 새 컨테이너 생성 실험과는 구분한다. Ctrl+C 후에는 감시가 끝나므로 자동 복구도 중단된다.

참고: 교안 07, 35~39쪽·42~48쪽. 교안 03의 조건·반복·파이프 개념을 결합한 추가 해결안이다.
