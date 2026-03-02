# NVChad: Python 테스트 실행/디버깅 환경 도입 계획

## 배경

- `nvim-dap` 기반 멀티언어 디버거가 이미 구성되어 있다 (`configs/dap.lua`).
- 현재 Python 디버깅은 "현재 파일 실행", "모듈 실행" 2종의 launch 설정만 존재한다.
- **pytest 테스트 함수/클래스 단위 디버깅**이 불가능하다.
- 목표: 커서를 테스트 함수 위에 놓고 키 하나로 해당 테스트만 디버거 아래 실행한다.

### 선행 작업 (완료)

- `specs/add-debugger-to-nvchad.md` — nvim-dap 기반 디버거 설계 및 구현 완료
- `nvim/lua/configs/dap.lua` — 어댑터/키맵/프로젝트 오버레이 구현 완료
- `mason-nvim-dap` — debugpy, delve, codelldb 자동 설치 구성 완료

---

## 범위

### 포함

- `nvim-dap-python` — Python 전용 DAP 확장 (테스트 디버깅, venv 자동 감지)
- `neotest` + `neotest-python` — 테스트 실행 프레임워크 + UI (summary, inline 결과, watch)
- mason-nvim-dap Python handler 충돌 해소
- `configs/dap.lua`에서 수동 Python 어댑터 설정 제거 (nvim-dap-python이 대체)

### 제외

- Python 이외 언어의 테스트 프레임워크 (Go test, Rust test 등은 추후)
- `neotest` 기반 다른 언어 어댑터
- `.vscode/launch.json` 연동

---

## 현재 상태 분석

### 충돌 지점: mason-nvim-dap `handlers = {}`

현재 `plugins/init.lua:29`:

```lua
handlers = {},
```

`handlers = {}` 는 mason-nvim-dap의 **default handler**가 모든 어댑터를 등록한다는 의미다.
Python의 경우 `dap.adapters.python`을 static executable 테이블로 설정한다.

`nvim-dap-python`은 `dap.adapters.python`을 **function** 타입으로 등록하며,
`enrich_config` 콜백으로 venv의 `pythonPath`를 동적 해석한다.

**두 설정이 충돌**하므로 mason-nvim-dap의 Python handler를 no-op으로 오버라이드해야 한다.

### 제거 대상: `configs/dap.lua` 수동 Python 설정

- `setup_adapters()` 내 `dap.adapters.python` 등록 (lines 124-134)
- `setup_base_configurations()` 내 Python launch 설정 (lines 218-241)

이들은 `nvim-dap-python`의 `setup()`이 대체한다.

---

## 대상 파일

| 파일 | 작업 |
|---|---|
| `nvim/lua/plugins/init.lua` | nvim-dap-python, neotest, neotest-python 플러그인 추가; mason-nvim-dap handler 수정 |
| `nvim/lua/configs/dap.lua` | Python 어댑터/launch 설정 제거 (nvim-dap-python이 관리) |
| `nvim/README.md` | 테스트 디버깅 키맵 및 워크플로우 문서 추가 |

---

## 구현 단계

### 1) nvim-dap-python 플러그인 추가

`plugins/init.lua`에 추가:

```lua
{
  "mfussenegger/nvim-dap-python",
  ft = "python",
  dependencies = { "mfussenegger/nvim-dap" },
  keys = {
    {
      "<leader>dPt",
      function() require("dap-python").test_method() end,
      desc = "Debug: test method",
      ft = "python",
    },
    {
      "<leader>dPc",
      function() require("dap-python").test_class() end,
      desc = "Debug: test class",
      ft = "python",
    },
    {
      "<leader>dPs",
      function() require("dap-python").debug_selection() end,
      desc = "Debug: selection",
      mode = "v",
      ft = "python",
    },
  },
  config = function()
    local debugpy_python = vim.fn.stdpath("data")
      .. "/mason/packages/debugpy/venv/bin/python"
    require("dap-python").setup(debugpy_python)
    require("dap-python").test_runner = "pytest"
  end,
},
```

