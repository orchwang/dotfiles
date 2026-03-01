# NVChad: `nvim-dap` 기반 디버거 도입 계획 (Draft)

## 배경

- 현재 `nvim/` 설정에는 디버깅 스택이 없다.
- 목표는 VSCode 연동(`launch.json`) 없이 `nvim-dap` 표준 방식으로 디버깅을 도입하는 것이다.
- 커버 범위는 Python, JavaScript, TypeScript, Go, Rust 5개 언어다.
- 핵심 원칙:
  - 디버그 설정의 단일 진입점은 Lua (`require("dap").configurations`)
  - `.vscode/launch.json` 읽기 기능은 사용하지 않음

---

## 범위

### 포함

- `nvim-dap` 기본 엔진
- `nvim-dap-ui` (변수/스택/REPL 보조 UI)
- `nvim-dap-virtual-text` (인라인 변수 값)
- `mason-nvim-dap` (Python/Go/Rust 어댑터 설치 자동화)
- `mxsdev/nvim-dap-vscode-js` (`vscode-js-debug` 연동, JS/TS 지원)
- 표준 디버그 키맵 (`F5/F9/F10/F11/F12`)
- 세션 시작/종료 시 `dap-ui` 자동 open/close
- 애플리케이션/스크립트 실행 단위 디버깅 (`program`, `module`, `attach`)
- 프로젝트별 DAP 오버레이 로딩 (`<project>/.nvim/dap.lua`)
- 개인 전용 프로젝트 오버라이드 (`<project>/.nvim/dap.local.lua`)

### 제외

- `dap.ext.vscode.load_launchjs()` 사용
- `.vscode/launch.json` 의존 워크플로우
- 테스트 익스플로러/테스트케이스 단위 디버깅 기본 포함
- 프로젝트 외부 임의 경로 DAP 파일 자동 실행

---

## 대상 파일 (예정)

- 수정: `nvim/lua/plugins/init.lua`
- 생성(권장): `nvim/lua/configs/dap.lua`
- 수정(선택): `nvim/lua/mappings.lua`
  (키맵을 중앙 관리할지 `dap.lua` 내부에 둘지 결정)
- 생성(필수): `nvim/README.md` (NVChad 사용법 + 설정 구조 + 디버깅 가이드)

---

## 구현 단계 초안

## 1) 플러그인 스택 등록

- `nvim/lua/plugins/init.lua`에 다음 플러그인 추가:
  - `mfussenegger/nvim-dap`
  - `rcarriga/nvim-dap-ui`
  - `nvim-neotest/nvim-nio`
  - `theHamsta/nvim-dap-virtual-text`
  - `jay-babu/mason-nvim-dap.nvim`
  - `mxsdev/nvim-dap-vscode-js`
- 초기 설정은 `require("configs.dap")`로 위임해 파일 책임 분리

## 2) 공통 DAP 설정 작성 (`configs/dap.lua`)

- `dap-ui` / `virtual-text` 초기화
- 이벤트 리스너 설정:
  - `event_initialized` -> UI open
  - `event_terminated`, `event_exited` -> UI close
- 기본 명령 매핑:
  - `<F5>` continue/start
  - `<F9>` toggle breakpoint
  - `<F10>` step over
  - `<F11>` step into
  - `<F12>` step out
  - `<leader>dB>` 조건부 브레이크포인트
  - `<leader>dl>` 로그포인트
  - `<leader>dr>` REPL
  - `<leader>du>` UI 토글

## 3) 프로젝트별 DAP 설정 로더 추가

- `configs/dap.lua`에 프로젝트 루트 탐색 로직 추가 (`.git` 기준)
- 아래 파일을 순서대로 로드:
  - `<project>/.nvim/dap.lua` (팀 공유)
  - `<project>/.nvim/dap.local.lua` (개인 오버라이드)
- merge 정책:
  - 전역 기본 `dap.configurations`를 먼저 로드
  - 프로젝트 설정은 filetype 단위 append
  - 필요 시 `name` 기준 dedupe로 중복 launch 방지
- 안전장치:
  - 루트 외 경로는 로드하지 않음
  - 파일이 table을 반환하지 않으면 무시
  - 로딩 실패 시 `vim.notify` 경고만 출력하고 계속 진행

## 4) 언어별 어댑터/구성 정의

- Python
  - adapter: `debugpy`
  - config: 현재 파일 실행, 모듈 실행(선택) 2종
- JavaScript / TypeScript
  - adapter backend: `vscode-js-debug` (`js-debug-adapter`)
  - Neovim 연동: `nvim-dap-vscode-js`
  - config: Node 현재 파일 launch + 프로세스 attach
  - filetypes: `javascript`, `javascriptreact`, `typescript`, `typescriptreact`
