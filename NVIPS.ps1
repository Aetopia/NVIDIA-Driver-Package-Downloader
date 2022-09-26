function Get-NVGPU {
    param ([switch]$studio, [switch]$standard)

    $whql, $dtcid, $vers, $devs, $quadro, $gpu = 1, 1, @(), @(), $false, $null

    if ($studio) {
        $whql = 0
    }
    if ($standard) {
        $dtcid = 0
    }

    # Detect NVIDIA Hardware.
    $pciids = (Invoke-RestMethod "https://raw.githubusercontent.com/pciutils/pciids/master/pci.ids").Split("`n")
    $gpus = (Invoke-RestMethod "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3").LookupValueSearch.LookupValues.LookupValue
    $hwids = foreach ($key in (Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\PCI")) {
        $hwid = (Split-Path -Leaf $key.Name)
        if ($hwid.startswith("VEN_10DE")) {
            (($hwid -Split "VEN_10DE&DEV_") -Split "&SUBSYS")[1].Trim().ToLower()
        }
    } 
    for ($i = 0; $i -ne $pciids.length; $i++) {
        $x = $pciids[$i]
        if (!($x.startswith("#"))) {
            if ($x.startswith("10de")) {
                for ($j = $i; $j -ne $pciids.length; $j++) {
                    $y = $pciids[$j]
                    if (!($y.startswith("#"))) {
                        if (!($y.startswith("10df"))) {
                            if (!($y.startswith("`t`t"))) {
                                $id, $name = ($y.Trim("`t").Split(" ", 2))
                                foreach ($hwid in $hwids) {
                                    if ($hwid -eq $id) {
                                        $devs += $name.Trim().Split(" ", 2)[1].TrimStart("[").TrimEnd("]").Trim()
                                    }
                                }
                            }
                        }
                        else {
                            break
                        }
                    }
                }
                break
            }
        }
    }
    foreach ($i in $gpus) {
        foreach ($dev in $devs) {
            if ($i.Name -eq $dev) {
                if ($i.Name.ToLower() -like "*quadro*") {
                    $quadro = $true
                }
                $gpu = $i
                break
            }
        }
    }

    if ($null -eq $gpu) {Write-Error "Couldn't detect NVIDIA GPU." -ErrorAction Stop}
    # Get Driver Versions.
    $link = "https://www.nvidia.com/Download/processFind.aspx?psid=$($gpu.ParentID)&pfid=$($gpu.Value)&osid=57&lid=1&whql=$whql&ctk=0&dtcid=$dtcid"
    $f = (Invoke-RestMethod "$link").Split("`n") | ForEach-Object { $_.Trim() }
    
    foreach ($i in $f) {
        if (($i -like "<td class=""gridItem"">*.*</td>") -and ($i -notlike "<td class=""gridItem"">*`<img*")) {
            $i = $i.Trim("<td class=""gridItem"">").Trim("</td>")
            if ($i -like "*(*)*") {
                $i = $i.Split("(", 2)[1].Trim(")")
            }
            $vers += [float]$i
        }
    }
    return [ordered]@{GPU = $gpu.Name; Versions = $($vers | Sort-Object -Descending); Quadro = $quadro }
}

function Invoke-NVDriver {
    param([float]$version, [switch]$studio, [switch]$standard, [string]$directory = "$ENV:TEMP", [switch]$full)

    $gpu = Get-NVGPU -studio:$studio -standard:$standard
    $channel, $nsd, $type, $dir = '', '', '-dch', $directory
    $plat, $quadro = 'desktop', $gpu.Quadro
    
    if ((get-wmiobject Win32_SystemEnclosure).ChassisTypes -in @(8, 9, 10, 11, 12, 14, 18, 21)) {
        $plat = 'notebook'
    }

    if ($version -eq 0) {
        [string] $version = $gpu.Versions[0]
    }

    if ($studio) {
        $nsd = '-nsd'
    }
    if ($standard) {
        $type = ''
    }
    if ($quadro) {
        $channel = 'Quadro_Certified/'
        $plat = 'quadro-rtx-desktop-notebook'
    }

    $output = "$dir\NVIDIA - $version.exe"

    foreach ($winver in @("win10-win11", "win10")) {
        $link = "https://international.download.nvidia.com/Windows/$channel$version/$version-$plat-$winver-64bit-international$nsd$type-whql.exe"
        try { 
            if ((Invoke-WebRequest -UseBasicParsing -Method Head -Uri "$link").StatusCode -eq 200) {
                curl.exe -L -# "$link" -o "$output" 
            }
        }
        catch [System.Net.WebException] {}
    }
    if ($full -eq $true) {
        cmd.exe /c "explorer.exe /select,""$output"""
    }
    else {
        Expand-NVDriver -file "$output" -dir "$dir"  
    }

}

function Expand-NVDriver {
    param([string]$file, [string]$directory = "$ENV:TEMP")
    $dir = "$directory"
    $components = "Display.Driver NVI2 EULA.txt ListDevices.txt setup.cfg setup.exe"
    $output = "$dir\$(((Split-Path -Leaf "$file") -split ".exe", 2, "simplematch").Trim())".Trim()
    if ((Test-Path "$output")) {
        Remove-Item "$output" -Force -Recurse
    }
    $7zr = "$ENV:TEMP\7zr.exe"

    curl.exe -s "https://www.7-zip.org/a/7zr.exe" -o "$7zr"
    cmd.exe /c """$7zr"" x -bso0 -bsp1 -bse1 -aoa ""$file"" $components -o""$output"""

    $fp = "$output/setup.cfg"
    $f = [System.Collections.ArrayList]((Get-Content "$fp" -Encoding UTF8) -Split "`n")
    foreach ($i in @('<file name="${{EulaHtmlFile}}"/>', 
            '<file name="${{PrivacyPolicyFile}}"/>', 
            '<file name="${{FunctionalConsentFile}}"/>', "")) {
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
    cmd.exe /c "explorer.exe /select,""$output\setup.exe"""
}

