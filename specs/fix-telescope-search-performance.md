# NVChad Telescope Find Files / Live Grep 성능 저하 원인 분석 및 개선 계획

## 배경

- 증상: `<leader>ff` (find_files)로 파일을 검색할 때 키워드 입력 후 결과가 노출되기까지
  매우 오래 걸린다. `<leader>fw`/`<leader>fg` (live_grep) 도 동일하게 느리다.
- 가설: `.venv` 같은 프로젝트 내 패키지/의존성 디렉터리가 인덱싱 대상에 포함되어
  검색 후보군이 비정상적으로 커진 것이 원인 중 하나로 의심됨.
- 목적: 실제 원인을 코드/실측으로 확인하고, 개선 계획을 수립한다. (이 문서는 계획 단계이며
  실제 설정 변경은 별도로 진행)

## 원인 분석

### 1. (핵심 원인) `find_files`/`live_grep` 기본 피커가 `.gitignore`·hidden 필터링을 무력화함

`nvim/lua/plugins/init.lua:270-296`:

```lua
{
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = {
      vimgrep_arguments = {
        "rg", "-L", "--color=never", "--no-heading", "--with-filename",
        "--line-number", "--column", "--smart-case",
        "--no-ignore-vcs", "--hidden",
      },
    },
    pickers = {
      find_files = { no_ignore = true, hidden = true },
      live_grep = { additional_args = { "--no-ignore-vcs", "--hidden" } },
    },
  },
}
```

NvChad는 원래 두 종류의 검색을 의도적으로 분리해서 제공한다
(`~/.local/share/nvim/lazy/NvChad/lua/nvchad/mappings.lua:57,71,74-76`):

- `<leader>ff` → `Telescope find_files` (기본, `.gitignore` 존중)
- `<leader>fa` → `Telescope find_files follow=true no_ignore=true hidden=true` (전체 검색, 별도 키맵)

그런데 위 dotfiles 설정은 `<leader>fa` 전용이어야 할 `no_ignore=true, hidden=true`를
**기본 `find_files`/`live_grep` 피커 자체**에 덮어써서, 매번 `<leader>ff`/`<leader>fw`를
누를 때마다 "전체 검색"이 실행되는 셈이 되었다. (telescope 소스 확인:
`telescope.nvim/lua/telescope/builtin/__files.lua:310-328` — `no_ignore` → `fd/rg --no-ignore`,
`hidden` → `--hidden` 로 그대로 매핑됨)

**실측 벤치마크** (`rg 14.1.1`, `fd 10.4.2`, 로컬 SSD):

| 프로젝트 | 도구 | 기본(.gitignore 존중) | 현재 설정(no_ignore+hidden) | 배율 |
|---|---|---|---|---|
| `datamaker-annotator-backend` (`.venv` 443M) | `fd --type f` | 423 files / 0.03s | 27,982 files / 0.22s | **66배** |
| `datamaker-annotator-frontend` (`node_modules` 646M) | `fd --type f` | 754 files / 0.03s | 50,323 files / 0.14s | **67배** |
| `datamaker-annotator-backend` | `rg "def "` (grep) | 1,160 matches / 0.05s | 117,845 matches / 0.66s | **101배 매치, 13배 느림** |

두 프로젝트 모두 `.venv`/`node_modules`는 각자의 `.gitignore`에 명시되어 있고
(`.gitignore` 확인 완료), 문제의 옵션들이 정확히 그 필터링을 해제하고 있었다.

체감 지연의 실질적인 원인은 `rg`/`fd` 프로세스 자체(수백 ms 수준)보다,
**Telescope가 수만 건의 후보를 매 키 입력마다 Lua 레벨에서 fuzzy 매칭·정렬·렌더링**
해야 하는 비용이 후보 수에 비례해 커지는 데 있다. 이것이 "키워드 입력 후 결과 노출까지
오래 걸린다"는 증상과 정확히 일치한다.

