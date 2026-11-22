<div align="center">

# termux-boot-adb-tcp

Android를 재부팅한 뒤에도 고정 ADB TCP 포트를 되살리는 Termux:Boot 스크립트와 호스트 CLI입니다.

[English](README.md) · Android의 Termux · 호스트는 macOS 또는 Linux

[![license](https://img.shields.io/github/license/elfenomenokim/termux-boot-adb-tcp)](LICENSE)
[![tests](https://github.com/elfenomenokim/termux-boot-adb-tcp/actions/workflows/tests.yml/badge.svg)](https://github.com/elfenomenokim/termux-boot-adb-tcp/actions/workflows/tests.yml)

[설치](#설치) · [빠른 시작](#빠른-시작) · [용도](#용도) · [설정](#설정) · [제한](#제한)

</div>

```console
$ termux-adb doctor --device 192.168.0.10:5555
termux-adb 0.2.0 doctor  ·  192.168.0.10:5555

✓ adb: SM-X900 · Android 16 · 192.168.0.10:5555
✓ com.termux 0.118.3
✓ com.termux.boot 0.8.1 launched once
✓ packages enabled
✓ battery allow-list: com.termux
✓ battery allow-list: com.termux.boot
✓ samsung: com.termux is not in the auto-disable target list
! boot script installed, bytes differ from this 0.2.0 copy
    fix: termux-adb install
✓ watch running (pid 12441)
✓ sshd running (pid 12421)
✓ wireless debugging on (adb_wifi_enabled=1)
✓ port 5555 open on 192.168.0.10 (service.adb.tcp.port=5555)
✓ boot.log, last 3 lines
    [2026-11-22 04:04:59] PID: 12441 | UID: 10315 | USER: u0_a315
    [2026-11-22 04:04:59] System boot completed detected (waited 1s).
    [2026-11-22 04:04:59] Watch started: checking port 5555 every 60s.

12 ok, 1 warning, 0 problem
```

<sub>Samsung Galaxy Tab S8에서 실제로 실행한 출력입니다. 기기에 이전 버전 스크립트가 남아 있어 한 줄이 경고로 나옵니다. 주소는 예시입니다.</sub>

## 설치

컴퓨터에는 Android platform-tools, `curl`, `gpg`가 필요합니다. 기기에서 무선 디버깅을 켜고 컴퓨터에서 `adb pair HOST:PAIRING_PORT`, `adb connect HOST:PORT`로 연결하세요. 그다음 `termux-adb install --fetch-apps`가 [Termux](https://github.com/termux/termux-app/releases)와 [Termux:Boot](https://github.com/termux/termux-boot/releases)(GitHub 빌드, sha256 확인), [KeepADB](https://f-droid.org/packages/de.hohnepeople.keepadb/)(F-Droid, gpg 서명 확인)를 내려받아 설치합니다. Termux와 Termux:Boot를 직접 설치해도 됩니다. 이때 둘은 같은 곳에서 받아야 합니다.

AI 에이전트가 다른 사람의 기기를 설정할 때는 [AGENTS.md의 Set up for a user](AGENTS.md#set-up-for-a-user)를 따릅니다. 사람이 할 일은 개발자 옵션 켜기, 페어링 코드 읽어 주기, 원격 접속이 필요하면 Tailscale 로그인뿐입니다.

컴퓨터에서 저장소를 복제하고 `termux-adb`를 PATH에 추가하세요. `boot-restore-adb.sh`는 그 옆에 두세요.

## 빠른 시작

Termux에서 실행하세요.

```bash
curl -fsSL https://raw.githubusercontent.com/elfenomenokim/termux-boot-adb-tcp/main/setup.sh | bash -s --
```

필요하면 `--` 뒤에 `--battery-saver`, `--vpn-app com.tailscale.ipn` 또는 `--ssh-key "ssh-ed25519 AAAA..."`를 추가하세요. Termux에서 `adb connect 127.0.0.1:5555`를 실행하고 기기에서 **항상 허용**을 누르세요. 컴퓨터에서 실행하세요.

```bash
termux-adb --device 192.168.0.10:5555 install
termux-adb --device 192.168.0.10:5555 doctor --ssh-port 8022 --ssh-user USER
termux-adb --device 192.168.0.10:5555 keeper --install
```

`USER`에는 setup이 출력한 Termux 사용자를 입력하세요. SSH 진단에는 SSH 인증이 필요합니다. `install --keep-auth-timeout`은 Android 인증 만료 설정을 유지합니다. `keeper --notify-cmd /path/to/executable --notify-after 3`은 연속 3회 실패와 복구 시 메시지를 인수로 전달합니다. 예약하려면 같은 옵션을 `keeper --install`에 추가하세요.

## 시스템 업데이트 후 유지되는 항목

앱, 데이터, 키, 배터리 허용 목록은 유지됩니다. 포트 5555는 재부팅 때 닫히며 watch가 다시 엽니다. 주요 업데이트가 개발자 옵션이나 무선 디버깅을 끌 수 있습니다. SSH는 계속 작동하지만 ADB에는 무선 디버깅을 수동으로 다시 켜야 합니다. 연결할 수 있으면 `doctor`가 상태를 표시합니다. Tailscale 같은 VPN 앱은 Android 상시 VPN으로 지정하지 않으면 업데이트 재부팅 뒤 꺼진 채로 남습니다. `install`이나 `setup.sh`에 `--vpn-app 패키지이름`을 주세요(Fold4에서 One UI 업데이트 뒤 Tailscale이 꺼진 것을 확인했습니다).

같은 Fold4 업데이트는 무선 디버깅도 껐습니다. Termux 스크립트로는 다시 켤 수 없습니다. `WRITE_SECURE_SETTINGS` 권한이 있어도 Android가 앱 셸의 `settings`·`content` 쓰기를 거부합니다. F-Droid에서 [KeepADB](https://f-droid.org/packages/de.hohnepeople.keepadb/)를 설치하고 Keep-Alive를 켜세요. `termux-adb install`이 권한, 알림, Wi-Fi 감지를 허용하고 `doctor`가 상태를 확인합니다. KeepADB 설정 도우미에서 Keep-Alive를 켜고 집 Wi-Fi를 신뢰하세요. Tab S8에서 무선 디버깅을 끄자 1초 안에 다시 켜졌습니다. KeepADB가 무선 디버깅을 다시 켜면, 이 도구의 watch가 포트 5555, SSH, Termux를 되살립니다.

## 용도

무선 디버깅은 Wi-Fi가 끊기면 스스로 꺼지고, adbd는 다시 시작할 때마다 **새 임의 포트**에서
듣습니다. 부팅 때 한 번 실행되는 스크립트가 `adb tcpip 5555`를 호출하고 그다음부터 포트를
계속 확인하면, 호스트는 늘 같은 주소로 접속할 수 있습니다.

문제는 그다음 절반입니다. Samsung MARs는 유휴 앱을 `DISABLED_UNTIL_USED` 상태로
비활성화하며, 이때 호출자는 `lastDisabledCaller: auto_disabler`로 남습니다. 비활성화된
Termux:Boot은 `BOOT_COMPLETED`를 받지 못하므로 재부팅 뒤에는 sshd도, 포트도, 감시
프로세스도 돌아오지 않습니다. One UI에는 Termux를 예외로 두는 화면이 없습니다. 절전
예외 목록에 없고, FAS provider는 시스템 권한을 요구합니다. 배터리 사용량을
**제한 없음(Unrestricted)** 으로 두면 두 패키지가 deviceidle 허용 목록에 들어가고, 그것이
MARs 대상 목록에서 빼냅니다. `install`이 그 일을 하고, `doctor`가 나중에 두 패키지가 다시
목록에 들어왔는지 알려 줍니다.

| | 이 도구 | [Termux:Boot](https://github.com/termux/termux-boot)만 | [wireless-adb-keeper](https://github.com/MBanucu/wireless-adb-keeper) |
|---|---|---|---|
| 호스트의 고정 포트 | `adb tcpip 5555`를 계속 유지 | 없음 | 없음, mDNS로 adbd의 임의 포트를 따라감 |
| 호스트만으로 동작 | 아니오, Termux 설정 필요 | 호스트 쪽 없음 | 아니오, 기기에서 앱 빌드 필요 |
| 비활성화된 Termux:Boot 감지 | `doctor`, `keeper` | 없음 | 없음 |
| Samsung이 비활성화한 뒤 되살림 | 예 | 없음 | 없음, 자기 앱도 같은 대상 |
| 기기에서 APK 빌드 | 필요 없음 | 필요 없음 | 필요(`openjdk-17`, `aapt`, `d8`, `android.jar`) |

## 설정

### 명령

| 명령 | 동작 |
|---|---|
| `termux-adb install [--ssh-key FILE] [--no-start] [--battery-saver] [--keep-auth-timeout] [--vpn-app PKG] [--fetch-apps]` | 기기를 설정하고 부팅 스크립트를 복사한 뒤 지금 시작하고, 이어서 `doctor`를 실행합니다. `--no-start`는 즉시 시작을 건너뜁니다. `--battery-saver`(폰용)는 wake lock 없이 300초마다 확인합니다. `--vpn-app`은 그 VPN 앱을 상시 VPN으로 지정합니다. `--fetch-apps`는 빠진 Termux, Termux:Boot, KeepADB를 내려받아 설치합니다. |
| `termux-adb doctor [--ssh-port PORT --ssh-user USER]` | 읽기 전용 점검입니다. 실패한 줄마다 고치는 방법을 한 줄로 붙입니다. `✗`가 하나라도 있으면 종료 코드 1입니다. |
| `termux-adb keeper [--ssh-port 8022] [--log FILE]` | 복구 한 회입니다. 감시 프로세스가 없거나 `--ssh-port`가 닫혀 있으면 부팅 스크립트를 시작합니다. |
| `termux-adb keeper --install [--interval 300] [--ssh-port 8022]` | N초마다 복구 한 회를 실행하는 예약 항목을 씁니다. `--device`마다 하나씩 만들어 한 PC가 태블릿과 폰을 함께 지킬 수 있습니다. 정상일 때는 기록을 남기지 않습니다. |
| `termux-adb keeper --uninstall` | 그 항목을 지웁니다. |

대상 기기는 `--device HOST:PORT`(또는 `-s SERIAL`), `TERMUX_ADB_DEVICE`, `adb devices`가
보고하는 단일 기기 순서로 정해집니다. 옵션은 명령 앞뒤 어디에나 쓸 수 있습니다.

### `install`이 기기에 하는 변경

| 단계 | 기기 쪽 결과 |
|---|---|
| `pm enable com.termux`, `pm enable com.termux.boot` | `pm list packages -d`에 있을 때만 실행합니다. |
| `cmd deviceidle whitelist +com.termux`, `+com.termux.boot` | 배터리 사용량이 제한 없음이 되고, Samsung이 두 패키지를 `mMARsTargetPackages`에서 뺍니다. |
| `am start -n com.termux.boot/.BootActivity`, 이어서 HOME | Termux:Boot이 첫 실행을 기록합니다(`notLaunched=false`). |
| `/data/local/tmp`로 push한 뒤 `run-as`로 복사 | `~/.termux/boot/boot-restore-adb.sh`, 권한 700. `run-as`가 안 되면 Termux setup 한 줄 명령을 출력합니다. |
| `--ssh-key` | 공개 키를 `~/.ssh/authorized_keys`(권한 600)에 덧붙입니다. 이미 있으면 건너뜁니다. |
| 시작 | `run-as com.termux … setsid nohup bash .termux/boot/boot-restore-adb.sh`. keeper가 쓰는 호출과 같습니다. |

### 기기 스크립트

`boot-restore-adb.sh`는 부팅 때 `~/.termux/boot/`에서 실행됩니다. 절전 잠금을 잡고,
`sshd`가 있으면 시작하고, 포트를 한 번 복구한 뒤 60초마다 확인하며, Android가 무선
디버깅을 껐으면 다시 켭니다. 감시 프로세스는 기기마다 하나입니다.
`~/.termux/boot-restore-adb.watch.pid`에 PID가 있고, 두 번째 `--watch` 실행은 종료 코드
0으로 끝납니다.

| 설정 | 기본값 | 동작 |
|---|---|---|
| `ADB_RESTORE_PORT` | 5555 | 복구하고 감시할 포트입니다. |
| `ADB_RESTORE_WAKE_LOCK` | 1 | `0`이면 Termux wake lock을 잡지 않습니다(`--battery-saver`가 설정). |
| `ADB_RESTORE_WATCH_INTERVAL` | 60 | 부팅 후 감시 간격(초)입니다(`--battery-saver`면 300). |
| `ADB_RESTORE_LOG` | `~/.termux/boot.log` | 로그 경로입니다. |
| `ADB_RESTORE_VPN_APP` | 없음 | 상시 연결 VPN 앱의 패키지 이름입니다. |
| `ADB_RESTORE_VPN_LOCKDOWN` | 없음 | `0` 또는 `1`. VPN 패키지가 필요합니다. |

`bash boot-restore-adb.sh --once`는 한 번 복구하고 끝나며, `--watch [SECONDS]`는 감시만
합니다. `--version`은 `boot-restore-adb.sh 0.3.0`을 출력합니다.

### 호스트 환경 변수

| 변수 | 기본값 | 동작 |
|---|---|---|
| `TERMUX_ADB_DEVICE` | 없음 | `--device`와 같습니다. |
| `ADB` | `PATH`의 `adb` | 호출할 adb 실행 파일입니다. |
| `TERMUX_ADB_LOG` | `~/.local/state/termux-adb-keeper.log` | keeper 로그입니다. `--log`가 이깁니다. |

종료 코드는 `0` 정상, `1` 점검 실패 또는 기기 연결 불가, `2` 잘못된 사용법입니다.

## 제한

두 기기에서 확인했습니다: Samsung Galaxy Tab S8(SM-X900)과 Galaxy Z Fold4(SM-F936N,
`--battery-saver`), 둘 다 Android 16, Termux 0.118.3, Termux:Boot 0.8.1입니다. `install`,
`doctor`, `keeper`는 Apple Silicon Mac의 macOS 26에서 실행했습니다. 0.2.0으로 Tab S8을
재부팅하자 손대지 않아도 sshd가 80초, 5555 포트가 111초 만에 돌아왔고 감시는 하나만 떴습니다.
폰 재부팅과 Linux 예약 항목은 실행해 보지 않았습니다. Windows 호스트는 지원하지 않습니다.

복구에는 기기의 승인된 ADB 페어링과 부팅 후 쓸 수 있는 무선 디버깅이 필요합니다.
`run-as`는 디버그 가능한 Termux 빌드가 필요합니다. F-Droid 빌드에서는 setup과 SSH 진단을 사용하세요. Samsung의 `dumpsys activity mars`는 제조사 전용이라
`ro.product.manufacturer`가 `samsung`일 때만 확인합니다. 제조사 업데이트가 출력을 바꾸면
`doctor`는 목록을 점검하지 못했다고 알리고 추측하지 않습니다.

[기여 안내](CONTRIBUTING.md) · [MIT 라이선스](LICENSE)

Termux, Samsung, Google과 별개인 프로젝트입니다.
