# NVIDIA Driver Package Downloader (NVDPD)

A simple PowerShell script to extract and download NVIDIA driver packages.

# Usage

1. Open PowerShell as an Admin.
2. Copy and paste the following command:
    ```ps
    irm "https://raw.githubusercontent.com/Aetopia/NVIPS/main/NVDPD.ps1" | iex
    ```
3. Once the command executes, you can any of the following commands.
    - `Get-NvidiaGpu`: **Query NVIDIA GPU Info.**

    - `Expand-NvidiaDriverPackage`: **Extract a NVIDIA driver package.**
        |Argument|Description|
        |-|-| 
        |`-DriverPackage <Driver Package File>` | NVIDIA driver package file to extract.|
        | `-Setup` | Launch the NVIDIA Driver Setup|
        | `-Components <Components>`| Extract Driver Specific Components.|

    - `Invoke-NvidiaDriverPackage`: **Download a driver package**
        |Argument|Description|
        |-|-| 
        |`-NvidiaGpu <Get-NvidaGpu>` | Pass a variable which has a `Get-NvidaGpu` Object.|
        | `-Version <Version>` | Set which version to download.|
        | `-Studio` | Studio driver type.|
        | `-Standard` | Standard driver type.|
        | `-Setup` | Launch the NVIDIA Driver Setup.|
        | `-Components <Components>` | Extract Driver Specific Components. |
    
    - `Get-NvidiaGpuProperties` | Get information on Dynamic P-State, HDCP and NVIDIA Control Panel & NVIDIA Display Container LS Service Telemetry.

    - `Set-NvidiaGpuProperty` | Configure a Nvidia GPU property.
        |Argument|Description|
        |-|-|
        |`-Property`| Specify the property to configure.|
        |`-State`| Configure the state of the specified property, `1` for enabling the property and `0` for disabling it.|

        |Property|Description|
        |-|-|
        |`DynamicPState`| This property determines if a NVIDIA GPU should dynamically clock itself.|
        |`HDCP`|This property determines if HDCP is enabled for DRM content.| 
        |`NVCPLTelemetry`|This property determines if NVIDIA Control Panel has telemetry enabled or not.
        |`NVSTelemetry`|This property determines if the NVIDIA Display Container LS Service has telemetry enabled or not.|