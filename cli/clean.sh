#!/bin/bash
# ============================================================================
# clean.sh — Mac キャッシュ掃除テンプレート
# ============================================================================
# 使い方:
#   ./clean.sh                  # 対話モード（1項目ずつ確認）
#   ./clean.sh --dry-run        # ドライラン（何が削除されるか表示のみ）
#   ./clean.sh --yes            # 全自動モード（確認なしで実行）
#   ./clean.sh --quick          # クイックモード（安全な項目のみ全自動）
#
# 設定: clean.conf で掃除対象の ON/OFF を切り替えられます。
# ============================================================================

set -euo pipefail

# ============================================================
# 初期設定
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/clean.conf"

# モード設定（デフォルト: 対話モード）
DRY_RUN=false
YES_MODE=false
QUICK_MODE=false

# 集計用
TOTAL_FREED=0
CLEANED_ITEMS=()

# ============================================================
# 設定読み込み
# ============================================================
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "設定ファイルが見つかりません: $CONFIG_FILE"
    echo "  clean.conf をテンプレートからコピーしてください。"
    exit 1
fi
source "$CONFIG_FILE"

# ============================================================
# 引数解析
# ============================================================
for arg in "$@"; do
    case "$arg" in
        --dry-run|--dryrun|-n)
            DRY_RUN=true
            ;;
        --yes|-y)
            YES_MODE=true
            ;;
        --quick|-q)
            QUICK_MODE=true
            YES_MODE=true
            # クイックモードでは安全な項目だけ有効化
            CLEAN_ORB_PRUNE=false
            CLEAN_SYSTEM_LOGS=false
            CLEAN_SYSTEM_UPDATES=false
            CLEAN_CLAUDE_VM=false
            CLEAN_VSCODE_CACHE=false
            CLEAN_WINDSURF_CACHE=false
            CLEAN_CURSOR_CACHE=false
            CLEAN_ZED_CACHE=false
            CLEAN_EDGE_CACHE=false
            CLEAN_EDGE_BETA_CACHE=false
            CLEAN_FIREFOX_CACHE=false
            CLEAN_GOOGLE_CACHE=false
            CLEAN_GOOGLE_SHIPIT=false
            CLEAN_EDGE_UPDATER=false
            CLEAN_NODE_GYP_CACHE=false
            CLEAN_PIP_CACHE=false
            CLEAN_PLAYWRIGHT_CACHE=false
            CLEAN_JDTLS_CACHE=false
            CLEAN_GOOGLE_UPDATER=false
            CLEAN_MOZILLA_CACHE=false
            CLEAN_DISCORD_CACHE=false
            CLEAN_ANTIGRAVITY_UPDATER=false
            ;;
        --help|-h)
            echo "使い方: ./clean.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  --dry-run, -n   ドライラン（削除はせず表示のみ）"
            echo "  --yes, -y       全自動モード（確認なし）"
            echo "  --quick, -q     クイックモード（安全な項目のみ全自動）"
            echo "  --help, -h      このヘルプを表示"
            echo ""
            echo "設定: clean.conf で掃除対象の ON/OFF を変更できます。"
            exit 0
            ;;
        *)
            echo "不明なオプション: $arg"
            echo "使い方: ./clean.sh [--dry-run|--yes|--quick|--help]"
            exit 1
            ;;
    esac
done

# ============================================================
# ユーティリティ関数
# ============================================================

# サイズを human-readable に表示
hr_size() {
    local bytes=$1
    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1048576 )); then
        echo "$(( bytes / 1024 ))KB"
    elif (( bytes < 1073741824 )); then
        echo "$(( bytes / 1048576 ))MB"
    else
        local gb=$(echo "scale=1; $bytes / 1073741824" | bc 2>/dev/null || echo "$(( bytes / 1073741824 ))")
        echo "${gb}GB"
    fi
}

# 確認プロンプト
confirm() {
    local label="$1"
    local size="$2"
    if $YES_MODE; then
        return 0
    fi
    echo ""
    echo -n "[?] $label ($(hr_size $size) freed) Clean? [y/N] "
    read -r response
    [[ "$response" =~ ^[yY] ]]
}

# 掃除を実行
do_clean() {
    local label="$1"
    local size="$2"
    local cmd="$3"

    if $DRY_RUN; then
        echo "  [DRY-RUN] $label -> $(hr_size $size) freed"
        echo "    command: $cmd"
        TOTAL_FREED=$((TOTAL_FREED + size))
        CLEANED_ITEMS+=("$label")
        return
    fi

    if ! confirm "$label" "$size"; then
        echo "  -> skip"
        return
    fi

    echo -n "  Cleaning $label... "
    if eval "$cmd" 2>/dev/null; then
        echo "done ($(hr_size $size) freed)"
        TOTAL_FREED=$((TOTAL_FREED + size))
        CLEANED_ITEMS+=("$label")
    else
        echo "FAILED"
    fi
}

