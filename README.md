# LogCatch
android adb logcat viewer for Linux/Mac/Windows

This is written in tcl/tk.

Spec:
- Colored log. logtype detection is supported. like time threadtime brief process, and eclipse copied, studio copied logs. 
- Fitering by keywords. This is done by awk regular expression like awk '/key|word/ {print}'
- Searching highlighting.
- Saving log.
- Can read saved log in a file. (Coloring OK)
- show adb logcat log forma a device.

Dependency
 You need to prepare wish, awk, and adb.

Linux:
tk package, android-sdk for adb, awk.

Mac:
android-sdk for adb

Windows:
bash, wish, awk, android-sdk for adb.
I recommed to install msys-git. This contains git, bash, awk.

To start
type in bash:
wish LogCatch.tcl

