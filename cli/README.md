# 🧹 Mac キャッシュ掃除テンプレート

このテンプレートは、macOS のキャッシュファイルを安全に削除してディスク容量を回復するためのものです。

**ポリシー**: キャッシュ削除のみ。アプリのアンインストールは行いません。

---

## ファイル構成

```
src/cli/
├── README.md            # 👈 このファイル。使い方説明
├── clean.sh             # メイン実行スクリプト（実行ファイル）
├── clean.conf           # 掃除対象の設定ファイル
├── cache-reference.md   # 各キャッシュの詳細リファレンス
└── storage_agent.py     # 削除を行わない容量調査エージェント
```

## 容量調査エージェント（読み取り専用）

`storage_agent.py` は、容量の大きいフォルダとファイルを調査します。ファイル内容は開かず、シンボリックリンクも辿りません。削除・移動・圧縮・設定変更は行いません。

```bash
python3 ./storage_agent.py
python3 ./storage_agent.py ~/Downloads --depth 3 --top 30
python3 ./storage_agent.py --interactive
python3 ./storage_agent.py --json > storage-report.json
```

対話モードでは `scan [path]`、`focus [path]`、`help`、`quit` が使えます。表示された確認ポイントを見て、削除するかどうかは手動で判断してください。

---

## 使い方

`src` ディレクトリ内から Makefile 経由で実行できます。

```bash
make cli                       # 対話モード
make cli ARGS="--dry-run"      # 削除せずに確認
```

以下の直接実行例は `src/cli` 内で実行します。

### 1. 掃除対象を選ぶ

`clean.conf` をエディタで開き、掃除したい項目を `true` に、スキップしたい項目を `false` に設定します。

```bash
# 例: Claude VM だけ掃除したい場合
CLEAN_NPM_CACHE=false
CLEAN_CLAUDE_VM=true
CLEAN_BREW_CACHE=false
# ... 他の項目も適宜設定
```

### 2. ドライランで確認（推奨）

```bash
./clean.sh --dry-run
```

実際に削除はせず、何がどれだけ解放されるかを確認できます。

### 3. 実行する

#### 対話モード（1項目ずつ確認）
```bash
./clean.sh
```

#### 全自動モード（確認なし）
```bash
./clean.sh --yes
```

#### クイックモード（安全な項目だけ全自動）
```bash
./clean.sh --quick
```
以下だけを自動で掃除します（確認なし）：
- npm / bun / Homebrew キャッシュ
- Pencil updater / Codex / Antigravity updater キャッシュ

---

## モード一覧

| オプション | 動作 |
|-----------|------|
| （なし） | 対話モード。1項目ずつ yes/no を確認 |
| `--dry-run` / `-n` | ドライラン。削除せずに解放見込みを表示 |
| `--yes` / `-y` | 全自動。設定が true の項目をすべて実行 |
| `--quick` / `-q` | クイック。パッケージマネージャ系キャッシュのみ自動 |
| `--help` / `-h` | ヘルプ表示 |

---

## キャッシュ削除の考え方

### 安全（リスク低）
- **パッケージマネージャキャッシュ**（npm, bun, brew）
  - 再ダウンロード可能。削除後も `install` 時に再生成。
- **ブラウザキャッシュ**（Edge, Firefox, Google）
  - 再ダウンロード可能。ログイン状態は維持。
- **IDEキャッシュ**（VSCode, Windsurf, Cursor, Zed）
  - 再起動時に再生成。設定や拡張機能は維持。
- **各種アプデーターキャッシュ**（Pencil, Antigravity, Google ShipIt）
  - アプリ動作に影響なし。

### やや注意（リスク中）
- **Claude VM バンドル**（~9.7GB）
  - 削除後、次回 Claude 起動時に再生成される。設定や会話履歴に影響なし。
  - ただし初回起動時にダウンロードが発生するため時間がかかる。
- **Orbstack 未使用イメージ削除**
  - Docker の未使用コンテナ・イメージを削除。起動中のコンテナには影響なし。
  - ただし使用中のイメージも対象になる場合があるので注意。

### システム系（慎重に）
- **システムログ**（/Library/Logs/）
  - トラブルシューティングに使うログが消える。問題が起きてないなら削除してOK。
- **システムアップデートキャッシュ**（/Library/Updates/）
  - インストール済みアップデートのパッケージ。削除しても問題なし。

---

## カスタマイズ方法

`clean.conf` を編集するだけで掃除対象をカスタマイズできます。

新しい掃除対象を追加したい場合は、以下の3箇所を編集します：

1. **clean.conf** に設定変数を追加
2. **clean.sh** の `clean_tasks+=()` ブロックにタスク定義を追加
3. **clean.sh** にサイズ計算関数と実行関数を追加（必要なら）

---

## 注意事項

- このスクリプトは `$HOME` 以下のユーザーファイルのみを対象としています。
- システム領域（`/Library/Logs/`, `/Library/Updates/`）の削除には `sudo` が必要です。
- 実行前に必ず `--dry-run` で影響範囲を確認することを推奨します。
- このテンプレートは `clean.sh` 自身が置かれているディレクトリの `clean.conf` を読み込みます。
