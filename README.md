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
        Supported Components: `HDAudio, PhysX`                   
        |Argument|Description|
        |-|-| 
        |`-DriverPackage <Driver Package File>` | NVIDIA driver package file to extract.|
        | `-Setup` | Launch the NVIDIA Driver Setup|
        | `-Full`|Extract a Full Driver Package|
        | `-Components <Component-1,Component-2, ...>`| Extract Driver Specific Components.|

    - `Invoke-NvidiaDriverPackage`: **Download a driver package**
        |Argument|Description|
        |-|-| 
        |`-NvidiaGpu <Get-NvidiaGpu>` | Pass a variable which has a `Get-NvidaGpu` Object.|
        | `-Version <Version>` | Set which version to download.|
        | `-Studio` | Studio driver type.|
        | `-Standard` | Standard driver type.|
        | `-Setup` | Launch the NVIDIA Driver Setup.|
        | `-Full`|Extract a Full Driver Package|
        | `-Components <Component-1,Component-2, ...>` | Extract Driver Specific Components. |
    
    - `Get-NvidiaDriverVersions`: **Get NVIDIA Driver Versions.**    
        |Argument|Description|
        |-|-| 
        |`-NvidiaGpu <Get-NvidiaGpu>` | Pass a variable which has a `Get-NvidaGpu` Object.|
        | `-Studio` | Studio driver type.|
        | `-Standard` | Standard driver type.|

    - `Get-NvidiaGpuProperties` **Get information on Dynamic P-State, HDCP and NVIDIA Control Panel & NVIDIA Display Container LS Service Telemetry.**

    - `Set-NvidiaGpuProperty`: **Configure a NVIDIA GPU property.**
        |Argument|Description|
        |-|-|
        |`-Property`| Specify the property to configure.|
        |`-State`| Configure the state of the specified property, `1` for enabling the property and `0` for disabling it.|

        |Property|Description|
        |-|-|
        |`DynamicPState`| This property determines if a NVIDIA GPU should dynamically clock itself.|
        |`HDCP`|This property determines if HDCP is enabled for DRM content.|