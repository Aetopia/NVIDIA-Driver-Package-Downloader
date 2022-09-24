# NVIDIA Installer PowerShell (NVIPS)

A simple powershell script to extract and download NVIDIA driver packages.

# Usage

1. Open PowerShell.
2. Copy and paste the following command:
    ```ps
    irm "https://raw.githubusercontent.com/Aetopia/NVIPS/main/NVIPS.ps1" | iex
    ```
3. Once the command executes, you can any of the following commands.
    1. `Get-NVGPU -Studio -Standard` | Query NVIDIA GPU Info
        1. `-Studio` | Studio driver type.
        2. `-Standard` | Standard driver type.

    2. `Expand-NVDriver` |  Extract a NVIDIA driver package.
        1. `-File <file>` | NVIDIA driver package file to extract. 
        2. `-Directory <Directory>` | Output Directory (Default > `%TEMP%)

    3. `Invoke-NVDriver` | Download a driver package but extract the display driver only.
        1. `-Version <Version>` | Set which version to download
        2. `-Studio` | Studio driver type.
        3. `-Standard` | Standard driver type.
        4. `-Directory <Directory>` | Output Directory
        5. `-Full` | Download an entire driver package. 