- Go
  - adapter: `delve`
  - config: 현재 파일/패키지 launch
- Rust
  - adapter: `codelldb`
  - config: 빌드된 바이너리 launch (program path 선택 함수 포함)

## 5) 설치 자동화 연결

- `mason-nvim-dap` `ensure_installed`:
  - `python`, `delve`, `codelldb`
- JS/TS용 `js-debug-adapter`는 `:Mason`으로 설치 자동화
  - 필요 시 추후 `mason-tool-installer.nvim`로 완전 자동화
- 어댑터 설치 상태를 `:Mason`에서 확인 가능하도록 문서화

## 6) 검증 (언어별 Smoke Test + 프로젝트 오버레이)

1. Python: 브레이크포인트 -> `F5` -> step 동작 확인
2. JavaScript: Node 스크립트 launch/attach 확인
3. TypeScript: `ts-node` 또는 빌드 산출물 기준 launch 확인
4. Go: `main.go` launch 및 변수 확인
5. Rust: 바이너리 launch 및 브레이크포인트 hit 확인
6. 공통: 세션 시작 시 `dap-ui` open, 종료 시 close 확인
7. 프로젝트 루트에 `.nvim/dap.lua` 추가 후 custom launch 항목이 목록에 나타나는지 확인
8. `.nvim/dap.local.lua`로 개인 설정이 append되는지 확인
9. 프로젝트 외부 경로의 DAP 파일이 로드되지 않는지 확인
10. 회귀: 기존 `hop`, `telescope`, NVChad 기본 키맵 충돌 여부 점검

---

## 7) 문서화 (`nvim/README.md`)

- 아래 내용을 포함해 `nvim/README.md` 신규 작성:
  - NVChad 기본 사용법
  - 현재 `nvim/` 디렉터리 구조와 각 파일 역할
  - 플러그인 관리/동기화 방식 (`lazy.nvim`, lockfile)
  - 키맵 커스터마이징 위치 (`lua/mappings.lua`)와 적용 방법
  - 디버깅 설정 구조(`configs/dap.lua`) 및 동작 흐름
  - 언어별 디버깅 지원 범위 (Python/JS/TS/Go/Rust)
  - 프로젝트별 DAP 설정 파일 규칙 (`.nvim/dap.lua`, `.nvim/dap.local.lua`)
  - 대표 실행 예시 (launch/attach/conditional breakpoint)
- 문서 톤:
  - 신규 사용자도 따라할 수 있는 quick start 우선
  - 유지보수 관점에서 변경 지점(어디를 수정해야 하는지) 명확히 표기

---

## Future Feature

- Python 테스트케이스 디버깅 (`pytest` + 단일 test function 선택 실행)
- 테스트 트리/익스플로러 UX (`neotest` + `neotest-python`)
- 테스트 실행 전략에서 `strategy = "dap"` 표준화
- 테스트 결과 패널/요약 뷰를 NVChad 워크플로우에 맞게 키맵 통합

---

## 의사결정 포인트

- 키맵 위치: `mappings.lua` vs `configs/dap.lua`
- 프로젝트 루트 탐색 기준: `.git` 단일 기준 vs `package.json`/`pyproject.toml` 보조 기준
- JS/TS 실행 전략: 런타임 직접 실행 vs 빌드 산출물 디버깅
- Rust 실행 전략: 바이너리 선택 프롬프트 vs 고정 경로
- launch dedupe 전략: 단순 append vs `name`/`type` 기준 중복 제거
- 브레이크포인트 영속화(`persistent-breakpoints.nvim`) 도입 여부
- 테스트 디버깅 계층(`neotest`, `nvim-dap-python`) 도입 시점

---

## 완료 기준 (Definition of Done)

- `nvim` 실행 후 디버그 키맵이 유효하다.
- Python/JavaScript/TypeScript/Go/Rust에서 최소 1개 launch 구성이 동작한다.
- 브레이크포인트/스텝/변수 확인이 5개 언어에서 재현된다.
- 프로젝트별 `.nvim/dap.lua` 설정이 전역 설정 위에 정상 merge된다.
- `.nvim/dap.local.lua`를 통해 개인 설정을 팀 설정과 분리해 유지할 수 있다.
- 설정이 `launch.json` 없이 Lua 표준(`dap.configurations`)만으로 유지된다.
- `nvim/README.md`가 생성되고, NVChad 기본 사용법과 디버깅 가이드가 포함된다.
