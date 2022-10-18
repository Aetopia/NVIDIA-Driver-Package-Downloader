# Launcher for NVIDIA Control Panel
import os, osproc, winlean, winim/com
setCurrentDir(getAppDir())
if not isAdmin(): 
    discard shellExecutew(0, newWideCString("runas"), newWideCString(getAppFilename()), nil, nil, 5)
    quit(0)
var (wmi, query) = (GetObject("winmgmts:"), "SELECT * FROM Win32_Service WHERE Name='NVDisplay.ContainerLocalSystem'")
var svc = wmi.ExecQuery(query).ItemIndex(0)
svc.ChangeStartMode("Manual")
svc.StartService()
svc.ChangeStartMode("Disabled")
while true: 
    sleep(1)
    if wmi.ExecQuery(query).ItemIndex(0).State == "Running": break
discard waitForExit(startProcess("nvcplui.exe"), -1)
svc.StopService()