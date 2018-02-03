Set ws = CreateObject("Wscript.Shell")

Set objFso = CreateObject("Scripting.FileSystemObject")

If Not objFso.FileExists("src\logcatch.bat") And objFso.FileExists("src\setup_path_for_windows.bat") Then
    ws.run "cmd /c src\setup_path_for_windows.bat", vbhide
    WScript.Sleep 2500
End If

If objFso.FileExists("src\logcatch.bat") Then
    ws.run "cmd /c src\logcatch.bat", vbhide
End If

