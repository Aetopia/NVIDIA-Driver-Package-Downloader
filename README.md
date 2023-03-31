# NVIDIA Driver Package Downloader (NVDPD)

A simple PowerShell script to extract and download NVIDIA driver packages.

# Usage

1. Open PowerShell as an Admin.
2. Copy and paste the following command:
    ```ps
    irm "https://raw.githubusercontent.com/Aetopia/NVIPS/main/NVDPD.ps1" | iex
    ```
3. Once the command executes, you can any of the following commands.
    1. `Get-NvidiaGpu`: **Query NVIDIA GPU Info.**

    2. `Expand-NvidiaDriverPackage`: **Extract a NVIDIA driver package.**
        |Argument|Description|
        |-|-| 
        |`-DriverPackage <DriverPackage>` | NVIDIA driver package file to extract.|
        | `-Setup` | Launch the NVIDIA Driver Setup|
        | `-Components <Components>`| Extract Driver Specific Components.|

    3. `Invoke-NvidiaDriverPackage`: **Download a driver package**
        |Argument|Description|
        |-|-| 
        |`-NvidiaGpu <Get-NvidaGpu>` | Pass a variable which has a `Get-NvidaGpu` Object.|
        | `-Version <Version>` | Set which version to download.|
        | `-Studio` | Studio driver type.|
        | `-Standard` | Standard driver type.|
        | `-Setup` | Launch the NVIDIA Driver Setup.|
        | `-Components <Components>` | Extract Driver Specific Components. |