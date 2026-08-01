#!/usr/bin/env pwsh

# PowerShell のエラーハンドリング設定
$ErrorActionPreference = "Stop"

# TLS 1.2 を強制的に有効にする (パッケージプロバイダー等のダウンロードエラーを回避するため)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# カラー出力用の簡易ヘルパー
function Write-LogInfo { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-LogSuccess { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-LogWarning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-LogError { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# プラットフォーム判別
$myIsWindows = $PSVersionTable.Platform -eq "Win32NT" -or $env:OS -like "*Windows*"
$myIsLinux = -not $myIsWindows
$pathSeparator = [IO.Path]::PathSeparator

# 必要な基本ツールの確認 (Linux環境でのみ検証)
if ($myIsLinux) {
    foreach ($cmd in @("git", "curl", "tar")) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Write-LogError "$cmd がインストールされていません。インストールしてから再度実行してください。"
            exit 1
        }
    }
}

# 必要なディレクトリの作成
$zshDir = "$HOME/.zsh"
$localBinDir = "$HOME/.local/bin"
Write-LogInfo "必要なディレクトリを作成しています..."
$null = New-Item -ItemType Directory -Force -Path $zshDir
$null = New-Item -ItemType Directory -Force -Path $localBinDir

# 一時的に PATH に追加してインストール直後の検証を可能にする
if ($env:PATH -notlike "*$localBinDir*") {
    $env:PATH = "${localBinDir}${pathSeparator}${env:PATH}"
}

# --- 1. fzf のセットアップ ---
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-LogInfo "fzf が見つかりません。インストールを開始します..."
    if ($myIsLinux) {
        $fzfDir = "$HOME/.fzf"
        if (-not (Test-Path $fzfDir)) {
            git clone --depth 1 https://github.com/junegunn/fzf.git $fzfDir
        } else {
            Write-LogInfo "既存の fzf リポジトリを更新しています..."
            git -C $fzfDir pull
        }
        & "$fzfDir/install" --bin
        $null = New-Item -ItemType SymbolicLink -Path "$localBinDir/fzf" -Value "$fzfDir/bin/fzf" -Force
        Write-LogSuccess "fzf を Linux にインストールしました。"
    } else {
        # Windows環境でのインストール (winget を試行)
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-LogInfo "winget を使用して fzf をインストールしています..."
            winget install --id junegunn.fzf --silent --accept-source-agreements --accept-package-agreements | Out-Null
            Write-LogSuccess "fzf をインストールしました。反映にはシェルの再起動が必要な場合があります。"
        } else {
            Write-LogWarning "Windows環境ですが winget が見つかりません。`winget install junegunn.fzf` 等で手動インストールしてください。"
        }
    }
} else {
    Write-LogSuccess "fzf は既にインストールされています。"
}

# --- 2. starship のセットアップ ---
if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
    Write-LogInfo "starship が見つかりません。インストールを開始します..."
    if ($myIsLinux) {
        curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir $localBinDir
        Write-LogSuccess "starship を Linux にインストールしました。"
    } else {
        # Windows環境でのインストール (winget を試行)
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-LogInfo "winget を使用して starship をインストールしています..."
            winget install --id Starship.Starship --silent --accept-source-agreements --accept-package-agreements | Out-Null
            Write-LogSuccess "starship をインストールしました。反映にはシェルの再起動が必要な場合があります。"
        } else {
            Write-LogWarning "Windows環境ですが winget が見つかりません。`winget install Starship.Starship` 等で手動インストールしてください。"
        }
    }
} else {
    Write-LogSuccess "starship は既にインストールされています。"
}

# --- 3. zellij のセットアップ ---
if (-not (Get-Command zellij -ErrorAction SilentlyContinue)) {
    Write-LogInfo "zellij が見つかりません。インストールを開始します..."
    if ($myIsLinux) {
        $arch = (uname -m)
        $target = ""
        if ($arch -eq "x86_64") {
            $target = "x86_64-unknown-linux-musl.tar.gz"
        } elseif ($arch -eq "aarch64") {
            $target = "aarch64-unknown-linux-musl.tar.gz"
        }

        if ($target -ne "") {
            Write-LogInfo "GitHub から最新の zellij バイナリをロードしています..."
            $zellijReleaseJson = curl -sL https://api.github.com/repos/zellij-org/zellij/releases/latest
            $url = ($zellijReleaseJson | Select-String -Pattern "https://github.com/zellij-org/zellij/releases/download/[^\`"]*" -AllMatches).Matches.Value | Select-String -Pattern $target | Select-Object -First 1
            
            if ($url) {
                curl -L $url -o /tmp/zellij.tar.gz
                tar -xzf /tmp/zellij.tar.gz -C $localBinDir zellij
                Remove-Item /tmp/zellij.tar.gz
                Write-LogSuccess "zellij を Linux にインストールしました。"
            } else {
                Write-LogError "zellij のダウンロードURLの取得に失敗しました。"
            }
        } else {
            Write-LogWarning "未対応のアーキテクチャ ($arch) のため、zellij の自動インストールをスキップしました。"
        }
    } else {
        # Windowsネイティブ環境でのインストール (winget または 公式のPowerShellスクリプト)
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-LogInfo "winget を使用して zellij-windows をインストールしています..."
            winget install --id arndawg.zellij-windows --silent --accept-source-agreements --accept-package-agreements | Out-Null
            Write-LogSuccess "zellij をインストールしました。反映にはシェルの再起動が必要な場合があります。"
        } else {
            Write-LogInfo "launch.ps1 スクリプトを使用して zellij をインストールしています..."
            $null = Invoke-RestMethod https://zellij.dev/launch.ps1 | Invoke-Expression
            Write-LogSuccess "zellij をインストールしました。"
        }
    }
} else {
    Write-LogSuccess "zellij は既にインストールされています。"
}

