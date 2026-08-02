#!/usr/bin/env bash

set -euo pipefail

# カラー出力用の定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# zsh のインストール確認とインストール処理
install_zsh() {
    if command -v zsh &> /dev/null; then
        log_success "zsh は既にインストールされています。"
        return 0
    fi

    log_info "zsh がインストールされていません。インストールを試みます..."

    if command -v apt-get &> /dev/null; then
        log_info "apt を使用して zsh をインストールします (sudo 権限が必要です)..."
        sudo apt-get update && sudo apt-get install -y zsh
    elif command -v dnf &> /dev/null; then
        log_info "dnf を使用して zsh をインストールします (sudo 権限が必要です)..."
        sudo dnf install -y zsh
    elif command -v yum &> /dev/null; then
        log_info "yum を使用して zsh をインストールします (sudo 権限が必要です)..."
        sudo yum install -y zsh
    elif command -v pacman &> /dev/null; then
        log_info "pacman を使用して zsh をインストールします (sudo 権限が必要です)..."
        sudo pacman -S --noconfirm zsh
    else
        log_error "サポートされているパッケージマネージャ (apt, dnf, yum, pacman) が見つかりませんでした。"
        log_error "手動で zsh をインストールした後に、このスクリプトを再度実行してください。"
        exit 1
    fi

    # インストール確認
    if ! command -v zsh &> /dev/null; then
        log_error "zsh のインストールに失敗しました。"
        exit 1
    fi
    log_success "zsh をインストールしました。"
}

# zsh のインストールを実行
install_zsh

# 必要なコマンドの確認
for cmd in git curl tar; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd がインストールされていません。インストールしてから再度実行してください。"
        exit 1
    fi
done

# ディレクトリの作成
ZSH_DIR="$HOME/.zsh"
LOCAL_BIN_DIR="$HOME/.local/bin"
log_info "必要なディレクトリを作成しています..."
mkdir -p "$ZSH_DIR"
mkdir -p "$LOCAL_BIN_DIR"

# PATH に ~/.local/bin を一時的に追加して、インストール直後のコマンド実行を可能にする
export PATH="$LOCAL_BIN_DIR:$PATH"

# --- 1. fzf のセットアップ ---
if ! command -v fzf &> /dev/null; then
    log_info "fzf が見つかりません。インストールを開始します..."
    if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    else
        log_info "既存の fzf リポジトリを更新しています..."
        git -C "$HOME/.fzf" pull
    fi
    "$HOME/.fzf/install" --bin
    ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN_DIR/fzf"
    log_success "fzf を $LOCAL_BIN_DIR/fzf にインストールしました。"
else
    log_success "fzf は既にインストールされています。"
fi

# --- 2. starship のセットアップ ---
if ! command -v starship &> /dev/null; then
    log_info "starship が見つかりません。インストールを開始します..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$LOCAL_BIN_DIR"
    log_success "starship を $LOCAL_BIN_DIR/starship にインストールしました。"
else
    log_success "starship は既にインストールされています。"
fi

