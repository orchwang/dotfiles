# NVChad Configuration Guide

이 디렉터리는 개인 `dotfiles`에서 사용하는 NVChad 설정 전체를 관리합니다.

## 1. Quick Start

1. `nvim`을 실행하면 `lazy.nvim`이 자동으로 플러그인을 동기화합니다.
2. 최초 실행 후 아래 명령으로 상태를 확인합니다.
   - `:Lazy` (플러그인 상태)
   - `:Mason` (LSP/DAP 도구 설치 상태)
   - `:checkhealth` (환경 점검)
3. 키맵 변경/플러그인 변경 뒤에는 `:Lazy sync` 후 Neovim 재시작을 권장합니다.
4. `make install`/`make install-nvchad`는 `set-nvim-tools` 단계에서 `MasonToolsInstallSync`를 실행해
   필수 LSP/DAP/Linter/Formatter 도구를 기본 설치합니다.

## 2. 구성 구조

```
nvim/
├── init.lua
├── lazy-lock.json
└── lua/
    ├── chadrc.lua
    ├── options.lua
    ├── mappings.lua
    ├── autocmds.lua
    ├── configs/
    │   ├── lazy.lua
    │   ├── lspconfig.lua
    │   ├── conform.lua
    │   └── dap.lua
    └── plugins/
        └── init.lua
```

핵심 파일 역할:
- `init.lua`: lazy bootstrap + NvChad 로딩 진입점
- `lua/chadrc.lua`: 테마/Ui 관련 설정
- `lua/options.lua`: 기본 editor option 오버라이드
- `lua/mappings.lua`: 커스텀 키맵
- `lua/plugins/init.lua`: 추가 플러그인 선언
- `lua/configs/*.lua`: 플러그인 세부 설정

## 3. NVChad 기본 사용법

자주 쓰는 흐름:
- 파일 탐색: `<leader>e` (`nvim-tree`)
- 파일 검색: `<leader>ff` (`telescope`)
- 문자열 검색: `<leader>fg` (`telescope live grep`)
- LSP 코드 액션/정의 이동: 기본 NvChad LSP 키맵 사용

현재 커스텀 키맵:
- `;` -> `:`
- insert 모드 `jk` -> `<ESC>`
- `s`, `S`, `gw`: `hop.nvim` 기반 이동
- `<leader>cv`: Python 가상환경 선택 (`venv-selector.nvim`)

커스터마이징 원칙:
- 플러그인 추가/변경: `lua/plugins/init.lua`
- 플러그인 상세 동작: `lua/configs/<plugin>.lua`
- 전역 키맵: `lua/mappings.lua`

## 4. LSP / Formatter 설정

### 4.1 LSP 서버

정의 위치: `lua/configs/lspconfig.lua`

| 언어 | LSP 서버 | 설치 방식 |
|------|----------|-----------|
| HTML | `html` | Mason |
| CSS | `cssls` | Mason |
| Python | `pyright` | Mason |
| Python (lint) | `ruff` | 시스템 (Homebrew / uv) |
| Rust | `rust_analyzer` | Mason |
| Go | `gopls` | Mason (Go 설치 시) |
| JS/TS | `ts_ls` | Mason |
| Markdown | `marksman` | Mason |

### 4.2 포매터 (format-on-save)

정의 위치: `lua/configs/conform.lua`

| 언어 | 포매터 |
|------|--------|
| Lua | `stylua` |
| Python | `ruff_format` |
| JS/JSX/TS/TSX | `prettier` |
| JSON | `prettier` |
| Markdown | `prettier` |
| Go | `goimports` + `gofumpt` |
| Rust | `rustfmt` |

저장 시 자동 포맷(`format_on_save`)이 활성화되어 있으며, 타임아웃은 500ms입니다.

## 5. Plugin / Tooling 관리

- 플러그인 매니저: `lazy.nvim`
- 버전 고정: `lazy-lock.json`
- 도구 설치: `mason-tool-installer.nvim` (`run_on_start = false`, headless 모드 전용)

### 5.1 추가 플러그인

