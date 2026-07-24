# sync-unity.ps1
# 单向同步 src/unity -> unity/My project/Assets/Scripts
# 保留 Unity 侧 .meta（引用关联），仅同步 .cs/.asmdef 源码。
# 用法：
#   powershell -ExecutionPolicy Bypass -File sync-unity.ps1          # 执行
#   powershell -ExecutionPolicy Bypass -File sync-unity.ps1 -DryRun  # 仅预览

param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = Join-Path $root "src\unity"
$dst = Join-Path $root "unity\My project\Assets\Scripts"

if (-not (Test-Path $src)) { Write-Error "源目录不存在: $src"; exit 1 }
if (-not (Test-Path $dst)) { Write-Error "目标目录不存在: $dst"; exit 1 }

$excludeFiles = @("*.meta", "*.md", "*.csproj", "*.sln")
$excludeDirs  = @(".git")

function Invoke-Robo {
    param([string]$from, [string]$to, [switch]$Mirror)
    $args = [System.Collections.Generic.List[string]]::new()
    $args.Add($from); $args.Add($to)
    if ($Mirror) { $args.Add("/MIR") }
    foreach ($f in $excludeFiles) { $args.Add("/XF"); $args.Add($f) }
    foreach ($d in $excludeDirs)  { $args.Add("/XD"); $args.Add($d) }
    $args.Add("/NFL"); $args.Add("/NDL"); $args.Add("/NJS"); $args.Add("/NJH")
    if ($DryRun) { $args.Add("/L") }
    Write-Host ("[{(0)}] {1} -> {2}" -f $(if ($DryRun) {'DRY'} else {'SYNC}'), $from, $to)
    & robocopy @args
    # robocopy 退出码 0-7 视为成功
    if ($LASTEXITCODE -ge 8) { Write-Error "robocopy 失败 (code $LASTEXITCODE)"; exit $LASTEXITCODE }
}

# 1) Features 子树：镜像（删除目标中源已删的文件），但保留 .meta
Invoke-Robo -from "$src\Features" -to "$dst\Features" -Mirror

# 2) 顶层 .cs（如 CoreSmokeTest.cs）：仅复制，不删目标（保护 Core 目录等 Unity 独有内容）
Invoke-Robo -from $src -to $dst

Write-Host ""
Write-Host ("完成。" + $(if ($DryRun) {'（DRY-RUN，未实际写入）'} else {''}))