### 2. (보조 원인) `telescope-fzf-native.nvim` 미설치

- 현재 정렬기: telescope 내장 순수 Lua fzy 소터.
- `~/.local/share/nvim/lazy/`, `nvim/lazy-lock.json` 어디에도 `fzf-native` 없음 (확인 완료).
- 네이티브(C, `make` 빌드) 소터 대비 매 키 입력 시 재정렬 비용이 큼. 원인 1로 후보군이
  66~101배 부풀어 있는 상태라 이 차이가 더 크게 체감된다. 원인 1을 고쳐도 대형
  모노레포에서는 여전히 유효한 개선 포인트.

### 3. (연관 신호, 이번 범위 아님) `nvim-tree`도 동일하게 "전부 보이기" 설정

`nvim/lua/plugins/init.lua:260-267`의 `nvim-tree` 설정도 `filters.git_ignored = false`로,
같은 "무시 파일도 항상 노출" 의도가 반복된다 (`nvim/README.md` 5.2/5.3에 의도적으로
문서화되어 있음). 트리는 1회 렌더링이라 실시간 타이핑 지연과는 무관하므로 이번
성능 이슈의 원인은 아니지만, telescope 쪽 설정과 같은 배경에서 나온 결정으로 보여
참고용으로 남긴다. (변경 여부는 사용자 워크플로우 확인 후 별도 결정 — 이번 개선 계획 범위 제외)

### 확인 결과: 도구 자체는 문제 없음

- `ripgrep 14.1.1`, `fd 10.4.2` 모두 최신이며 정상 동작.
- `RIPGREP_CONFIG_PATH` 미설정, 전역 `.rgignore`/`.ripgreprc` 없음 — 외부 설정 간섭 없음.
- `nvim 0.11.6` (LuaJIT) — 버전 이슈 아님.

## 개선 계획

### 목표

- `<leader>ff`/`<leader>fw` 기본 검색은 각 프로젝트의 `.gitignore`를 존중해
  `.venv`/`node_modules`/`__pycache__`/`.git` 등 대형 디렉터리를 인덱싱 대상에서 제외한다.
- "무시된 파일까지 찾고 싶다"는 기존 요구는 NvChad가 이미 제공하는 `<leader>fa`
  (find_files 전용)로 계속 충족하고, live_grep에도 동일 목적의 대칭 키맵을 추가한다.
- 네이티브 정렬기를 설치해 대형 프로젝트에서도 타이핑 지연을 최소화한다.
- `.gitignore`가 없거나 불완전한 저장소를 위해 무거운 디렉터리를 `file_ignore_patterns`로
  방어적으로 한 번 더 걸러낸다.

### 포함

- `nvim/lua/plugins/init.lua`: telescope `opts`에서 기본 `find_files`/`live_grep`의
  `no_ignore` / `--no-ignore-vcs` 제거 (전체 검색 전용 키맵에만 남김)
- `file_ignore_patterns` 추가: `.git/`, `.venv/`, `venv/`, `node_modules/`, `__pycache__/`,
  `.mypy_cache/`, `.ruff_cache/`, `dist/`, `build/`, `target/` 등
- `telescope-fzf-native.nvim` 플러그인 추가 (`build = "make"`,
  `cond = vim.fn.executable "make" == 1`) + `load_extension("fzf")` 연결
- (선택) live_grep용 "전체 검색" 키맵 추가 (예: `<leader>fA`)로 find_files의 `<leader>fa`와 대칭
- `nvim/README.md` 5.2 절 갱신: 기본 검색과 전체 검색이 분리되어 있다는 원칙 명시
- `nvim/lazy-lock.json` 갱신 (`:Lazy sync` 결과 자동 반영)

### 제외

- `nvim-tree`의 `git_ignored = false` 변경 — 실시간 타이핑 지연과 무관하고 별도 의도일
  가능성이 있어 이번 조사 범위에서 제외 (원인 분석 §3 참고, 필요 시 별도 논의)
