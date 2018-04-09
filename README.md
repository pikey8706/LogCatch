LogCatch
===
Log viewer for Linux/Mac/Windows.
First desigend for android adb logcat viewer.
Now you can use this for general log viewer by easy filtering and highlighting.
This is written in tcl/tk.

Spec:
- Colored log. logtype detection is supported. like time threadtime brief process, and eclipse copied, studio copied logs. 
- Filtering by keywords. This is done by awk regular expression like awk '/key|word/ {print}'
- Searching keyword and highlighting it.
- Saving log.
- Can read saved logs in a file.
- View adb logcat logs from a device.

## Requirement
You need to prepare commands: wish, awk, and adb(for android).

Linux:
awk for filtering, tk package for GUI, and android-sdk for adb.

Mac:
android-sdk for adb.

Windows:
bash, wish, awk, android-sdk for adb.
I recommed to install msys-git. This contains git, bash, awk, wish.
No warranty for subsystem-linux on windows 10. Only mysy-git is supported.

## Install
Linux:
pacman -S awk tk android-tools
apt-get install awk tk android-tools

Mac:
prepare android-sdk

Windows:
I tested my-app on msysgit enviroment.
Install from : https://git-for-windows.github.io/
Or active tcl may work().

## Usage
To launch app

Linux/Mac user
- git clone https://github.com/pikey8706/LogCatch.git
- open LogCatch folder.
- Just W-click [runOnShell].
<pre>
on terminal.
$ runOnShell
or
$ wish src/LogCatch.tcl --dir src
</pre>

Windows user
Assuming you have done installed msys-git.
- git clone https://github.com/pikey8706/LogCatch.git
or
- Download zip file: https://github.com/pikey8706/LogCatch/archive/master.zip
- unzip LogCatch-master.zip
- open LogCatch-master folder.
- Just W-click [LogCatch_winLauncher.vbs]. This automatically resolve path for wish/bash/awk in msys-git windows enviroment.
- Please create shortcut lancher by yourself.

To see log from devices after app launched, do below please.
- you should select android-sdk-directory or adb including directory from popup window.
- click "Devices" button to see device list connected to usb. after click Devices,
 devices name will list in "Source:".
- click Device name then log will be shown in window.

![ScreenShot](https://raw.github.com/pikey8706/LogCatch/master/screenshot_on_mac.png)

Author:
Hirohito Sasaki
email: pikey8706@gmail.com
