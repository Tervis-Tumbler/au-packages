$ErrorActionPreference = 'Stop'

$PackageName = 'prometheus-blackbox-exporter'
$url32       = 'https://github.com/prometheus/blackbox_exporter/releases/download/v0.17.0/blackbox_exporter-0.17.0.windows-386.tar.gz'
$url64       = 'https://github.com/prometheus/blackbox_exporter/releases/download/v0.17.0/blackbox_exporter-0.17.0.windows-amd64.tar.gz'
$checksum32  = '9d89342fe27e2bdd46ade6630d6f06310e7ae526f36abf9726d6574b63cb5f8c'
$checksum64  = '80493a5baaacd236ade4ba593a1f0c9dfd53207518fc8c6b4a5a563af1ca2b59'

$packageArgs = @{
  packageName    = $packageName
  url            = $url32
  url64Bit       = $url64
  checksum       = $checksum32
  checksum64     = $checksum64
  checksumType   = 'sha256'
  checksumType64 = 'sha256'
  unzipLocation  = Split-Path $MyInvocation.MyCommand.Definition
}
Install-ChocolateyZipPackage @packageArgs
$File = Get-ChildItem -File -Path $env:ChocolateyInstall\lib\$packageName\tools\ -Filter *.tar
Get-ChocolateyUnzip -fileFullPath $File.FullName -destination $env:ChocolateyInstall\lib\$packageName\tools\

$ServiceName = 'prometheus-blackbox-exporter'

Write-Host "Installing service"

if ($Service = Get-Service $ServiceName -ErrorAction SilentlyContinue) {
    if ($Service.Status -eq "Running") {
        Start-ChocolateyProcessAsAdmin "stop $ServiceName" "sc.exe"
    }
    Start-ChocolateyProcessAsAdmin "delete $ServiceName" "sc.exe"
}

$ExporterExe = Get-ChildItem -File -Path $(Join-Path $File.DirectoryName $File.basename) -Filter *.exe
Start-ChocolateyProcessAsAdmin "install $ServiceName $($ExporterExe.FullName)" nssm
Start-ChocolateyProcessAsAdmin "set $ServiceName Start SERVICE_DEMAND_START" nssm
