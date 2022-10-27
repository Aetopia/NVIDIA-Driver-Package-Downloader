$global:ProgressPreference = "SilentlyContinue"

function Get-NVGPU {
    param ([switch]$studio, [switch]$standard)

    $whql, $dtcid, $vers, $devs, $type, $gpu = 1, 1, @(), @(), $null, $null

    if ($studio) {
        $whql = 4
    }
    if ($standard) {
        $dtcid = 0
    }

    # Detect NVIDIA Hardware.
    $pciids = (Invoke-RestMethod "https://raw.githubusercontent.com/pciutils/pciids/master/pci.ids").Split("`n")
    $gpus = (Invoke-RestMethod "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3").LookupValueSearch.LookupValues.LookupValue
    
    if ($null -eq $hwids) {
        $hwids = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI" | ForEach-Object {
            $hwid = (Split-Path -Leaf $_.Name)
            if ($hwid.startswith("VEN_10DE")) {
                (($hwid -Split "VEN_10DE&DEV_") -Split "&SUBSYS")[1].Trim().ToLower()
            }
        } 
    }

    foreach ($i in $pciids) {
        if ($i.startswith("10de")) {
            $nvidia = $true
        }
        elseif ($i.StartsWith("10df")) {
            break
        }
        if ($nvidia) {
            if (($i[0] -eq "`t") -and ($i[1] -ne "`t")) {
                $id, $name = ($i.Trim("`t").Split(" ", 2))
                foreach ($hwid in $hwids) {
                    if ($hwid -eq $id) {
                        $devs += $name.Trim().Split(" ", 2)[1].TrimStart("[").TrimEnd("]").Trim()
                    }
                }
            }
        }
    }
    :master foreach ($i in $gpus) {
        foreach ($dev in $devs) {
            $name, $dev = $i.Name.ToLower().TrimStart("nvidia").Trim(), $dev.ToLower().Trim()
            if ($dev -like "$($name)*") {
                if ($name.startswith("quadro")) {
                    $type = "Quadro"
                }
                elseif ($name.startswith("rtx")) {
                    $type = "Telsa"
                }
                else {
                    $type = "GeForce"
                }
                $gpu = $i
                break master
            }
        }
    }

    if (-Not($null -eq $gpu)) { 
        # Get Driver Versions.
        $link = "https://www.nvidia.com/Download/processFind.aspx?psid=$($gpu.ParentID)&pfid=$($gpu.Value)&osid=57&lid=1&whql=$whql&ctk=0&dtcid=$dtcid"
        $f = (Invoke-RestMethod "$link").Split("`n") | ForEach-Object { $_.Trim() }
        
        foreach ($i in $f) {
            if (($i -like "<td class=""gridItem"">*.*</td>") -and ($i -notlike "<td class=""gridItem"">*`<img*")) {
                $i = $i.Trim("<td class=""gridItem"">").Trim("</td>")
                if ($i -like "*(*)*") {
                    $i = $i.Split("(", 2)[1].Trim(")")
                }
                $vers += [string]$i.Trim()
            }
        }
    }
    return [ordered]@{
        GPU      = $gpu.Name; 
        Versions = $($vers | Sort-Object -Descending); 
        Type     = $type; 
        Debug    = [ordered]@{
            Devices = $devs; 
            HWIDS   = ($hwids | ForEach-Object { $_.ToUpper() });
            Link    = $link 
        } 
    }
}

function Invoke-NVDriver {
    param(
        [string]$version, 
        [switch]$studio, 
        [switch]$standard, 
        [string]$directory = "$ENV:TEMP", 
        [switch]$full, 
        [switch]$info
    )

    if ($null -eq $gpu) { $gpu = Get-NVGPU -studio:$studio -standard:$standard }
    $channel, $nsd, $type, $dir = '', '', '-dch', $directory
    $plat = 'desktop'
    
    if ((get-wmiobject Win32_SystemEnclosure).ChassisTypes -in @(8, 9, 10, 11, 12, 14, 18, 21)) {
        $plat = 'notebook'
    }

    if ($version -eq "") {
        $version = $gpu.Versions[0]
    }

    if ($studio) {
        $nsd = '-nsd'
    }
    if ($standard) {
        $type = ''
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

    $output, $success = "$dir\NVIDIA - $version.exe", $false

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
    Expand-NVDriver -file "$output" -dir "$dir" -full:$full  


}
function Expand-NVDriver {
    param([string]$file, [string]$directory = "$ENV:TEMP", [switch]$full)
    $dir = "$directory"
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
    Set-Content "$ENV:TEMP\nvcpl.txt" "$output\Display.Driver\NVCPL" -Encoding UTF8
    Start-Process "$output\setup.exe" -ErrorAction Ignore
}

function Install-NVCPL {
    if (-Not(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Please run this script as an Administrator!" -ForegroundColor Red
    }
    Set-Service "NVDisplay.ContainerLocalSystem" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service "NVDisplay.ContainerLocalSystem" -ErrorAction SilentlyContinue
    $txt = "$ENV:TEMP\nvcpl.txt"
    if (-Not(Test-Path "$txt")) {
        Write-Error "Please download and extract a driver package using Invoke-NVDriver | Expand-NVDriver!" -ErrorAction Stop
    }
    $appx = ((Get-ChildItem (Get-Content "$txt" -Encoding UTF8) | Where-Object { $_ -like "*.appx" }).FullName)
    $zip = "$(Split-Path $appx)\$((Get-Item $appx).BaseName).zip"  
    $dir = "$ENV:PROGRAMDATA\NVIDIA Corporation\NVCPL"
    $url = "$ENV:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\NVIDIA Control Panel.url"
    foreach ($i in ($dir, $url)) {
        Remove-Item "$i" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Copy-Item "$appx" "$zip"
    Expand-Archive "$zip" "$dir" -Force | Out-Null
    Write-Output "Fetching NVIDIA Control Panel Launcher..."
    curl.exe -#L "$((Invoke-RestMethod "https://api.github.com/repos/Aetopia/NVIPS/releases/latest").assets.browser_download_url)" -o "$dir\nvcpl.exe"
    Set-Content "$url" "[InternetShortcut]`nURL=file:///$dir\nvcpl.exe`nIconIndex=0`nIconFile=$dir\nvcplui.exe" -Encoding UTF8
    Write-Output "NVIDIA Control Panel Installed!"
}