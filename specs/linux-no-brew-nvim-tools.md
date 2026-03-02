# Linux (No Brew) 환경 대응 계획

## 배경

- Linux/Ubuntu에서는 Homebrew를 사용하지 않고 `apt + 공식 설치 스크립트`만 사용한다.
- 현재 디버깅 자동 설치(`set-nvim-tools` + `MasonToolsInstallSync`)는 Linux에서 일부 의존성 누락 가능성이 있다.
- 목표는 Linux 기본 설치 흐름만으로 NVChad + LSP/DAP/Linter/Formatter가 재현 가능하도록 정리하는 것이다.

## 목표

- Linux 설치 경로에서 brew 의존 제거/비권장 원칙을 명시한다.
- Ubuntu에서 DAP 관련 필수 도구(Python/JS/TS/Go/Rust)가 자동 설치되도록 보장한다.
- x86_64 외 Linux 아키텍처에서도 Neovim 설치 실패 가능성을 줄인다.

## 범위

### 포함

- `Makefile` Linux 설치 체인 보강
- `packages/apt-packages.txt` 의존성 보강 (`nodejs`, `npm` 등)
- `set-nvim-tools` 실행 경로 보강 (`nvim` PATH fallback)
- Linux용 문서 업데이트 (`nvim/README.md`, 필요 시 루트 README)
- Ubuntu 기준 검증 절차 문서화

### 제외

- Linuxbrew/Homebrew 기반 Linux 설치 경로 추가
- macOS 설치 체인 변경
- 테스트 디버깅 기능 확장 (`neotest` 등)

## 구현 계획

1. Linux 패키지 의존성 확정
- `packages/apt-packages.txt`에 JS/TS tooling 설치에 필요한 최소 런타임을 추가한다.
- 우선순위: `nodejs`, `npm`.

2. Neovim Linux 설치 안정화
- `set-neovim`에서 `uname -m` 기반으로 아키텍처별 tarball 이름을 분기한다.
- 지원 후보: `x86_64`, `aarch64` (미지원 아키텍처는 명시적 에러).

3. Mason 자동 설치 실행 안정화
- `set-nvim-tools`에서 `command -v nvim` 실패 시 `~/.local/bin/nvim` fallback으로 실행한다.
- headless 실행 실패 시 원인 메시지를 명확히 출력한다.

4. Linux 전용 원칙 문서화
- Linux 환경에서는 brew를 전제하지 않는다는 원칙을 README에 명시한다.
- DAP 관련 자동 설치 흐름(`make install[-nvchad]` -> `set-nvim-tools`)을 Linux 기준으로 예시화한다.

5. 검증
- `make -n install OS=Linux`로 체인 확인
- Ubuntu에서 `make set-nvim-tools` 실행 후 Mason 설치 상태 확인:
  - `debugpy`, `delve`, `codelldb`, `js-debug-adapter`
  - `pyright`, `gopls`, `typescript-language-server`
  - `eslint_d`, `prettier`, `goimports`, `gofumpt`, `rustfmt`, `stylua`

## 완료 기준 (DoD)

- Linux 설치 경로에서 brew 없이 DAP/LSP/Linter/Formatter 자동 설치가 동작한다.
- Ubuntu에서 Python/JS/TS/Go/Rust 디버깅 최소 1개 launch 구성이 실행된다.
- 문서에 Linux 설치 원칙과 디버깅 도구 설치 흐름이 반영된다.