# --- 4. PSFzf モジュールのインストール (fzf が古い場合のバックアップ用) ---
# ※ 最近の fzf (v0.48.0以降) は fzf 単体で --powershell 統合を提供しているため、
# モジュールが不要な場合もありますが、古い fzf との互換性のためにインストールは試行します。
Write-LogInfo "PSFzf モジュールを確認しています..."
if (-not (Get-Module -ListAvailable -Name PSFzf)) {
    Write-LogInfo "PSFzf モジュールをインストールしています..."
    # NuGetプロバイダーの確認とインストール
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        try {
            $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        } catch {
            Write-LogWarning "NuGet パッケージプロバイダーの自動インストールに失敗しました。既に適用されているか、手動での導入が必要な場合があります。"
        }
    }
    try {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        $null = Install-Module -Name PSFzf -Scope CurrentUser -Force
        Write-LogSuccess "PSFzf モジュールをインストールしました。"
    } catch {
        Write-LogWarning "PSFzf モジュールのインストールに失敗しました。fzf単体の統合機能を使用します。"
    }
} else {
    Write-LogSuccess "PSFzf モジュールは既にインストールされています。"
}

# --- PowerShell プロファイルの設定 ---
# プロファイル用ディレクトリの作成
$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) {
    $null = New-Item -ItemType Directory -Force -Path $profileDir
}

# プロファイルに書き込む設定ブロック
$profileBlock = @"

# ==========================================
# Fish-like environment settings for PowerShell
# ==========================================

# --- 環境変数 PATH の設定 ---
`$localBinDir = "`$HOME/.local/bin"
`$pathSeparator = [IO.Path]::PathSeparator
if (`$env:PATH -notlike "*`$localBinDir*") {
    `$env:PATH = "`$localBinDir`${pathSeparator}`$env:PATH"
}

# --- PSReadLine 設定 (Autosuggestions, History Search, Highlighting) ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    # Fishスタイルの履歴プレフィックス検索 (上下矢印キー)
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Fishスタイルの履歴予測 (Inline表示)
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView

    # 予測テキストの色を薄いグレーに設定
    Set-PSReadLineOption -Colors @{
        InlinePrediction = "`e[38;5;244m"
    }

    # Tabキーで補完メニューを表示 (Fishライクな挙動)
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# --- fzf 連携 (公式 powershell オプション優先、フォールバックとして PSFzf) ---
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    `$hasPowerShellOpt = `$false
    try {
        `$help = fzf --help 2>&1 | Out-String
        if (`$help -like "*--powershell*") {
            `$hasPowerShellOpt = `$true
        }
    } catch {}

    if (`$hasPowerShellOpt) {
        # fzf本体が提供する公式のPowerShell統合 (v0.48.0以降)
        Invoke-Expression (& fzf --powershell)
    } elseif (Get-Module -ListAvailable -Name PSFzf) {
        # 古いfzf環境用の PSFzf 連携
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

# --- starship プロンプト ---
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# --- zellij 連携 ---
if (Get-Command zellij -ErrorAction SilentlyContinue) {
    # 自動起動を有効にしたい場合は、以下のコメントアウトを解除するか、
    # `$env:ZELLIJ_AUTO_START = "true"` を設定してください。
    # `$env:ZELLIJ_AUTO_START = "true"

    if (`$env:ZELLIJ -eq `$null -and `$env:SSH_CONNECTION -eq `$null -and `$env:ZELLIJ_AUTO_START -eq "true") {
        # pwsh プロセスを zellij に置き換える
        exec zellij
    }
}
"@

if (Test-Path $PROFILE) {
    # 以前の古い設定ブロックを削除するために上書きまたはチェック
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -like "*Fish-like environment settings for PowerShell*") {
        Write-LogWarning "既にプロファイルに本スクリプトの設定が存在します。古い設定を上書き更新します。"
        # 古い設定を削除（簡易的に置換。改行コードやスペースの差異を考慮して (?ms) を使用）
        $cleanContent = $profileContent -replace "(?ms)# ==========================================.*?# --- zellij 連携 ---.*?exec zellij\s*\r?\n\s*\}\s*\r?\n\s*\}", ""
        $cleanContent = $cleanContent.Trim()
        Set-Content -Path $PROFILE -Value "$cleanContent`n$profileBlock"
        Write-LogSuccess "プロファイルの設定を更新しました。"
    } else {
        Add-Content -Path $PROFILE -Value "`n$profileBlock"
        Write-LogSuccess "既存のプロファイル設定に追記しました。"
    }
} else {
    $null = New-Item -ItemType File -Path $PROFILE -Force
    Set-Content -Path $PROFILE -Value $profileBlock
    Write-LogSuccess "新しいプロファイルを作成し、設定を書き込みました。"
}

Write-Host ""
Write-LogSuccess "PowerShell (pwsh) のセットアップが完了しました！"
Write-LogInfo "設定を反映させるには、PowerShell を再起動するか、以下を実行してください："
Write-Host "   . `$PROFILE"
Write-Host ""
