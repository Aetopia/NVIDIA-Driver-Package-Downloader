$global:ProgressPreference = "SilentlyContinue"
if (-Not(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as an Administrator!"
}
if ($null -eq (Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" | Where-Object { $_.Name -like "*10DE*" })) { 
    Write-Error "No NVIDIA GPU found!"
}

function Get-NVGPU ([switch]$studio, [switch]$standard) {

    $driver = [System.Collections.ArrayList]@("Game Ready", "DCH")
    $whql, $dtcid = 1, 1
    $vers, $devs = @(), [ordered]@{}
    $type = "GeForce"
    if ($studio) { $whql = 4; $driver[0] = "Studio" }
    if ($standard) { $dtcid = 0; $driver[1] = "Standard" }

    # Detect NVIDIA Hardware.
    $pciids = (Invoke-RestMethod "https://raw.githubusercontent.com/pciutils/pciids/master/pci.ids").Split("`n")
    $gpus = (Invoke-RestMethod "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3").LookupValueSearch.LookupValues.LookupValue
    
    $hwids = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" | ForEach-Object {
        $hwid = (Split-Path -Leaf $_.Name)
        if ($hwid.startswith("VEN_10DE")) {
            (($hwid -Split "VEN_10DE&DEV_") -Split "&SUBSYS")[1].Trim().ToLower()
        }
    } 

    foreach ($i in $pciids) {
        if ($i.startswith("10de")) { $nvidia = $true }
        elseif ($i.StartsWith("10df")) { break }
        if ($nvidia) {
            if (($i[0] -eq "`t") -and ($i[1] -ne "`t")) {
                $id, $name = ($i.Trim("`t").Split(" ", 2))
                foreach ($hwid in $hwids) {
                    if ($hwid -eq $id) {
                        $devs[$hwid] += $name.Trim().Split(" ", 2)[1].TrimStart("[").TrimEnd("]").Trim()
                    }
                }
            }
        }
    }
    :master foreach ($i in $gpus) {
        foreach ($hwid in $devs.Keys) {
            $name, $dev = $i.Name.ToLower().TrimStart("nvidia").Trim(), $devs[$hwid].ToLower().Trim()
            if ($dev -like "$($name)*") {
                if ($name.startswith("quadro")) { $type = "Quadro" }
                elseif ($name.startswith("rtx")) { $type = "Telsa" }
                $gpu = $i
                break master
            }
        }
    }

    if (-Not($null -eq $gpu)) { 
        # Get Driver Versions.
        $link = "https://www.nvidia.com/Download/processFind.aspx?psid=$($gpu.ParentID)&pfid=$($gpu.Value)&osid=57&lid=1&whql=$whql&ctk=0&dtcid=$dtcid"
        $f = (Invoke-RestMethod "$link").Split("`n") | ForEach-Object { $_.Trim() }
        
        foreach ($l in $f) {
            if (($l -like "<td class=""gridItem"">*.*</td>") -and ($l -notlike "<td class=""gridItem"">*`<img*")) {
                $l = $l.Trim("<td class=""gridItem"">").Trim("</td>")
                if ($l -like "*(*)*") { $l = $i.Split("(", 2)[1].Trim(")") }
                $vers += [string]$l.Trim()
            }
        }
    }
    return [ordered]@{
        GPU      = $gpu.Name
        Versions = $($vers | Sort-Object -Descending)
        Driver   = $driver -join " "
        Type     = $type
        Debug    = [ordered]@{
            HWID = $hwid.ToUpper()
            Link = $link 
        } 
    }
}

function Invoke-NVDriver {
    param(
        [hashtable]$gpu,
        [string]$version, 
        [switch]$studio, 
        [switch]$standard, 
        [string]$directory = "$ENV:TEMP", 
        [switch]$full,
        [switch]$slient
    )

    if ($null -eq $gpu) { $gpu = Get-NVGPU -studio:$studio -standard:$standard }
    $channel = $nsd = ''
    $type, $dir = '-dch', $directory
    $plat = 'desktop'
    if ($version -eq "") { $version = $gpu.Versions[0] }
    if ($studio) { $nsd = '-nsd' }
    if ($standard) { $type = '' }
    if ((get-wmiobject Win32_SystemEnclosure).ChassisTypes -in @(8, 9, 10, 11, 12, 14, 18, 21)) {
        $plat = 'notebook'
    }

    switch ($gpu.Type) {    
        "Quadro" {
            $channel = 'Quadro_Certified/'
            $plat = 'quadro-rtx-desktop-notebook'
        }
        "Telsa" {
            $plat = 'data-center-tesla-desktop'
        }
    }

    $output, $success = "$dir\NVIDIA - $($gpu.Driver) $version.exe", $false

    foreach ($winver in @("win10-win11", "win10")) {
        $link = "https://international.download.nvidia.com/Windows/$channel$version/$version-$plat-$winver-64bit-international$nsd$type-whql.exe"
        try { 
            if ((Invoke-WebRequest -UseBasicParsing -Method Head -Uri "$link").StatusCode -eq 200) {
                $success = $true
                curl.exe -#L "$link" -o "$output"
            }
        }
        catch [System.Net.WebException] {}
    }
    if (!($success)) {
        Write-Error "Couldn't find driver version $version.".Trim() -ErrorAction Stop
    }
    Expand-NVDriver -file "$output" -dir "$dir" -full:$full  -silent:$slient
}

function Expand-NVDriver {
    param(
        [string]$file, 
        [string]$directory = "$ENV:TEMP", 
        [switch]$full,
        [switch]$silent
    )

    $dir = $directory
    $components = "Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe"
    if ($full) { $components = "" }
    $output = "$dir\$(((Split-Path -Leaf "$file") -split ".exe", 2, "simplematch").Trim())".Trim()
    Remove-Item -Path "$output" -Recurse -Force -ErrorAction SilentlyContinue
    if ((Test-Path "$output")) {
        Remove-Item "$output" -Recurse -Force -ErrorAction SilentlyContinue
    }

    $7zr = "$ENV:TEMP\7zr.exe"
    curl.exe -s "https://www.7-zip.org/a/7zr.exe" -o "$7zr"
    Invoke-Expression "& ""$7zr"" x -bso0 -bsp1 -bse1 -aoa ""$file"" $components -o""$output"""

    $fp = "$output/setup.cfg"
    $f = [System.Collections.ArrayList]((Get-Content "$fp" -Encoding UTF8) -Split "`n")
    foreach ($i in @('<file name="${{EulaHtmlFile}}"/>', 
            '<file name="${{PrivacyPolicyFile}}"/>', 
            '<file name="${{FunctionalConsentFile}}"/>')) {
        $f.Remove("`t`t$i")
    }
    Set-Content "$fp" -Value $f -Encoding UTF8

    $fp = "$output/NVI2/presentations.cfg"
    $f = [System.Collections.ArrayList]((Get-Content "$fp" -Encoding UTF8) -Split "`n")
    $x, $index = @('<string name="ProgressPresentationUrl" value=', '<string name="ProgressPresentationSelectedPackageUrl" value='), @()
    foreach ($i in $x) {
        foreach ($j in $f) {
            if ($j -like "`t`t$i*") {
                $index += $f.IndexOf($j)
            }
        }
    }
    for ($i = 0 ; $i -ne $index.length; $i++) {
        $f[$index[$i]] = "`t`t$($x[$i]) """"/>"
    }
    Set-Content "$fp" -Value $f -Encoding UTF8
    if ($slient -eq $false) { 
        try { Start-Process "$output\setup.exe" -ErrorAction SilentlyContinue }
        catch [System.InvalidOperationException] {}
    }
}

function Install-NVCPL ([switch]$uwp) {
    $file = "$ENV:TEMP\NVCPL.zip"
    $dir = "$ENV:PROGRAMDATA\NVIDIA Corporation\NVCPL"
    $lnk = "$ENV:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\NVIDIA Control Panel.lnk"
    if ($uwp) { $file = "$file.appx" }
    if ($null -eq (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "NVIDIA*" })) { Write-Error "No NVIDIA GPU found." -ErrorAction Stop }

    # Disable Telemetry.
    reg.exe add "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" /v "OptInOrOutPreference" /t REG_DWORD /d 0 /f 
    reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" /v "SendTelemetryData" /t REG_DWORD /d 0 /f

    # Using rg-adguard to fetch the latest version of the NVIDIA Control Panel.
    $body = @{
        type = 'url'
        url  = "https://apps.microsoft.com/store/detail/nvidia-control-panel/9NF8H0H7WMLT"
        ring = 'RP'
        lang = 'en-US' 
    }
    Write-Output "Getting the latest version of the NVIDIA Control Panel from the Microsoft Store..."
    $link = ((Invoke-RestMethod -Method Post -Uri "https://store.rg-adguard.net/api/GetFiles" -ContentType "application/x-www-form-urlencoded" -Body $body) -Split "`n" | 
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -like ("*http://tlu.dl.delivery.mp.microsoft.com*") } |
        ForEach-Object { ((($_ -split "<td>", 2, "SimpleMatch")[1] -Split "rel=", 2, "SimpleMatch")[0] -Split "<a href=", 2, "SimpleMatch")[1].Trim().Trim('"') })[-1]
    curl.exe -#L "$link" -o "$file"

    if ($uwp) {
        Write-Output "Installing the NVIDIA Control Panel as a UWP app..."
        Add-AppxPackage "$file" -ForceApplicationShutdown -ForceUpdateFromAnyVersion
        Write-Output "NVIDIA Control Panel Installed!"
        return
    }

    Write-Output "Installing the NVIDIA Control Panel as a Win32 app..."
    # Disable the NVIDIA Root Container Service. The NVIDIA Control Panel Launcher runs the service when the NVIDIA Control Panel is launched.
    Set-Service "NVDisplay.ContainerLocalSystem" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "NVDisplay.ContainerLocalSystem" -Force -ErrorAction SilentlyContinue
    foreach ($i in ($dir, $lnk)) { Remove-Item "$i" -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive "$file" "$dir" -Force

    # This launcher is needed inorder to suppress the annoying pop-up that the UWP Control Panel isn't installed.
    curl.exe -#L "$((Invoke-RestMethod "https://api.github.com/repos/Aetopia/NVIPS/releases/latest").assets.browser_download_url)" -o "$dir\nvcpl.exe"
    $wsshell = New-Object -ComObject "WScript.Shell"
    $shortcut = $wsshell.CreateShortcut("$lnk")
    $shortcut.TargetPath = "$dir\nvcpl.exe"
    $shortcut.IconLocation = "$dir\nvcplui.exe, 0"
    $shortcut.Save()
    Write-Output "NVIDIA Control Panel Installed!"
}

function Get-NVGPUProperty {
    # MSI Mode
    $pci = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\PCI"
    $gpu = "$(Split-Path $pci)\$(((Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "NVIDIA*" }).PNPDeviceID -Split "&SUBSYS", 2, "SimpleMatch")[0])"

    $hwid = (Get-ChildItem "Registry::$(Get-ChildItem "Registry::$pci" | Where-Object {$_.Name -like "$gpu*"})").Name
    $msimode = Get-ItemPropertyValue "Registry::$hwid\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" -Name "MSISupported"
    
    $dev = (Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue).Name | 
    Where-Object { $_ -like "*000*" } |
    ForEach-Object { Get-ItemProperty "Registry::$_" } | 
    Where-Object { $_.ProviderName -like "*NVIDIA*" } 
    
            
    return [ordered]@{
        "MSI Mode"        = if ($msimode) { $true } else { $false }
        "Dynamic P State" = if ($dev.DisableDynamicPstate) { $false } else { $true }
        "HDCP"            = if ($dev.RMHdcpKeyglobZero) { $false } else { $true }
        "Info"            = @{"HWID" = $hwid; "Device" = Convert-Path $dev.PSPath }
    }
}

function Set-NVGPUProperty ([string]$Name, [switch]$switch) {}