| 플러그인 | 용도 | 로딩 조건 |
|----------|------|-----------|
| `hop.nvim` | 빠른 커서 이동 | 항시 |
| `venv-selector.nvim` | Python venv 선택 (Telescope 피커) | `ft = python` / `<leader>cv` |
| `render-markdown.nvim` | Markdown 리치 프리뷰 | `ft = markdown` |
| `image.nvim` | 이미지 인라인 렌더링 (Kitty backend) | `ft = markdown` |
| `diagram.nvim` | Mermaid 다이어그램 인라인 렌더링 | `ft = markdown` |

### 5.2 Telescope 커스텀 설정

- `find_files`: 숨김 파일 포함, `.gitignore` 무시 (`no_ignore = true`, `hidden = true`)
- `live_grep`: 숨김 파일 포함, `.gitignore` 무시 (`--no-ignore-vcs`, `--hidden`)

### 5.3 nvim-tree 커스텀 설정

- `.gitignore`에 포함된 파일도 표시 (`git_ignored = false`)

### 5.4 업데이트 절차

1. `:Lazy sync`
2. `:Mason`에서 필요한 도구 설치 확인
3. `:checkhealth`
4. 정상 동작 확인 후 `lazy-lock.json` 커밋

수동 재설치:
- `make set-nvim-tools`
- 또는 Neovim에서 `:MasonToolsInstallSync`

### 5.5 Linux 설치 원칙 (No Brew)

- Linux/Ubuntu는 Homebrew를 전제로 하지 않습니다.
- 기본 경로는 `apt + 공식 설치 스크립트`이며, `make install` 또는 `make install-nvchad`로 동일하게 적용됩니다.
- JS/TS 계열 Mason 도구를 위해 `nodejs`, `npm`이 Linux 기본 패키지에 포함됩니다.
- Go 계열 Mason 도구(`gopls`, `goimports`, `gofumpt`, `delve`)를 위해 `golang-go`가 Linux 기본 패키지에 포함됩니다.
- Python DAP adapter(`debugpy.adapter`)는 `uv`로 온디맨드 실행됩니다.
- `set-nvim-tools`는 `PATH`의 `nvim`이 없을 때 `~/.local/bin/nvim`을 fallback으로 사용합니다.

## 6. Python 개발 환경

- LSP: `pyright` (타입 검사) + `ruff` (린팅)
- 포매터: `ruff_format` (format-on-save)
- 디버거: `debugpy` (`uv run --with debugpy` 우선, Mason fallback)
- 가상환경: `venv-selector.nvim`으로 `.venv` 선택
  - 프로젝트 루트의 `.venv/`는 Pyright가 자동 감지
  - `<leader>cv`로 수동 선택 가능
  - 선택한 venv는 프로젝트별 캐시 및 자동 복원

## 7. Debugging (nvim-dap)

이 설정은 `launch.json`을 읽지 않고, Lua 기반 `dap.configurations`를 표준으로 사용합니다.

### 7.1 Debugging 스택

- `mfussenegger/nvim-dap`
- `rcarriga/nvim-dap-ui`
- `theHamsta/nvim-dap-virtual-text`
- `jay-babu/mason-nvim-dap.nvim`
- `mxsdev/nvim-dap-vscode-js`
- `WhoIsSethDaniel/mason-tool-installer.nvim` (`js-debug-adapter` 설치용)

### 7.2 지원 언어

- Python (`debugpy`)
- JavaScript (`pwa-node`, `js-debug-adapter`)
- TypeScript (`pwa-node`, `js-debug-adapter`)
- Go (`delve`)
- Rust (`codelldb`)

### 7.3 기본 디버그 키맵

로딩 방식:
- DAP는 lazy-load이며 아래 키 입력 또는 DAP 명령 실행 시 로드됨
- cold start에서도 `:DapReloadProjectConfig` 실행으로 플러그인 로드 + 명령 실행 가능
- `launch.json` 로딩은 비활성화되어 있으며, 프로젝트 설정은 `.nvim/dap.lua`/`.nvim/dap.local.lua`만 사용

