Name
===
LogCatch
android adb logcat viewer for Linux/Mac/Windows

This is written in tcl/tk.

Spec:
- Colored log. logtype detection is supported. like time threadtime brief process, and eclipse copied, studio copied logs. 
- Filtering by keywords. This is done by awk regular expression like awk '/key|word/ {print}'
- Searching keyword and highlighting it.
- Saving log.
- Can read saved logs in a file.
- View adb logcat logs from a device.

## Requirement
You need to prepare commands: wish, awk, and adb.

Linux:
tk package, android-sdk for adb, awk.

Mac:
android-sdk for adb

Windows:
bash, wish, awk, android-sdk for adb.
I recommed to install msys-git. This contains git, bash, awk, wish.

## Install
Linux:
pacman -S awk tk android-tools

Mac:
prepare android-sdk

Windows:
I tested my-app on msysgit enviroment.
Install from : https://git-for-windows.github.io/
Or active tcl may work().

## Usage
To boot app

Linux/Mac user
<pre>
wish LogCatch.tcl
</pre>

Windows user
Assuming you have done installed msys-git.
1. Download zip file: https://github.com/pikey8706/LogCatch/archive/master.zip
2. unzip LogCatch-master.zip
3. open LogCatch-master folder.
4. Right click in folder.
5. click Git bash (Here) menu.
6. type below in bash window.
<pre>
wish LogCatch.tcl
</pre>

To see log from devices after app launched, do below please.
1. you should select android-sdk-directory or adb including directory from popup window.
2. click "Devices" button to see device list connected to usb. after click Devices,
 devices name will list in "Source:".
3. click Device name then log will be shown in window.

Author:
Hirohito Sasaki
email: pikey8706@gmail.com

Icon-Author:
Designed by Freepik