**핵심 동작:**
- `test_method()`: Tree-sitter로 커서 위치의 테스트 함수를 찾아 `pytest -s path::Class::method` 형태로 DAP 실행
- `test_class()`: 커서가 속한 클래스의 모든 테스트를 DAP 실행
- `setup(debugpy_python)`: `dap.adapters.python`을 function 타입으로 등록 + `enrich_config`으로 venv `pythonPath` 자동 해석

### 2) mason-nvim-dap Python handler 충돌 해소

`plugins/init.lua`의 mason-nvim-dap 설정 변경:

```lua
-- 변경 전
handlers = {},

-- 변경 후
handlers = {
  function(config)
    require("mason-nvim-dap").default_setup(config)
  end,
  python = function() end,  -- nvim-dap-python이 관리
},
```

### 3) `configs/dap.lua` Python 수동 설정 제거

**`setup_adapters()`에서 제거:**

```lua
-- 제거: debugpy_python 변수 및 dap.adapters.python 등록
local debugpy_python = resolve_executable { ... }
dap.adapters.python = { ... }
```

**`setup_base_configurations()`에서 제거:**

```lua
-- 제거: Python launch 설정 (현재 파일 실행, 모듈 실행)
local python = { ... }
append_unique_configurations("python", python)
```

nvim-dap-python이 다음 기본 설정을 자동 등록한다:
- Launch file
- Launch file with arguments
- Attach remote
- Run doctests in file

### 4) neotest + neotest-python 플러그인 추가

`plugins/init.lua`에 추가:

```lua
{
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-python",
    "mfussenegger/nvim-dap-python",  -- DAP strategy 사용 시 어댑터 필요
  },
  keys = {
    {
      "<leader>tn",
      function() require("neotest").run.run() end,
      desc = "Test: run nearest",
    },
    {
      "<leader>tf",
      function() require("neotest").run.run(vim.fn.expand("%")) end,
      desc = "Test: run file",
    },
    {
      "<leader>td",
      function() require("neotest").run.run({ strategy = "dap" }) end,
      desc = "Test: debug nearest",
    },
    {
      "<leader>tl",
      function() require("neotest").run.run_last() end,
      desc = "Test: run last",
    },
    {
      "<leader>tL",
      function() require("neotest").run.run_last({ strategy = "dap" }) end,
      desc = "Test: debug last",
    },
    {
      "<leader>ts",
      function() require("neotest").summary.toggle() end,
      desc = "Test: toggle summary",
    },
    {
      "<leader>to",
      function() require("neotest").output.open({ enter = true }) end,
      desc = "Test: show output",
    },
    {
      "<leader>tp",
      function() require("neotest").output_panel.toggle() end,
      desc = "Test: toggle output panel",
    },
    {
      "<leader>tS",
      function() require("neotest").run.stop() end,
      desc = "Test: stop",
    },
    {
      "<leader>tw",
      function() require("neotest").watch.toggle(vim.fn.expand("%")) end,
      desc = "Test: watch file",
    },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-python")({
          runner = "pytest",
          args = { "--tb=short", "-q" },
          dap = {
            justMyCode = false,
            console = "integratedTerminal",
          },
        }),
      },
      status = { enabled = true, signs = true, virtual_text = false },
      diagnostic = { enabled = true, severity = vim.diagnostic.severity.ERROR },
      output = { enabled = true, open_on_run = false },
    })
  end,
},
```

### 5) 문서 업데이트 (`nvim/README.md`)

디버깅 가이드 섹션에 추가:
- 테스트 디버깅 키맵 (`<leader>dPt`, `<leader>dPc`)
- neotest 키맵 (`<leader>t*` 시리즈)
- DAP strategy 동작 흐름 설명
- venv 자동 감지 동작 설명

---

## 키맵 요약

### nvim-dap-python (디버깅 전용)

| 키맵 | 동작 | 조건 |
|---|---|---|
| `<leader>dPt` | 커서 위치 테스트 함수 디버깅 | Python 파일 |
| `<leader>dPc` | 커서 위치 테스트 클래스 디버깅 | Python 파일 |
| `<leader>dPs` | 선택 영역 디버깅 | Visual mode, Python 파일 |