- ripgrep/fd 자체 교체·업그레이드 — 도구 자체는 문제 없음을 확인함
- 개별 프로젝트의 `.gitignore` 내용 수정

### `hidden` 옵션 관련 결정 사항

`no_ignore`와 별개로 `hidden = true`는 유지를 권장한다. `.git/` 디렉터리는 `.gitignore`
규칙과 무관하게 rg/fd가 항상 하드코딩으로 제외하므로, `no_ignore`만 제거하면
`hidden = true`를 유지해도 `.env`, `.github/`처럼 유용한 dotfile은 계속 검색되면서
`.venv`/`node_modules`(각 프로젝트 `.gitignore`에 등록됨)는 계속 제외된다. 더 보수적으로
가고 싶다면 `hidden`도 함께 제거하는 대안이 있으나, 우선순위는 `no_ignore` 제거로 충분하다고 판단.

### 구현 단계

1. telescope `opts` 정리
   - `pickers.find_files`에서 `no_ignore = true` 제거 (`hidden = true`는 유지)
   - `pickers.live_grep.additional_args`에서 `--no-ignore-vcs` 제거 (`--hidden`은 유지)
   - `defaults.vimgrep_arguments`의 `--no-ignore-vcs` 제거 (live_grep 외 `grep_string` 등에도
     영향을 주므로 함께 정리)
2. `defaults.file_ignore_patterns` 추가 (방어적 안전망)
3. `telescope-fzf-native.nvim` 플러그인 스펙 추가, `:Lazy sync` 후
   `require("telescope").load_extension("fzf")` 호출 확인
4. (선택) live_grep 전체 검색 키맵 추가
5. `nvim/README.md` 5.2 절 갱신
6. 검증
   - 벤치마크 프로젝트(`datamaker-annotator-backend`, `datamaker-annotator-frontend`)에서
     `<leader>ff`/`<leader>fw` 재측정 → `.gitignore` 준수 수준(수백 건)으로 복귀 확인
   - `<leader>fa`가 여전히 전체 검색(`.venv`/`node_modules` 포함) 동작하는지 확인
   - `:checkhealth telescope`에서 `fzf-native` 감지 확인

## 완료 기준 (DoD)

- `<leader>ff`/`<leader>fw` 기본 검색 결과에 `.venv`/`node_modules`/`.git` 내부 파일이
  더 이상 포함되지 않는다 (실측 파일 수/매치 수가 `.gitignore` 준수 시 수준으로 복귀).
- `telescope-fzf-native.nvim`이 설치되어 네이티브 정렬기가 활성화된다.
- "무시된 파일까지 찾기" 요구가 최소 1개 키맵(`<leader>fa`, 필요 시 grep 대응 키맵)으로
  여전히 가능하다.
- `nvim/README.md`에 기본/전체 검색 분리 원칙이 반영된다.

## 부록: 실측 원본 데이터

```
# datamaker-annotator-backend (.venv 443M, .gitignore에 `.venv` 포함)
$ fd --type f .                       → 423 files   (0.031s)
$ fd --type f --no-ignore --hidden .  → 27,982 files (0.215s)   # 66x

$ rg ... "def " .                          → 1,160 matches   (0.050s)
$ rg ... --no-ignore-vcs --hidden "def " . → 117,845 matches (0.664s)   # 101x matches, 13x slower

# datamaker-annotator-frontend (node_modules 646M, .gitignore에 `node_modules` 포함)
$ fd --type f .                       → 754 files   (0.028s)
$ fd --type f --no-ignore --hidden .  → 50,323 files (0.144s)   # 67x

# 환경
ripgrep 14.1.1, fd 10.4.2, nvim 0.11.6 (LuaJIT), RIPGREP_CONFIG_PATH unset, 전역 rgignore 없음
telescope-fzf-native.nvim: 미설치 (lazy-lock.json, ~/.local/share/nvim/lazy 모두 없음)
```
