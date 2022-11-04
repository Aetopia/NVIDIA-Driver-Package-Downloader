# Launcher for NVIDIA Control Panel
import os, osproc
import winlean
import strutils

if isMainModule:
    const svc = "NVDisplay.ContainerLocalSystem"
    setCurrentDir(getAppDir())
    if not isAdmin(): 
        discard shellExecutew(0, newWideCString("runas"), newWideCString(getAppFilename()), nil, nil, 0)
        quit(0)
    for cmd in ["sc config $1 start=demand", "sc start $1", "sc config $1 start=disabled"]: 
        discard execCmdEx(cmd % svc, options={poDaemon})
    while true: 
        for i in execCmdEx("tasklist /SVC /FO CSV", options={poDaemon}).output.strip(chars={'\n'}).splitLines():
            if "NVDisplay.Container.exe" == i.split("\",")[0].strip(chars={'"'}).strip():
                discard waitForExit(startProcess("nvcplui.exe"), -1)
                discard execCmdEx("sc stop $1" % svc, options={poDaemon})
                quit(0)