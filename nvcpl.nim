# Launcher for NVIDIA Control Panel
import os, osproc, winlean, winim/com
setCurrentDir(getAppDir())
if not isAdmin(): 
    discard shellExecutew(0, newWideCString("runas"), newWideCString(getAppFilename()), nil, nil, 5)
    quit(0)
var svc = GetObject("winmgmts:").ExecQuery("SELECT * FROM Win32_Service WHERE Name='NVDisplay.ContainerLocalSystem'").ItemIndex(0)
svc.ChangeStartMode("Manual")
svc.StartService()
svc.ChangeStartMode("Disabled")
while svc.State == "OK": discard
discard waitForExit(startProcess("nvcplui.exe"), -1)
svc.StopService()