# ============================================================
# タスク追加ヘルパー
# ============================================================
# 4つの情報をパイプ区切りで1要素として扱う
add_task() {
    clean_tasks+=("$1|$2|$3|$4")
}

# ============================================================
# 掃除タスク定義
# ============================================================

clean_tasks=()

# Section 1: パッケージマネージャ
if [[ "${CLEAN_NPM_CACHE:-false}" == "true" ]]; then
    add_task "npm_cache" "npm cache" "npm_cache_size" "npm_cache_clean"
fi
if [[ "${CLEAN_BUN_CACHE:-false}" == "true" ]]; then
    add_task "bun_cache" "bun cache" "bun_cache_size" "bun_cache_clean"
fi
if [[ "${CLEAN_PIP_CACHE:-false}" == "true" ]]; then
    add_task "pip_cache" "pip cache" "dir_size \"$HOME/Library/Caches/pip\"" "rm -rf \"$HOME/Library/Caches/pip\""
fi
if [[ "${CLEAN_BREW_CACHE:-false}" == "true" ]]; then
    add_task "brew_cache" "Homebrew cache" "brew_cache_size" "brew_cache_clean"
fi

# Section 2: 開発ツール
if [[ "${CLEAN_PENCIL_UPDATER:-false}" == "true" ]]; then
    add_task "pencil_updater" "Pencil updater cache" "dir_size \"$HOME/Library/Caches/pencil-updater\"" "rm -rf \"$HOME/Library/Caches/pencil-updater\""
fi
if [[ "${CLEAN_CODEX_RUNTIMES:-false}" == "true" ]]; then
    add_task "codex_runtimes" "Codex runtimes cache" "dir_size \"$HOME/.cache/codex-runtimes\"" "rm -rf \"$HOME/.cache/codex-runtimes\""
fi
if [[ "${CLEAN_ANTIGRAVITY_UPDATER:-false}" == "true" ]]; then
    add_task "antigravity_updater" "Antigravity updater cache" "dir_size \"$HOME/Library/Caches/antigravity-updater\"" "rm -rf \"$HOME/Library/Caches/antigravity-updater\""
fi
if [[ "${CLEAN_GOOGLE_SHIPIT:-false}" == "true" ]]; then
    add_task "google_shipit" "Google ShipIt cache" "dir_size \"$HOME/Library/Caches/com.google.antigravity.ShipIt\"" "rm -rf \"$HOME/Library/Caches/com.google.antigravity.ShipIt\""
fi
if [[ "${CLEAN_EDGE_UPDATER:-false}" == "true" ]]; then
    add_task "edge_updater" "Edge/Edge Beta updater cache" "dir_size \"$HOME/Library/Application Support/Microsoft/EdgeUpdater\"" "rm -rf \"$HOME/Library/Application Support/Microsoft/EdgeUpdater\""
fi
if [[ "${CLEAN_NODE_GYP_CACHE:-false}" == "true" ]]; then
    add_task "node_gyp_cache" "node-gyp cache" "dir_size \"$HOME/Library/Caches/node-gyp\"" "rm -rf \"$HOME/Library/Caches/node-gyp\""
fi
if [[ "${CLEAN_PLAYWRIGHT_CACHE:-false}" == "true" ]]; then
    add_task "playwright_cache" "Playwright browser binaries" "dir_size \"$HOME/Library/Caches/ms-playwright-go\"" "rm -rf \"$HOME/Library/Caches/ms-playwright-go\""
fi
if [[ "${CLEAN_JDTLS_CACHE:-false}" == "true" ]]; then
    add_task "jdtls_cache" "Java LSP (jdtls) cache" "dir_size \"$HOME/Library/Caches/jdtls-*\"" "rm -rf \"$HOME/Library/Caches/jdtls-\"*"
fi
if [[ "${CLEAN_GOOGLE_UPDATER:-false}" == "true" ]]; then
    add_task "google_updater" "GoogleUpdater (Chrome系)" "dir_size \"$HOME/Library/Application Support/Google/GoogleUpdater\"" "rm -rf \"$HOME/Library/Application Support/Google/GoogleUpdater\""
fi

# Section 3: IDE
if [[ "${CLEAN_VSCODE_CACHE:-false}" == "true" ]]; then
    add_task "vscode_cache" "VSCode cache" "vscode_cache_size" "vscode_cache_clean"
