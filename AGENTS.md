# AGENTS.md

このファイルは、この dotfiles リポジトリで作業する AI エージェント向けのリポジトリ固有ガイドです。
グローバル指示（例: `.agents/AGENTS.md`）よりも、このリポジトリに関する具体的な事項を優先してください。

## リポジトリ概要

- 個人の開発環境設定を管理する dotfiles リポジトリです。
- ルート直下の dotfile と、`.config/` 配下のアプリケーション設定を主に管理します。
- 設定ファイルや `scripts/` 配下の補助スクリプトは、このリポジトリ側を正として管理し、実環境の所定パスへ symlink して配置します。
- README の Usage にあるとおり、実環境では各ファイルをホームディレクトリや `~/.config` に symlink して使う前提です。
- OpenCode / Cline / Antigravity CLI など、AI コーディング支援ツールの設定も含みます。

## 重要な方針

- ユーザーの個人設定を扱うため、無関係な整形・好みの変更・大規模な再構成は避けてください。
- 既存の未コミット変更はユーザーの作業である可能性が高いため、勝手に巻き戻したり上書きしたりしないでください。
- 設定ファイルの変更では、対象ツールの既存スタイル・命名・コメント量に合わせてください。
- README に記載された symlink 先や利用経路が変わる場合は、README も必要最小限で更新してください。
- シークレット、トークン、ローカルマシン固有の資格情報、個人情報を追加しないでください。

## 主な構成

- `README.md`: 管理対象設定と symlink 手順。
- `.config/fish/config.fish`: fish shell 設定。
- `.config/nvim/init.lua`: Neovim 設定。
- `.config/opencode/`: OpenCode 設定、プロンプト、コマンド、プラグイン依存関係。
- `.gemini/antigravity-cli/settings.json`: Antigravity CLI 設定。
- `scripts/`: 補助スクリプト。
  - `scripts/agy-statusline`: Antigravity CLI status line。
  - `scripts/cline`: Cline 起動用 wrapper。
  - `scripts/git-*`: Git 補助コマンド。
- `tests/`: shell ベースのテスト。
- `docs/adr/`: アーキテクチャ判断記録。
- `docs/superpowers/`: AI ツール設定・ワークフロー関連の設計、計画、メモ。
- `stylua.toml`: Lua フォーマット設定。

## 作業前チェック

1. `git status --short` で作業ツリーを確認してください。
2. 変更対象ファイルと近接ファイルを読み、既存の書式・設計・命名に合わせてください。
3. ユーザーの未コミット変更が対象ファイルにある場合は、その差分を壊さないようにしてください。
4. 破壊的な操作、ファイル移動、既存設定の削除は、明示的に依頼された場合だけ行ってください。

## コーディング・編集規約

- POSIX shell スクリプトは既存同様 `#!/bin/sh` と `set -eu` / `set -euo pipefail` の使い分けに従ってください。
- shell スクリプトでは移植性を優先し、既存が POSIX shell の場合は Bash 専用構文を追加しないでください。
- Lua は `stylua.toml` に従い、スペース 2、column width 120 を基準にしてください。
- JSON / TOML / YAML は既存ファイルのインデントとキー配置を保ってください。
- dotfiles なので、絶対パスの追加は避け、必要なら `~`、`$HOME`、または README の既存パターンに合わせてください。
- 新しい外部依存を追加する場合は、既に使われている管理方法（例: mise、bun lock）との整合性を確認してください。

## 検証

変更内容に応じて、可能な範囲で以下を実行してください。

- Antigravity status line を変更した場合:

  ```sh
  ./tests/agy-statusline.sh
  ```

- shell スクリプトを変更した場合:

  ```sh
  sh -n scripts/<script-name>
  ```

- Lua / Neovim 設定を変更した場合:

  ```sh
  stylua --check .config/nvim/init.lua
  ```

  `stylua` が未インストールの場合は、失敗内容を報告し、勝手に別フォーマッタで整形しないでください。

- OpenCode plugin 依存関係を変更した場合:

  ```sh
  cd .config/opencode && bun install
  ```

  `bun.lock` の差分も確認してください。

- JSON / TOML / YAML 設定を変更した場合は、対象ツールの検証コマンドが分かる場合のみ実行し、不明な場合は構文と差分を目視確認してください。

## Git 運用

- 明示的に依頼されていない限り、commit、push、tag、merge、rebase は行わないでください。
- `reset --hard`、`checkout -- <file>`、`clean -fd` など、ユーザー変更を消す操作は禁止です。
- コミットメッセージを提案する場合は Conventional Commits を使ってください。
  - 例: `docs(agents): add repository guidance`

## ドキュメント更新

- 設定の使い方、symlink 手順、必要な依存関係が変わる場合は `README.md` を更新してください。
- 設計判断を残す価値がある変更は `docs/adr/` に ADR を追加することを検討してください。
- 実装計画や調査メモを追加する場合は、既存の `docs/superpowers/` の分類に合わせてください。

## 最終報告

作業完了時は、以下を簡潔に報告してください。

- 変更したファイル
- 変更内容の要約
- 実行した検証コマンドと結果
- 実行できなかった検証がある場合は、その理由