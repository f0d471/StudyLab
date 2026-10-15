param([switch]$Elevated)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$linkPath = Join-Path $projectRoot 'Main\nemu\src\isa\riscv64'
$targetPath = Join-Path $projectRoot 'Main\nemu\src\isa\riscv32'
$resultPath = Join-Path $projectRoot 'logs\native-link-restore.json'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($Elevated) { throw 'Administrator token is required to create a native Windows symbolic link' }
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Elevated'
    $worker = Start-Process -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru -Wait
    if ($worker.ExitCode -ne 0) { throw 'Native link restoration failed; the administrator operation did not complete' }
    Get-Content -LiteralPath $resultPath
    exit 0
}
$expectedLink = [IO.Path]::GetFullPath((Join-Path $projectRoot 'Main\nemu\src\isa\riscv64'))
if ($linkPath -ne $expectedLink -or -not (Test-Path -LiteralPath $targetPath -PathType Container)) { throw 'Unexpected link or target path' }
$sourceRepo = Join-Path $projectRoot 'Main'
$indexRecord = & 'E:\Software\Git\cmd\git.exe' -C $sourceRepo ls-files --stage -- nemu/src/isa/riscv64
if ($LASTEXITCODE -ne 0 -or $indexRecord -notmatch '^120000 4eb3f6daab2ef3ef15fad5ad1e108d38a6dda653 0') { throw 'The staged upstream link identity is not the expected riscv32 target' }
$item = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
if ($null -ne $item) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { throw 'Refusing to replace an ordinary file or directory' }
    $linuxTarget = & wsl.exe -d Ubuntu --exec readlink /mnt/wsl-sandbox/ysyx/Main/nemu/src/isa/riscv64
    if ($LASTEXITCODE -ne 0 -or $linuxTarget.Trim() -ne 'riscv32') { throw 'The current link has an unexpected target' }
}
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class YsyxNativeLinkRestoreApi {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    [return: MarshalAs(UnmanagedType.U1)]
    public static extern bool CreateSymbolicLink(string path, string target, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool RemoveDirectory(string path);
}
"@
if ($null -ne $item) {
    if (-not [YsyxNativeLinkRestoreApi]::RemoveDirectory($linkPath)) { throw ('Cannot remove the link itself: '+[Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
}
if (-not [YsyxNativeLinkRestoreApi]::CreateSymbolicLink($linkPath,'riscv32',1)) { throw ('Cannot create native relative link: '+[Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
$item = Get-Item -LiteralPath $linkPath -Force
if ($item.LinkType -ne 'SymbolicLink' -or @($item.Target)[0] -ne 'riscv32') { throw 'Native link type or relative target mismatch' }
$record = [ordered]@{completedUtc=[DateTime]::UtcNow.ToString('o');path='Main/nemu/src/isa/riscv64';target='riscv32';type='native Windows directory symbolic link';deletedTargetDirectory=$false}
[IO.File]::WriteAllText($resultPath,($record|ConvertTo-Json -Depth 3)+"`n",(New-Object Text.UTF8Encoding($false)))