fi
if [[ "${CLEAN_WINDSURF_CACHE:-false}" == "true" ]]; then
    add_task "windsurf_cache" "Windsurf cache" "windsurf_cache_size" "windsurf_cache_clean"
fi
if [[ "${CLEAN_CURSOR_CACHE:-false}" == "true" ]]; then
    add_task "cursor_cache" "Cursor cache" "cursor_cache_size" "cursor_cache_clean"
fi
if [[ "${CLEAN_ZED_CACHE:-false}" == "true" ]]; then
    add_task "zed_cache" "Zed cache" "zed_cache_size" "zed_cache_clean"
fi

# Section 4: ブラウザ
if [[ "${CLEAN_EDGE_CACHE:-false}" == "true" ]]; then
    add_task "edge_cache" "Edge cache" "dir_size \"$HOME/Library/Caches/Microsoft Edge\"" "rm -rf \"$HOME/Library/Caches/Microsoft Edge\""
fi
if [[ "${CLEAN_EDGE_BETA_CACHE:-false}" == "true" ]]; then
    add_task "edge_beta_cache" "Edge Beta cache" "dir_size \"$HOME/Library/Caches/Microsoft Edge Beta\"" "rm -rf \"$HOME/Library/Caches/Microsoft Edge Beta\""
fi
if [[ "${CLEAN_FIREFOX_CACHE:-false}" == "true" ]]; then
    add_task "firefox_cache" "Firefox cache" "dir_size \"$HOME/Library/Caches/Firefox\"" "rm -rf \"$HOME/Library/Caches/Firefox\""
fi
if [[ "${CLEAN_MOZILLA_CACHE:-false}" == "true" ]]; then
    add_task "mozilla_cache" "Mozilla app cache" "dir_size \"$HOME/Library/Caches/Mozilla\"" "rm -rf \"$HOME/Library/Caches/Mozilla\""
fi
if [[ "${CLEAN_GOOGLE_CACHE:-false}" == "true" ]]; then
    add_task "google_cache" "Google cache" "dir_size \"$HOME/Library/Caches/Google\"" "rm -rf \"$HOME/Library/Caches/Google\""
fi

# Section 5: コミュニケーションアプリ
if [[ "${CLEAN_DISCORD_CACHE:-false}" == "true" ]]; then
    add_task "discord_cache" "Discord cache" "dir_size \"$HOME/Library/Application Support/discord/Cache\"" "rm -rf \"$HOME/Library/Application Support/discord/Cache\""
fi

# Section 6: 大容量
if [[ "${CLEAN_CLAUDE_VM:-false}" == "true" ]]; then
    add_task "claude_vm" "Claude VM bundles" "dir_size \"$HOME/Library/Application Support/Claude/vm_bundles\"" "rm -rf \"$HOME/Library/Application Support/Claude/vm_bundles\""
fi
if [[ "${CLEAN_ORB_PRUNE:-false}" == "true" ]]; then
    add_task "orb_prune" "Orbstack unused images" "orb_prune_size" "orb_prune_exec"
fi

# Section 7: システム系
if [[ "${CLEAN_SYSTEM_LOGS:-false}" == "true" ]]; then
    add_task "system_logs" "System logs" "dir_size \"/Library/Logs\"" "sudo rm -rf /Library/Logs/*"
fi
if [[ "${CLEAN_SYSTEM_UPDATES:-false}" == "true" ]]; then
    add_task "system_updates" "System update cache" "dir_size \"/Library/Updates\"" "sudo rm -rf /Library/Updates/*"
fi


# ============================================================
# サイズ計算関数（遅延評価用）
# ============================================================

dir_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sk "$path" 2>/dev/null | awk '{print $1*1024}'
    else
        echo 0
    fi
}

npm_cache_size() {
    dir_size "$HOME/.npm/_cacache"
}

npm_cache_clean() {
    npm cache clean --force 2>/dev/null || true
}

bun_cache_size() {
    dir_size "$HOME/.bun/install"
}

bun_cache_clean() {
    bun pm cache rm 2>/dev/null || true
}

brew_cache_size() {
    local size=0
    local d="$HOME/Library/Caches/Homebrew"
    [[ -d "$d" ]] && size=$((size + $(du -sk "$d" 2>/dev/null | awk '{print $1*1024}') ))
    echo $size
}

brew_cache_clean() {
    brew cleanup --prune=all 2>/dev/null || true
    brew autoremove 2>/dev/null || true
    rm -rf "$HOME/Library/Caches/Homebrew" 2>/dev/null || true
}

