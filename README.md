LogCatch
===
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
- Download zip file: https://github.com/pikey8706/LogCatch/archive/master.zip
- unzip LogCatch-master.zip
- open LogCatch-master folder.
- Right click in folder.
- click Git bash (Here) menu.
- type below in bash window.
<pre>
wish LogCatch.tcl
</pre>

To see log from devices after app launched, do below please.
- you should select android-sdk-directory or adb including directory from popup window.
- click "Devices" button to see device list connected to usb. after click Devices,
 devices name will list in "Source:".
- click Device name then log will be shown in window.

![ScreenShot](https://{github.com/pikey8706/LogCatch/screenshot.png})

Author:
Hirohito Sasaki
email: pikey8706@gmail.com

Icon-Author:
Designed by Freepik
