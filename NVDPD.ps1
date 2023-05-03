if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator Permissions Required."
    return 
}

function Split-String (
    [Parameter(Mandatory = $True)][string]$String, 
    [Parameter(Mandatory = $True)][string]$Delimiter,
    [int]$MaxSubStrings = 0) {
    return $String -Split "$Delimiter", $MaxSubStrings, "SimpleMatch"
}

function Remove-Parentheses (
    [Parameter(Mandatory = $True)][string]$String,
    [Parameter(Mandatory = $True)][string] $A, 
    [Parameter(Mandatory = $True)][string]$B) { 
    return (Split-String (Split-String $String $A 2)[1] $B 2)[0].Trim()
}

function Get-NvidiaGpu {
    $EnumPCIKey = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\PCI"
    $InstalledNvidiaDeviceIds = (Get-ChildItem "Registry::$EnumPCIKey").Name | ForEach-Object { 
        $VendorId, $DeviceId = Split-String (Split-String (Split-String $_ "$EnumPCIKey\" 2)[1].Trim() "&SUBSYS" 2)[0].TrimStart("VEN_") "&DEV_" 2
        if ($VendorId -eq "10DE") { $DeviceId }
    }
    $ApiNvidiaGpus = (Invoke-RestMethod "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3").LookupValueSearch.LookupValues.LookupValue
    
    $LinuxSupportedNvidiaGpus = (Split-String (
            Invoke-RestMethod "https://download.nvidia.com/XFree86/Linux-x86_64/$((
            Split-String (Invoke-RestMethod "https://download.nvidia.com/XFree86/Linux-x86_64/latest.txt") " " -MaxSubStrings 2)[0]
            )/README/supportedchips.html"
        ) "`n") | ForEach-Object { $_.Trim() }

    foreach ($Index in 0..( $LinuxSupportedNvidiaGpus.Length - 1)) {
        $Line = $LinuxSupportedNvidiaGpus[$Index]
        if ($Line -notlike "<tr id=`"devid*`">" -or 
            $Line -like "<tr id=`"devid*_*`">") { continue }
        $GpuName = Remove-Parentheses $LinuxSupportedNvidiaGpus[$Index + 1] ">" "<"
        $DeviceId = Remove-Parentheses $LinuxSupportedNvidiaGpus[$Index + 2] ">" "<"
        if ($DeviceId -notin $InstalledNvidiaDeviceIds) { continue }
        foreach ($Gpu in $ApiNvidiaGpus) {
            if (!$GpuName.EndsWith($Gpu.Name)) { continue }
            return [ordered]@{
                "Gpu"  = $Gpu.Name;
                "Psid" = $Gpu.ParentID;
                "Pfid" = $Gpu.Value;
            }
        }
        break
    } 
    Write-Error "No NVIDIA GPU found." -ErrorAction Stop
}

function Get-NvidiaDriverVersions (
    [hashtable]$NvidiaGpu = (Get-NvidiaGpu),
    [switch]$Studio, 
    [switch]$Standard) {
    $Whql = "1"
    $Dtcid = "1"
    if ($Studio) { $Whql = "4" }
    if ($Standard) { $Dtcid = "0" }
    return Split-String (
        Invoke-RestMethod "https://www.nvidia.com/Download/processFind.aspx?psid=$($NvidiaGpu.Psid)&pfid=$($NvidiaGpu.Pfid)&osid=57&lid=1&whql=$Whql&ctk=0&dtcid=$Dtcid") "`n" | 
    ForEach-Object { $_.Trim() } | 
    Where-Object { $_ -like "<td class=""gridItem"">*.*</td>" -and $_ -notlike "<td class=""gridItem"">*`<img*" } |
    ForEach-Object {
        $Version = Remove-Parentheses $_ ">" "<"
        if ($Version -like "*(*)*") { $Version = Remove-Parentheses $Version "(" ")" }
        $Version 
    } | Sort-Object -Descending
}

function Invoke-NvidiaDriverPackage (
    [hashtable]$NvidiaGpu = (Get-NvidiaGpu),
    [string]$Version = (Get-NvidiaDriverVersions $NvidiaGpu -Studio: $Studio -Standard: $Standard)[0],
    [switch]$Studio, 
    [switch]$Standard,
    [switch]$Setup,
    [switch]$Full,
    [array]$Components = @()) {
    $DriverName = [System.Collections.ArrayList]@("Game Ready", "DCH")
    $Channel, $NSD = "", ""
    $Platform = "desktop"
    $Type = "-dch"

    if ($Studio) { 
        $NSD = "-nsd"
        $DriverName[0] = "Studio" 
    }
    if ($Standard) { 
        $Type = ""
        $DriverName[1] = "Standard" 
    }
    if ((Get-CimInstance Win32_SystemEnclosure).ChassisTypes -in @(8, 9, 10, 11, 12, 14, 18, 21)) { $Platform = "notebook" }

    if ($NvidiaGpu.Gpu.StartsWith("Quadro")) {
        $Channel = 'Quadro_Certified/'
        $Platform = 'quadro-rtx-desktop-notebook'
    }
    elseif ($NvidiaGpu.Gpu.StartsWith("RTX")) {
        $Platform = 'data-center-tesla-desktop'
    }

    $Output = "$ENV:TEMP\NVIDIA - $DriverName $Version.exe"

    foreach ($WindowsVersion in @("win10-win11", "win10")) {
        $DownloadLink = "https://international.download.nvidia.com/Windows/$Channel$Version/$Version-$Platform-$WindowsVersion-64bit-international$NSD$Type-whql.exe"
        try { 
            if ((Invoke-WebRequest -UseBasicParsing -Method Head -Uri $DownloadLink).StatusCode -eq 200) {
                Write-Output "GPU: $($NvidiaGpu.Gpu)
Driver Type: $($DriverName -Join " ")
Downloading: `"$(Split-Path $Output -Leaf)`""
                if (Get-Command "curl.exe" -ErrorAction SilentlyContinue) { 
                    curl.exe -#L "$DownloadLink" -o `"$Output`"
                }
                else {
                    Write-Output "Warning: Curl isn't available. Using PowerShell to download driver package."
                    (New-Object System.Net.WebClient).DownloadFile($DownloadLink, $Output)
                }
                Write-Output "Finished: Driver Package Downloaded."
                Expand-NvidiaDriverPackage $Output -Full: $Full -Setup: $Setup $Components
            }
        }
        catch [System.Net.WebException] {}
    }
}

function Expand-NvidiaDriverPackage (
    [Parameter(Mandatory = $True)]$DriverPackage,
    [switch]$Setup,
    [switch]$Full,
    [array]$Components = @()) {
    $ComponentsFolders = "Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe"
    $DriverPackage = (Resolve-Path $DriverPackage)
    $Output = (Split-String $DriverPackage (Get-Item $DriverPackage).Extension 2)[0]
    $7Zip = "$ENV:TEMP\7zr.exe"
    $SetupCfg = "$Output\setup.cfg"
    $PresentationsCfg = "$Output/NVI2/presentations.cfg"
    if ($Full) {
        Write-Output "Extraction Options: Full Driver Package" 
        $ComponentsFolders = "" 
    }
    elseif ($Components -and !$Full) {
        Write-Output "Extraction Options: Display Driver | $($Components -Join " | ")"
        $Components | ForEach-Object {
            switch ($_) {
                "PhysX" { $ComponentsFolders += " $_" }
                "HDAudio" { $ComponentsFolders += " $_" }
                default { Write-Error "Invalid Component." -ErrorAction Stop } 
            }
        }
    }

    Write-Output "Extracting: `"$DriverPackage`""
    Write-Output "Extraction Directory: `"$Output`""
    Remove-Item $Output -Recurse -Force -ErrorAction SilentlyContinue
    (New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/7zr.exe", $7Zip)
    Invoke-Expression "& `"$7Zip`" x -bso0 -bsp1 -bse1 -aoa `"$DriverPackage`" $ComponentsFolders -o`"$Output`"" 

    $SetupCfgContent = [System.Collections.ArrayList](Get-Content $SetupCfg -Encoding Ascii)
    foreach ($Index in 0..($SetupCfgContent.Count - 1)) {
        if ($SetupCfgContent[$Index].Trim() -in @('<file name="${{EulaHtmlFile}}"/>', 
                '<file name="${{FunctionalConsentFile}}"/>'
                '<file name="${{PrivacyPolicyFile}}"/>')) { 
            $SetupCfgContent[$Index] = "" 
        }
    }
    Set-Content $SetupCfg $SetupCfgContent -Encoding Ascii

    $PresentationsCfgContent = [System.Collections.ArrayList](Get-Content $PresentationsCfg -Encoding Ascii)
    foreach ($Index in 0..($PresentationsCfgContent.Count - 1)) {
        foreach ($String in @('<string name="ProgressPresentationUrl" value=',
                '<string name="ProgressPresentationSelectedPackageUrl" value=')) {
            if ($PresentationsCfgContent[$Index] -like "`t`t$String*") {
                $PresentationsCfgContent[$Index] = "`t`t$String`"`"/>"
            }
        }
    }
    Set-Content $PresentationsCfg $PresentationsCfgContent -Encoding Ascii

    Write-Output "Finished: Driver Package has been Extracted."
    if ($Setup) {
        Start-Process "$Output\setup.exe" -ErrorAction SilentlyContinue
    }
}

function Get-NvidiaGpuProperties {
    $NvidiaGpuProperties = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\????" -ErrorAction SilentlyContinue | 
    Where-Object { $_.MatchingDeviceId.StartsWith("pci\ven_10de") }
    return [ordered]@{
        "Key"             = $NvidiaGpuProperties.PSPath.TrimStart("Microsoft.PowerShell.Core\Registry::")
        "Dynamic P-State" = !$NvidiaGpuProperties.DisableDynamicPstate
        "HDCP"            = !$NvidiaGpuProperties.RMHdcpKeyglobZero
    };
}

function Set-NvidiaGpuProperty (
    [Parameter(Mandatory = $True)]
    [ValidateSet("DynamicPState", "HDCP")]
    [string]$Property,
    [Parameter(Mandatory = $True)][bool]$State) {
    $Key = (Get-NvidiaGpuProperties).Key 
    $Value = (![int]$State)
    if ($Key) {
        switch ($Property.Trim()) {
            "DynamicPState" { New-ItemProperty "Registry::$Key" "DisableDynamicPstate" -Value $Value -PropertyType DWORD -Force } 
            "HDCP" { New-ItemProperty "Registry::$Key" "RMHdcpKeyglobZero" -Value $Value -PropertyType DWORD -Force } 
        }
    };
}