vscode_cache_size() {
    local size=0
    local base="$HOME/Library/Application Support/Code"
    for d in "Cache" "CachedData" "CachedExtensionVSIXs" "WebStorage"; do
        [[ -d "$base/$d" ]] && size=$((size + $(du -sk "$base/$d" 2>/dev/null | awk '{print $1*1024}') ))
    done
    echo $size
}

vscode_cache_clean() {
    local base="$HOME/Library/Application Support/Code"
    rm -rf "$base/Cache" "$base/CachedData" "$base/CachedExtensionVSIXs" "$base/WebStorage" 2>/dev/null || true
}

windsurf_cache_size() {
    local size=0
    local base="$HOME/Library/Application Support/Windsurf"
    for d in "Cache" "CachedData" "WebStorage"; do
        [[ -d "$base/$d" ]] && size=$((size + $(du -sk "$base/$d" 2>/dev/null | awk '{print $1*1024}') ))
    done
    echo $size
}

windsurf_cache_clean() {
    local base="$HOME/Library/Application Support/Windsurf"
    rm -rf "$base/Cache" "$base/CachedData" "$base/WebStorage" 2>/dev/null || true
}

cursor_cache_size() {
    local size=0
    local base="$HOME/Library/Application Support/Cursor"
    for d in "Cache" "CachedData" "WebStorage"; do
        [[ -d "$base/$d" ]] && size=$((size + $(du -sk "$base/$d" 2>/dev/null | awk '{print $1*1024}') ))
    done
    echo $size
}

cursor_cache_clean() {
    local base="$HOME/Library/Application Support/Cursor"
    rm -rf "$base/Cache" "$base/CachedData" "$base/WebStorage" 2>/dev/null || true
}

zed_cache_size() {
    local size=0
    local base="$HOME/Library/Application Support/Zed"
    for d in "node" "external_agents" "extensions"; do
        [ -d "$base/$d" ] && size=$((size + $(du -sk "$base/$d" 2>/dev/null | awk '{print $1*1024}') ))
    done
    echo $size
}

zed_cache_clean() {
    local base="$HOME/Library/Application Support/Zed"
    rm -rf "$base/node" "$base/external_agents" 2>/dev/null || true
    # extensions は最小限のキャッシュだけ削除（拡張機能自体は残す）
    rm -rf "$base/extensions/_staging" "$base/extensions/_cache" 2>/dev/null || true
}

orb_prune_size() {
    # Orbstack の未使用領域は事前計算が難しい
    echo 0
}

orb_prune_exec() {
    if command -v orb &>/dev/null; then
        orb prune --force 2>/dev/null || true
    fi
}

# ============================================================
# メイン処理
# ============================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Mac Cache Cleaner Template"
    echo "=============================================="
    echo ""

    if $DRY_RUN; then
        echo "  [DRY-RUN mode] - no files will be deleted"
    elif $QUICK_MODE; then
        echo "  [QUICK mode] - safe items only, auto-confirm"
    elif $YES_MODE; then
        echo "  [AUTO mode] - no confirmation"
    else
        echo "  [INTERACTIVE mode] - confirm each item"
    fi
    echo ""

    # 掃除実行
    for task in "${clean_tasks[@]}"; do
        # パイプ区切りで分割
        local id="${task%%|*}"
        local rest="${task#*|}"
        local label="${rest%%|*}"
        rest="${rest#*|}"
        local size_cmd="${rest%%|*}"
        local clean_cmd="${rest#*|}"

        # サイズ取得（遅延評価）
        size=$(eval "$size_cmd" 2>/dev/null || echo 0)
        if [[ "$size" -gt 0 ]] || [[ "$id" == "orb_prune" ]]; then
            do_clean "$label" "$size" "$clean_cmd"
        else
            echo "  - $label: nothing to clean (skip)"
        fi
    done

    # サマリー表示
    echo ""
    echo "=============================================="
    echo "  Summary"
    echo "=============================================="
    if $DRY_RUN; then
        echo "  Dry-run results:"
        for item in "${CLEANED_ITEMS[@]+"${CLEANED_ITEMS[@]}"}"; do
            echo "    - $item"
        done
        echo "  Total space that can be freed: $(hr_size $TOTAL_FREED)"
    else
        if [[ ${#CLEANED_ITEMS[@]} -eq 0 ]]; then
            echo "  Nothing was cleaned."
        else
            echo "  Cleaned:"
            for item in "${CLEANED_ITEMS[@]+"${CLEANED_ITEMS[@]}"}"; do
                echo "    - $item"
            done
            echo "  Total freed: $(hr_size $TOTAL_FREED)"
        fi
    fi
    echo "=============================================="
    echo ""

    if $DRY_RUN; then
        echo "Tip: Run without --dry-run or with --yes to actually clean."
    fi
}

main
