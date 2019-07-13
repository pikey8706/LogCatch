Set ws = CreateObject("Wscript.Shell")

Set objFso = CreateObject("Scripting.FileSystemObject")

Const SETUP_BATCH = "src\setup_path_for_windows.bat"
Const RUN_BATCH = "src\logcatch.bat"

If objFso.FileExists(SETUP_BATCH) Then

    Private updateRunBatch
    If objFso.FileExists(RUN_BATCH) Then
        Set runFile = objFso.GetFile(RUN_BATCH)
        Set setupFile = objFso.GetFile(SETUP_BATCH)
        if runFile.DateLastModified < setupFile.DateLastModified Then
            updateRunBatch = True
        End If
    Else
        updateRunBatch = True
    End If

    if updateRunBatch Then
        ws.run "cmd /c " & SETUP_BATCH, vbhide
        WScript.Sleep 2500
    End If

End If

If objFso.FileExists(RUN_BATCH) Then
    ws.run "cmd /c" & RUN_BATCH, vbhide
End If

