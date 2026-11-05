# 把论文 Markdown 渲染成 PDF（pandoc + xelatex）
#
#   用法（在仓库根目录）：
#       pwsh ML_EnergyStorage_Optimization/src/make_pdf.ps1              # 中文稿
#       pwsh ML_EnergyStorage_Optimization/src/make_pdf.ps1 -Lang en     # 英文稿
#
#   依赖：pandoc（winget install JohnMacFarlane.Pandoc）、TeX Live（xelatex）、
#         中文字体 Microsoft YaHei UI（Windows 自带）。
#
#   说明：
#   - -f markdown-implicit_figures 关掉 pandoc 自动图注，否则图下方会出现
#     "Figure 3: 图3" 这样的重复标题；
#   - pandoc-subs.lua 把 ₁/₂ 之类的下标字符转成 LaTeX 数学下标，YaHei 缺这些字形；
#   - --resource-path 让 ../CCES_CHP_Simulink 与 data/ 里的图片能被找到。

param(
    [ValidateSet("zh", "en")]
    [string]$Lang = "zh"
)

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = Split-Path -Parent $here          # ML_EnergyStorage_Optimization
$md = if ($Lang -eq "zh") { "paper_manuscript_zh.md" } else { "paper_manuscript.md" }
$pdf = [IO.Path]::ChangeExtension($md, ".pdf")

$pandoc = @(
    "$env:LOCALAPPDATA\Pandoc\pandoc.exe",
    "$env:ProgramFiles\Pandoc\pandoc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $pandoc) { throw "找不到 pandoc：winget install JohnMacFarlane.Pandoc" }
if (-not (Get-Command xelatex -ErrorAction SilentlyContinue)) { throw "找不到 xelatex：需要 TeX Live" }

Push-Location $dir
try {
    # Windows PowerShell 5.1 把原生程序写到 stderr 的“警告”当作 terminating error，
    # 因此调用 pandoc 期间临时放宽 ErrorActionPreference，只用退出码判定失败。
    $ErrorActionPreference = "Continue"
    # 先写临时文件：目标 PDF 可能正被 Acrobat/Edge 打开而无法覆盖。
    $tmp = Join-Path $dir ("~" + $pdf)
    $log = & $pandoc $md -o $tmp `
        -f markdown-implicit_figures `
        --pdf-engine=xelatex `
        --lua-filter "$here\pandoc-subs.lua" `
        -V CJKmainfont="Microsoft YaHei UI" `
        -V mainfont="Times New Roman" `
        -V monofont="Microsoft YaHei UI" `
        -V fontsize=11pt `
        -V geometry:"margin=2.4cm" `
        -V linestretch=1.25 `
        --toc --toc-depth=2 `
        --resource-path=. 2>&1

    $code = $LASTEXITCODE
    $warn = ($log | Select-String "Missing character").Count
    if ($code -ne 0) {
        $log | Select-Object -Last 20 | Write-Host
        throw "pandoc 退出码 $code"
    }
    if ($warn -gt 0) { Write-Host "注意：$warn 处缺字形（检查字体或源码里的特殊字符）" }

    $target = Join-Path $dir $pdf
    try {
        Move-Item -LiteralPath $tmp -Destination $target -Force -ErrorAction Stop
        $final = $target
    }
    catch {
        # 目标被占用：另存为带时间戳的文件，不打断工作流
        $ts = Get-Date -Format "yyyyMMdd-HHmm"
        $final = Join-Path $dir ([IO.Path]::GetFileNameWithoutExtension($pdf) + ".$ts.pdf")
        Move-Item -LiteralPath $tmp -Destination $final -Force
        Write-Host "目标文件被占用（可能正在阅读器中打开），已另存为："
    }
}
finally {
    Pop-Location
    $ErrorActionPreference = "Stop"
}

$size = [math]::Round((Get-Item $final).Length / 1KB)
Write-Host "OK  $(Split-Path -Leaf $final)  ($size kB)"