- `<F5>`: 시작/계속
- `<F9>`: 브레이크포인트 토글
- `<F10>`: Step Over
- `<F11>`: Step Into
- `<F12>`: Step Out
- `<leader>dB`: 조건부 브레이크포인트
- `<leader>dl`: 로그 포인트
- `<leader>dr`: DAP REPL 열기
- `<leader>du`: DAP UI 토글

세션 동작:
- 디버그 시작 시 `dap-ui` 자동 open
- 디버그 종료/exit 시 `dap-ui` 자동 close

### 7.4 언어별 기본 Launch 구성

정의 위치: `lua/configs/dap.lua`

- Python
  - 현재 파일 실행
  - 모듈 이름 입력 후 실행
- JavaScript / TypeScript
  - 현재 파일 launch
  - 실행 중 프로세스 attach
- Go
  - 패키지 실행 (`${workspaceFolder}`)
  - 현재 파일 실행
- Rust
  - 실행 바이너리 경로 입력 후 launch

### 7.5 프로젝트별 DAP 설정

프로젝트 루트(`.git` 기준)에서 아래 파일을 자동 로드합니다.

- `<project>/.nvim/dap.lua` (팀 공유)
- `<project>/.nvim/dap.local.lua` (개인 오버라이드)

자동 동작:
- Neovim 시작 시 현재 프로젝트 오버레이 로드
- `:cd` / `:tcd`로 작업 디렉터리 변경 시 오버레이 재로딩
- 수동 재로딩 명령: `:DapReloadProjectConfig`

로드 순서:
1. 전역 기본 설정 (`lua/configs/dap.lua`)
2. 프로젝트 공유 설정 (`.nvim/dap.lua`)
3. 개인 설정 (`.nvim/dap.local.lua`)

`dap.local.lua`는 개인 환경용으로 `.gitignore` 처리 권장.

프로젝트 예시 (`.nvim/dap.lua`):

```lua
return {
  configurations = {
    python = {
      {
        type = "python",
        request = "launch",
        name = "API server",
        module = "uvicorn",
        args = { "app.main:app", "--reload" },
        cwd = "${workspaceFolder}",
      },
    },
    typescript = {
      {
        type = "pwa-node",
        request = "launch",
        name = "TS app",
        runtimeExecutable = "pnpm",
        runtimeArgs = { "tsx", "src/index.ts" },
        cwd = "${workspaceFolder}",
      },
    },
  },
}
```

### 7.6 Debugging 검증 체크리스트

1. 대상 파일에서 브레이크포인트(`F9`) 설정
2. `F5`로 디버그 시작
3. 변수/스택/콘솔이 `dap-ui`에 표시되는지 확인
4. `F10/F11/F12` step 동작 확인
5. 종료 시 `dap-ui` 자동 닫힘 확인

### 7.7 현재 범위와 Future Feature

현재 범위:
- 애플리케이션/스크립트 단위 디버깅

Future Feature:
- Python test case 단위 디버깅 (`neotest` + DAP 전략)

## 8. 트러블슈팅

- JS/TS 디버깅이 안 열리면:
  - `node --version`, `npm --version` 확인 (Linux 필수 런타임)
  - `:Mason`에서 `js-debug-adapter` 설치 여부 확인
  - 필요 시 `:MasonInstall js-debug-adapter`
- Python 디버깅이 안 열리면:
  - `uv --version` 확인
  - 수동 확인: `uv run --with debugpy python -m debugpy.adapter --help`
  - 설치 실패 로그 확인: `~/.local/state/nvim/mason.log`
- Go/Rust 디버깅이 안 열리면:
  - `dlv`, `codelldb` 설치 여부 확인 (`:Mason`)
- `delve: installing`에서 오래 멈추면:
  - `go version` 확인 (`go`가 없으면 Go 계열 Mason 설치는 skip되거나 실패할 수 있음)
  - 로그 확인: `~/.local/state/nvim/mason.log`
  - 단독 재시도: `:MasonInstall delve`
