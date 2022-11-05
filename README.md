# NVIDIA Installer PowerShell (NVIPS)

A simple powershell script to extract and download NVIDIA driver packages.

# Usage

1. Open PowerShell as an Admin.
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
        2. `-Directory <Directory>` | Output Directory (Default > `%TEMP%`)

    3. `Invoke-NVDriver` | Download a driver package but extract the display driver only.
        1. `-Version <Version>` | Set which version to download
        2. `-Studio` | Studio driver type.
        3. `-Standard` | Standard driver type.
        4. `-Directory <Directory>` | Output Directory
        5. `-Full` | Download an entire driver package. 
    
    4. `Install-NVCPL` | Install the NVIDIA Control Panel.                
        By default this function installs the NVIDIA Control Panel as a Win32 app.            
        - `-UWP` | Install the NVIDIA Panel as a UWP app.

# NVIDIA Control Panel Launcher
This program serves the launcher for the NVIDIA Control Panel, although you don't need it for the control panel itself, it essentially supresses the `NVIDIA Control Panel is not installed!` prompt from popping up since the UWP control panel isn't installed.

## Building
1. Install Nim using: https://github.com/dom96/choosenim
    > Run the tool 2 ~ 3 times to ensure it is correctly installed on your system.          
    > If Nim isn't in your system's `PATH`, reboot.

2. Run the following command to compile the launcher:

   ```cmd
   nim c -d:release --app:gui --opt:size nvcpl.nim
   ```
   >Optional: Compress using UPX.
   >```
   >upx -8 nvcpl.exe
   >```
3. Now simply extract the NVIDIA Control Panel APPX package as a `.zip` archive.              
   Can be found in `Display.Driver\NVCPL` within an extracted driver package.
4. Place `nvcpl.exe` in the directory and run it.
