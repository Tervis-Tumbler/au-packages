$ErrorActionPreference = 'Stop'

$PackageName = 'office365-2016-deployment-tool'
$url       = 'https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_7614-3602.exe'
$checksum  = 'CB9B41ABF4C3D67D082BA534F757A0C84F7CA4AF89D77590CC58290B7C875F5E'
$PackageVersion  = '16.0.7614.3602'

$ErrorActionPreference = 'Stop';

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$installConfigFileLocation = $(Join-Path $toolsDir 'install.xml')
$uninstallConfigFileLocation = $(Join-Path $toolsDir 'uninstall.xml')
$ignoreExtractFile = "officedeploymenttool.exe.ignore"
$ignoreSetupFile = "setup.exe.ignore"

# Argument defaults
$arch = 32
$sharedMachine = 0
$logPath = "%TEMP%"

$arguments = @{}

$packageParameters = $env:chocolateyPackageParameters

if ($packageParameters) {
    $match_pattern = "\/(?<option>([a-zA-Z]+)):(?<value>([`"'])?([a-zA-Z0-9- _\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z0-9]+))"
    $option_name = 'option'
    $value_name = 'value'

    if ($packageParameters -match $match_pattern ){
        $results = $packageParameters | Select-String $match_pattern -AllMatches
        $results.matches | % {
            $arguments.Add(
                $_.Groups[$option_name].Value.Trim(),
                $_.Groups[$value_name].Value.Trim())
        }
    }
    else
    {
        Throw "Package Parameters were found but were invalid (REGEX Failure)"
    }

    if ($arguments.ContainsKey("64bit")) {
        Write-Host "Installing 64-bit version."
        $arch = 64
    } else {
        Write-Host "Installing 32-bit version."
    }

    if ($arguments.ContainsKey("Shared")) {
        Write-Host "Installing with Shared Computer Licensing for Remote Desktop Services."
        $sharedMachine = 1
    }

    if ($arguments.ContainsKey("LogPath")) {
        Write-Host "Installation log in directory $($arguments['LogPath'])"
        $logPath = $arguments["LogPath"]
    }

    if ($arguments.ContainsKey("Lang")) {
        Write-Host "Installing additional Languages $($arguments['Lang'])"
        $lang = $arguments["Lang"]
    }

} else {
    Write-Debug "No Package Parameters Passed in"
    Write-Host "Installing 32-bit version."
    Write-Host "Installing language variant MatchOS."
    Write-Host "Installation log in directory %TEMP%"
}

function Get-PreInstalledOfficeVersionArch () {
    $installedVersion = $null
    $installedArch = $null
    
    $installedOffice32 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | `
        foreach { Get-ItemProperty $_.PSPath } | `
        Where-Object { $_ -match "Microsoft Office*" }

    $installedOffice64 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | `
        foreach { Get-ItemProperty $_.PSPath } | `
        Where-Object { $_ -match "Microsoft Office*" }

    if ($installedOffice32) {
        $installedArch = 32
        [int]$installedVersion = $installedOffice32.DisplayVersion.Split(".")[0]
    } elseif ($installedOffice64) {
        $installedArch = 32
        [int]$installedVersion = $installedOffice64.DisplayVersion.Split(".")[0]
    }

    $officeVersionArch = @{"Version" = $installedVersion; "Architecture" = $installedArch}

    return $officeVersionArch
}

$PreinstalledOfficeVersionArch = Get-PreInstalledOfficeVersionArch

if ($PreinstalledOfficeVersionArch.Version -ne $null) {
    if ($PreinstalledOfficeVersionArch.Version -eq $packageVersion.Split(".")[0]) {
        Write-Error "This version of Office is already installed. Please uninstall prior installations to continue."
    } 
    if ($PreinstalledOfficeVersionArch.Architecture -ne $arch) {
        Write-Error "$($PreinstalledOfficeVersionArch.Architecture)-bit Office previously installed. `
        Cannot install Office $arch-bit without removing Office $($PreinstalledOfficeVersionArch.Architecture)-bit first."
    }
}

[xml]$installConfigData = @"
<Configuration>
  <Add OfficeClientEdition="$arch">
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
    </Product>
  </Add>  
  <Display Level="None" AcceptEULA="TRUE" />  
  <Logging Level="Standard" Path="$logPath" /> 
  <Property Name="SharedComputerLicensing" Value="$sharedMachine" />  
</Configuration>
"@

[xml]$uninstallConfigData = @"
<Configuration>
  <Remove>
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
    </Product>
  </Remove>
  <Display Level="None" AcceptEULA="TRUE" />  
  <Logging Level="Standard" Path="$logPath" /> 
  <Property Name="FORCEAPPSHUTDOWN" Value="True" />
</Configuration>
"@

If($lang){
    $lang = $lang.Replace("'","").Split()
    foreach($la in $lang){
    $language = $installConfigData.CreateElement('Language')
    $language.SetAttribute("ID",$la)
    $installConfigData.Configuration.Add.Product.AppendChild($language)
    $unnstallConfigData.Configuration.Add.Product.AppendChild($language)
    }   
}

$installConfigData.Save($installConfigFileLocation)
$uninstallConfigData.Save($uninstallConfigFileLocation)

New-Item -Path $toolsDir -Name $ignoreSetupFile -ItemType File
New-Item -Path $toolsDir -Name $ignoreExtractFile -ItemType File

$extractPackage = Get-ChocolateyWebFile -PackageName $packageName -FileFullPath "$toolsDir\officedeploymenttool.exe" -Url $url -Checksum $checksum -ChecksumType SHA256

$statements = "/extract:$toolsDir /quiet /norestart"

$setupPackageArgs = @{
  packageName = $packageName
  fileType = 'EXE'
  file = $(Join-Path $toolsDir "setup.exe")
  silentArgs = "/configure $installconfigFileLocation"
}

Start-ChocolateyProcessAsAdmin -Statements "$statements" -ExeToRun $extractPackage

Install-ChocolateyInstallPackage @setupPackageArgs