# --- 3. zellij のセットアップ ---
if ! command -v zellij &> /dev/null; then
    log_info "zellij が見つかりません。インストールを開始します..."
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    if [ "$OS" = "linux" ]; then
        TARGET=""
        if [ "$ARCH" = "x86_64" ]; then
            TARGET="x86_64-unknown-linux-musl.tar.gz"
        elif [ "$ARCH" = "aarch64" ]; then
            TARGET="aarch64-unknown-linux-musl.tar.gz"
        fi

        if [ -n "$TARGET" ]; then
            log_info "GitHub から最新の zellij バイナリをロードしています..."
            ZELLIJ_RELEASE_JSON=$(curl -sL https://api.github.com/repos/zellij-org/zellij/releases/latest)
            ZELLIJ_URL=$(echo "$ZELLIJ_RELEASE_JSON" | grep -o 'https://github.com/zellij-org/zellij/releases/download/[^"]*' | grep "$TARGET" | head -n 1)
            
            if [ -n "$ZELLIJ_URL" ]; then
                curl -L "$ZELLIJ_URL" -o /tmp/zellij.tar.gz
                tar -xzf /tmp/zellij.tar.gz -C "$LOCAL_BIN_DIR" zellij
                rm /tmp/zellij.tar.gz
                log_success "zellij を $LOCAL_BIN_DIR/zellij にインストールしました。"
            else
                log_error "zellij のダウンロードURLの取得に失敗しました。"
            fi
        else
            log_warning "未対応のアーキテクチャ ($ARCH) のため、zellij の自動インストールをスキップしました。"
        fi
    else
        log_warning "Linux 以外のOSのため、zellij の自動インストールをスキップしました。"
    fi
else
    log_success "zellij は既にインストールされています。"
fi

# プラグインのクローン/更新関数
setup_plugin() {
    local repo_url=$1
    local dest_dir=$2
    local name=$3

    if [ -d "$dest_dir" ]; then
        log_info "$name は既に存在します。最新化しています..."
        git -C "$dest_dir" pull
    else
        log_info "$name をクローンしています..."
        git clone --depth 1 "$repo_url" "$dest_dir"
    fi
}

# --- 4. zsh-autosuggestions ---
setup_plugin \
    "https://github.com/zsh-users/zsh-autosuggestions.git" \
    "$ZSH_DIR/zsh-autosuggestions" \
    "zsh-autosuggestions"

# --- 5. zsh-completions ---
setup_plugin \
    "https://github.com/zsh-users/zsh-completions.git" \
    "$ZSH_DIR/zsh-completions" \
    "zsh-completions"

# --- 6. zsh-syntax-highlighting ---
setup_plugin \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$ZSH_DIR/zsh-syntax-highlighting" \
    "zsh-syntax-highlighting"

# --- .zshrc の作成と編集 ---
ZSHRC_PATH="$HOME/.zshrc"
BACKUP_PATH="${ZSHRC_PATH}.bak.$(date +%Y%m%d%H%M%S)"
ZSH_INIT_MARKER_BEGIN="# >>> zsh_init >>>"
ZSH_INIT_MARKER_END="# <<< zsh_init <<<"

if [ -f "$ZSHRC_PATH" ]; then
    log_info "既存の .zshrc をバックアップしています: $BACKUP_PATH"
    cp "$ZSHRC_PATH" "$BACKUP_PATH"
fi

if [ -f "$HOME/.bashrc" ]; then
    log_info "既存の .bashrc を検出しました。エイリアスや PATH 等を .zshrc へ引き継ぎます。"
else
    log_warning ".bashrc が見つかりません。bash 設定の引き継ぎはスキップされます。"
fi

log_info ".zshrc に設定を書き込んでいます..."

# 書き込む設定ブロック（マーカーで囲み、再実行時に置換できるようにする）
cat << 'EOF' > temp_zshrc_block
# >>> zsh_init >>>

# ==========================================
# Inherit settings from existing ~/.bashrc
# ==========================================
# bash 固有の組み込みを無害化し、alias / export PATH 等を引き継ぐ。
# 履歴や補完など zsh 側の設定は、この後のブロックで上書きする。
if [ -f "$HOME/.bashrc" ]; then
  shopt() { :; }
  complete() { :; }
  # shellcheck disable=SC1090,SC1091
  source "$HOME/.bashrc"
  unfunction shopt complete 2>/dev/null || true
fi

# ==========================================
# Fish-like environment settings for Zsh
# ==========================================

# --- 環境変数 PATH の設定 ---
# ローカルバイナリディレクトリを追加
export PATH="$HOME/.local/bin:$PATH"

# --- 履歴設定 ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history           # 履歴を他のセッションと共有
setopt hist_ignore_all_dups    # 重複するコマンド行は古い方を削除
setopt hist_ignore_space       # スペースで始まるコマンドは履歴に保存しない
setopt hist_reduce_blanks      # 余分なスペースを削除して履歴に保存

# --- zsh-completions (補完機能の拡張) ---
if [ -d "$HOME/.zsh/zsh-completions" ]; then
  fpath=($HOME/.zsh/zsh-completions/src $fpath)
fi

# 補完の初期化
autoload -Uz compinit
compinit

# 補完メニューの挙動設定 (fishのようにタブで選択可能にする)
zstyle ':completion:*' menu select
# 大文字小文字を区別せずに補完、かつ部分一致補完を有効にする
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# --- Up line or beginning search (履歴のプレフィックス一致検索) ---
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
# キーバインド設定 (上下矢印キー)
bindkey '^[[A' up-line-or-beginning-search # Up Arrow
bindkey '^[[B' down-line-or-beginning-search # Down Arrow
if [[ -n "${terminfo[kcuu1]}" ]]; then
  bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
fi
if [[ -n "${terminfo[kcud1]}" ]]; then
  bindkey "${terminfo[kcud1]}" down-line-or-beginning-search
fi

# --- fzf 連携 ---
if (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
fi

# --- starship プロンプト ---
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi

# --- zellij 連携 ---
# zellij がインストールされていて、現在マルチプレクサ内でなく、かつインタラクティブシェルの場合に自動起動
if (( $+commands[zellij] )); then
  # 自動起動を有効にしたい場合は、以下のコメントアウトを解除するか、
  # 環境変数 ZELLIJ_AUTO_START=true を設定してください。
  # export ZELLIJ_AUTO_START=true

  if [[ -z "$ZELLIJ" && -z "$SSH_CONNECTION" && "${ZELLIJ_AUTO_START:-false}" == "true" ]]; then
    exec zellij
  fi
fi

# --- zsh-autosuggestions (自動提案) ---
if [ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
  # 提案テキストのスタイル変更 (薄いグレー)
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
fi

# --- zsh-syntax-highlighting (構文強調) ---
# ※ zsh-syntax-highlighting は必ず最後の方にロードする必要があります
if [ -f "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# <<< zsh_init <<<
EOF

# .zshrc から既存の管理ブロック / 旧形式ブロックを除去する
strip_managed_zshrc_block() {
    local src=$1
    local dest=$2

    if grep -qF "$ZSH_INIT_MARKER_BEGIN" "$src"; then
        awk -v begin="$ZSH_INIT_MARKER_BEGIN" -v end="$ZSH_INIT_MARKER_END" '
            $0 == begin { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$src" > "$dest"
    elif grep -q "Fish-like environment settings for Zsh" "$src"; then
        # 旧形式: Fish-like 見出し直前の区切り線からファイル末尾までを除去
        awk '
            BEGIN { skip=0 }
            /^# =+[[:space:]]*$/ {
                getline nextline
                if (nextline ~ /Fish-like environment settings for Zsh/) {
                    skip=1
                    next
                }
                if (!skip) {
                    print
                    print nextline
                }
                next
            }
            skip { next }
            { print }
        ' "$src" > "$dest"
    else
        cp "$src" "$dest"
    fi

    # 末尾の連続空行を削除
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$dest" 2>/dev/null || true
}

# 既存の .zshrc がある場合、管理ブロックを置換または追記する
if [ -f "$ZSHRC_PATH" ]; then
    if grep -qF "$ZSH_INIT_MARKER_BEGIN" "$ZSHRC_PATH" || grep -q "Fish-like environment settings for Zsh" "$ZSHRC_PATH"; then
        log_info "既存の設定ブロックを更新しています..."
        strip_managed_zshrc_block "$ZSHRC_PATH" temp_zshrc_clean
        if [ -s temp_zshrc_clean ]; then
            {
                cat temp_zshrc_clean
                echo ""
                cat temp_zshrc_block
            } > "$ZSHRC_PATH"
        else
            cp temp_zshrc_block "$ZSHRC_PATH"
        fi
        rm -f temp_zshrc_clean temp_zshrc_block
        log_success ".zshrc の設定を更新しました。"
    else
        {
            echo ""
            cat temp_zshrc_block
        } >> "$ZSHRC_PATH"
        rm temp_zshrc_block
        log_success ".zshrc に設定を追記しました。"
    fi
else
    mv temp_zshrc_block "$ZSHRC_PATH"
    log_success "新規に .zshrc を作成し、設定を書き込みました。"
fi

echo ""
log_success "セットアップが完了しました！"
log_info "シェルを zsh に変更するには以下のコマンドを実行してください："
echo -e "   chsh -s \$(which zsh)"
log_info "その後、新しいターミナルを開くか、'zsh' コマンドを実行して環境を確認してください。"
echo ""