### neotest (실행 + 디버깅 + UI)

| 키맵 | 동작 |
|---|---|
| `<leader>tn` | 가장 가까운 테스트 실행 |
| `<leader>tf` | 현재 파일 전체 테스트 실행 |
| `<leader>td` | 가장 가까운 테스트 DAP 디버깅 |
| `<leader>tl` | 마지막 테스트 재실행 |
| `<leader>tL` | 마지막 테스트 DAP 재디버깅 |
| `<leader>ts` | Summary 패널 토글 |
| `<leader>to` | 테스트 출력 보기 |
| `<leader>tp` | Output 패널 토글 |
| `<leader>tS` | 테스트 중지 |
| `<leader>tw` | 파일 Watch 모드 토글 |

---

## Virtual Environment 자동 감지

### nvim-dap-python의 `pythonPath` 해석 순서

1. DAP config에 `pythonPath`가 명시된 경우 → 그대로 사용
2. `VIRTUAL_ENV` 환경 변수
3. `CONDA_PREFIX` 환경 변수
4. 워크스페이스 내 `venv/`, `.venv/`, `env/` 디렉터리
5. `setup()`에 전달한 Python 경로 (Mason debugpy)

### uv 프로젝트 대응

uv 기반 프로젝트에서는 `setup("uv")` 로 설정하면 `uv run --with debugpy` 방식으로 동작한다.
현재는 Mason debugpy를 기본으로 사용하되, 프로젝트별로 `.nvim/dap.lua`에서 오버라이드 가능하다.

### neotest-python의 Python 해석

`python` 옵션을 생략하면 자동으로 `.venv/`, `venv/` 등을 탐색한다.
두 플러그인의 해석은 **독립적**이나, 같은 프로젝트에서는 동일한 venv을 찾게 된다.

---

## 검증

1. Python 테스트 파일에서 `<leader>dPt` → 해당 테스트만 디버거 아래 실행되는지 확인
2. `<leader>dPc` → 클래스 내 모든 테스트가 디버거 아래 실행되는지 확인
3. `<leader>tn` → pytest로 가장 가까운 테스트가 실행되는지 확인
4. `<leader>td` → DAP strategy로 테스트가 디버거 아래 실행되는지 확인
5. `<leader>ts` → Summary 패널에 테스트 결과 트리가 표시되는지 확인
6. 브레이크포인트 설정 후 테스트 디버깅 시 해당 지점에서 정지하는지 확인
7. venv 프로젝트에서 `pythonPath`가 올바르게 해석되는지 확인
8. 기존 DAP 키맵 (`F5/F9/F10/F11/F12`)과 충돌 없는지 확인
9. Go, Rust, JS/TS 디버깅이 회귀 없이 동작하는지 확인

---

## 의사결정 포인트

- nvim-dap-python 단독 vs neotest 병행: **병행 채택** (디버깅 + 실행 UI 모두 필요)
- debugpy 경로: Mason 기본 vs `uv` 모드 → **Mason 기본, 프로젝트별 오버라이드 가능**
- neotest-python runner: `pytest` 고정 vs 자동 감지 → **`pytest` 고정** (표준화)
- `<leader>dP` vs `<leader>dt` 키맵 네임스페이스 → **`<leader>dP`** (DAP 그룹 내 Python)

---

## 완료 기준 (Definition of Done)

- Python 테스트 파일에서 커서 위치 테스트 함수를 단일 키로 디버깅할 수 있다.
- neotest Summary 패널에서 테스트 결과를 확인할 수 있다.
- DAP strategy로 테스트 실행 시 브레이크포인트가 동작한다.
- mason-nvim-dap과 nvim-dap-python 간 어댑터 충돌이 없다.
- 기존 Go/Rust/JS/TS 디버깅에 회귀가 없다.
- `nvim/README.md`에 테스트 디버깅 워크플로우가 문서화되어 있다.
