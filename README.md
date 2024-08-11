LogCatch
===
Log viewer for Linux/Mac/Windows.
First designed for android adb logcat viewer but works with other log formats.
Designed to allow easy filtering and/or highlighting or multiple patterns at once.
This is written in tcl/tk.

Features:
- Context colored log lines. Logtype detection enhances filtering including: time, threadtime, brief, process, eclipse, and studio logs
- Filtering by keywords. This is done by awk regular expression like awk '/key|word/ {print}'
- Key word/Term Searching/navigating and highlighting (up to 9 highlight/searches at once)
- Saving all or part of log files after filtering
- Can read files from disk
- Clear all log messages prior to a specific term in the log file
- Entire session is saved (search/highlights/filtering) for easy resuming
- Auto scrolling / tailing log files (and option to temporarily suspend reading new lines on the connection)

Android Specific Features:
- Use adb logcat to read live logs from a connected android device (or emulator)
- Native tag/process filtering supported (and shows process list)
- LogLevel filtering on a per tag setting (ie only critical SensorManager log lines but verbose lines for any other tag)
- Automatically clear device log on connect

<!-- MarkdownTOC -->

- [Screenshot](#screenshot)
- [Requirements](#requirements)
	- [Linux:](#linux)
	- [Mac:](#mac)
	- [Windows:](#windows)
- [Install](#install)
	- [Linux:](#linux-1)
	- [Mac:](#mac-1)
	- [Windows:](#windows-1)
- [Usage](#usage)
	- [Starting](#starting)
	- [Linux/Mac user](#linuxmac-user)
- [on terminal.](#on-terminal)
- [or](#or)
	- [Windows user](#windows-user)
	- [Viewing log file or live Device Log](#viewing-log-file-or-live-device-log)
	- [Searching / Highlights](#searching--highlights)
	- [Tailing / Suspending Reads](#tailing--suspending-reads)
	- [Filtering](#filtering)
		- [Android Native Tag/Level filtering](#android-native-taglevel-filtering)
	- [Saving search terms/filtering](#saving-search-termsfiltering)
	- [Command Line Args](#command-line-args)
- [Log Types](#log-types)
- [Author](#author)

<!-- /MarkdownTOC -->


## Screenshot
![ScreenShot](https://raw.github.com/pikey8706/LogCatch/master/screenshot_on_mac.png)

## Requirements
You need the binaries: wish (tk), gawk, and optionally adb (for android live logging)

### Linux:
gawk for filtering, tk package for GUI, and android-sdk for adb.

### Mac:
android-sdk for adb, gawk, and tk(from Homebrew).
From macOS Monterery, tk vesion 8.6.12(or over) from Homebrew can run this app.

### Windows:
bash, wish, gawk, android-sdk for adb.

Recommended to install msys-git ([Git for Windows](https://git-for-windows.github.io/)). This contains git, bash, awk, wish.

No warranty for subsystem-linux on windows 10. Only msys-git is tested but other setups may work.

## Install
### Linux:
Arch:
`pacman -S --needed gawk tk android-tools`

Debian/Ubuntu:
`apt-get install gawk tk android-tools`

### Mac:
`prepare android-sdk`

`brew install gawk tcl-tk`

### Windows:
I tested my-app on msysgit enviroment.

Install from : [here](https://git-for-windows.github.io/)

Or active tcl may work().

## Usage
### Starting
To launch app

### Linux/Mac user
- `git clone https://github.com/pikey8706/LogCatch.git`
- open LogCatch folder.
- Just W-click [runOnShell].
<pre>
#on terminal.
$ ./runOnShell
#or
$ wish src/LogCatch.tcl --dir src
</pre>

### Windows user
Assuming you have done installed msys-git.
- git clone https://github.com/pikey8706/LogCatch.git
or
- Download zip file: https://github.com/pikey8706/LogCatch/archive/master.zip
- unzip LogCatch-master.zip
- open LogCatch-master folder.
- Just W-click [LogCatch_winLauncher.vbs]. This automatically resolve path for wish/bash/awk in msys-git windows enviroment.
- Please create shortcut lancher by yourself.

### Viewing log file or live Device Log
To view log files click "Files" and browse to the log file you would like.

To see log from connected devices after app launched:
- you should select android-sdk-directory or adb including directory from popup window.
- click "Devices" button to see device list connected to usb. after click Devices,
 devices name will list in "Source:".
- click Device name then log will be shown in window.

### Searching / Highlights
The primary interface shows 9 colored squares directly above the log file itself.  You can put a search term into any of these boxes and hit enter, and every instance of that term will be highlighted (the total matches are shown on the right side of the box).  You can search/seek the term by hitting then up and down arrow keys while within the respective highlight box.

### Tailing / Suspending Reads
You can automatically scroll to the bottom of the log by having the "TrackTail" checked at the bottom right of the screen.
You can temporarily suspend logging new log lines to the log window by checking "SuspendRead" at the bottom right, note lines that come in while suspended are discarded.

### Filtering
Aside from the general minimal log level (verbose, trace, etc) configured in the upper left you can easily filter based on specific terms.  Changing any filter (when hitting enter) will clear the log view and reload the log file, or for a log stream it will only effect new log lines.

For Include/Exclude filter boxes they take an [AWK style pattern](https://web.mit.edu/gnu/doc/html/gawk_8.html).  This is a regex style form but in basics you can do multiple terms separated with a vertical pipe `|` ie: `CriticalException|Overheat|Battery` will match any log line with any of those 3 terms.

#### Android Native Tag/Level filtering
When connected to a device directly over ADB:

You can use standard ADB logcat filter strings in the "Native Tag Filter" box.  You can easily up the minimum log level for certain tags by selecting the part of one or more lines in the log window and in the right click context menu selecting "Require higher loglevel for selected lines". It doesn't matter what part of each line is selected it will automatically parse the log Tag from the line and raise the loglevel for that tag to one higher than the line itself is.

You can filter by a specific process and (or) by a specific android tag (tags are normally the service, etc that generates the message).  You may want to do OR not and filtering for situations where you want specific system messages that are not logged under the process you are about itself.

### Saving search terms/filtering
The existing session has all search/filters saved automatically to `~/.logcatch` these are reloaded on startup as well.

### Command Line Args
- --dir [dir] - Overrides the directory for LogCatch and its other scripts
- --clearOn [str] - If string is found in the log file everything before that string is cleared out.  Useful to essentially "start" logging when a specific event/action happens.
- --console - Shows the debug console window by default

For android adb connections only:
- --proc [procRegex] - Takes a regex if a process matches the regex the logs are filtered to only output from that process
- --device [deviceRegex] - Takes a regex and if an android device with that name is found it is automatically attached to it

## Log Types
- LogCatch determines the type of log from the first 6 lines of the log file.  The log type is currently only used for extracting the LogLevel for the line all other functionality works no matter the file type.

## Author
Hirohito Sasaki
email: pikey8706@gmail.com
