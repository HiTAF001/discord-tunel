' Discord'u tunelle, konsol penceresi gostermeden acar.
Set fso = CreateObject("Scripting.FileSystemObject")
klasor = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & klasor & "\Discord_Baslat.ps1""", 0, False
