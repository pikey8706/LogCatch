#!/bin/sh
# \
exec wish "$0" -- "$@"

set runDir [pwd]
foreach {opt val} $argv {
    if {"$opt" == "--dir"} {
        set runDir $val
    }
}

# globals
set AppName "LogCatch"
set SDK_PATH "$env(HOME)"
set ADB_PATH ""
set NO_ADB 0
set CONST_MODEL "ro.product.model"
set CONST_VERSION "ro.build.version.release"
set CONST_DEFAULT_ENCODING "utf-8"
set LogTypes "brief process tag thread raw time threadtime long"
set Devices ""
set Device ""
set Fd ""
set AutoSaveDeviceLog 0; # default: 0
set AutoSaveFileName ""
set HOME_PATH [regsub -all "\\\\" "$env(HOME)" "/"]; # switch windows path to unix path
set AutoSaveDirectory "$HOME_PATH/${AppName}_AutoSavedDeviceLogs"
set AutoSaveProcessId ""
set PrevLoadFile ""
set LoadFile ""
set LoadedFiles ""
set LoadFileMode 0; # 0: Load file one shot, 1: load file incrementaly
set LineCount 0
set statusOne .b.1
set statusTwo .b.2
set status3rd .b.3
set MaxRow 2500
set TrackTail 0
set LogLevel(V) 1
set LogLevel(D) 1
set LogLevel(I) 1
set LogLevel(W) 1
set LogLevel(E) 1
set LevelFilter "V\\\\/|D\\\\/|I\\\\/|W\\\\/|E\\\\/"
set LevelAndOr and
set WrapMode none
set OS $tcl_platform(os)
set PLATFORM $tcl_platform(platform)
# set StartLabel "--- Start Viewing Log ---\n"
# set EndLabel "--- End Of File reached ---\n"
set WaitingLabel "Waiting..."
set WaitingFd ""
set ReadingLabel "Reading..."
set EOFLabel "End Of File"
set Encoding $CONST_DEFAULT_ENCODING
set ProcessPackageList ""
set ProcessFilters ""
set ProcessFiltersOld ""
set ProcessFilterExpression ""
set FilterDeadProcess 1; # 0: none, 1: only the latest dead process, -1: all the dead processes
set ProcessAndOrTag "or"
set ProcessTagFilter ""
set TagFilter ""
set LogView ""
set LastLogLevel "V"

# Filter
set eFilter ""
set iFilter ""
# Search
set sWord ""
set sIdx 0
set sIndex 1.0
set pIndex 0.0
set sDir -forward
set sCnt 0
# Highlight
set AUTO_HIGHLIGHT_DELAY 1111

set LastKeyPress ""

# Update
set trackTailTask ""

# Editor
set Editor ""

# Clear Auto
set ClearAuto none

# Menu Face
set MenuFace button; # bar button both

# Font fot logview
set LogViewFontName TkFixedFont
if {$OS == "Darwin"} {
    proc tk::mac::Quit {} {
        safeQuit
    }
    set LogViewFontName systemSystemFont
}

# import essential command path
source $runDir/importPath.tcl

proc setEditor {} {
    global Editor OS
    # first check EDITOR env
    if {[info exist env(EDITOR)] && $env(EDITOR) != ""} {
        set Editor $env(EDITOR)
    }
    # default for each platform
    if {$Editor == ""} {
        if {$OS == "Darwin"} {
            set Editor "/Applications/TextEdit.app"
        } elseif {$OS == "Linux"} {
            set Editor nano
        } else {
            set Editor Notepad
        }
    }
}

# Windows
wm deiconify .
wm title . $AppName
wm protocol . WM_DELETE_WINDOW safeQuit
image create photo app_icon -file $runDir/icon_logcatch.gif
wm iconphoto . app_icon
# Encoding
encoding system $Encoding
# bottom status line
frame .b -relief raised
pack .b -side bottom -fill x
pack [label .b.1 -text "0" -relief ridge] -side left
pack [label .b.2 -text $EOFLabel -relief ridge -fg red] -side left
pack [checkbutton .b.stick -text TrackTail -command "trackTail" -variable TrackTail -relief ridge] \
	-side right -padx 3
pack [label .b.wmode -text LineWrap -relief ridge] -side right
pack [label .b.encode -text Encoding -relief ridge] -side right
pack [label .b.logtype -text "LogType:" -relief ridge] -side right
pack [label .b.3 -text "Source:" -relief ridge] -side left
pack [button .b.b -text Editor -command openEditor] -side left

# top menu
menu .mbar
#. config -menu .mbar
# Apple menu
# menu .mbar.apple
# .mbar add cascade -menu .mbar.apple 
# .mbar.apple add command -label "About my Applications"
# File menu
menu .mbar.f -tearoff 0
.mbar.f add command -label About -command "showAbout" -underline 0
.mbar.f add separator
.mbar.f add command -label Preferences -command "showPreferences" -underline 0
.mbar.f add separator
.mbar.f add command -label Quit -command "safeQuit" -underline 0
.mbar add cascade -menu .mbar.f -label $AppName -underline 0

# View menu
menu .mbar.v -tearoff 0
.mbar.v add command -label "Font & Colors" -command chooseFontsAndColors -underline 0
.mbar add cascade -menu .mbar.v -label View -underline 0

global InputSrc
# Input source menu
.mbar add cascade -menu .mbar.i -label "Input Source" -underline 0
menu .mbar.i -tearoff 1
.mbar.i add cascade -menu .mbar.i.d -label "devices" -underline 0
menu .mbar.i.d
.mbar.i.d add command -label "Detect deivices" -command "detectDevices" -underline 0
.mbar.i.d add separator

.mbar.i add separator
.mbar.i add cascade -menu .mbar.i.f -label "files" -underline 0
menu .mbar.i.f
.mbar.i.f add command -label "Select file" -command "loadFile" -underline 0
.mbar.i.f add separator

# Top frame
set t [frame .top ];#-bg pink]
pack $t -side top -fill x -padx 5
#pack [button $t.rec -text Rec] -side left
#image create photo menu_icon -file menu.gif
button $t.menu -text Menus -command "menuLogcatch $t.menu" ;# -image menu_icon
pack $t.menu -side left

proc menuLogcatch {w} {
    set m .logcatchmenu
    if {[winfo exist $m]} {
        destroy $m
    }
    menu $m -tearoff 0
    $m add command -label About -command "showAbout"
    $m add separator
    $m add command -label Preferences -command "showPreferences"
#    $m add command -label HistoryBrowser -command "showHistoryBrowser"
    $m add separator
    $m add command -label Quit -command "safeQuit"
    set x [expr [winfo rootx $w] - [winfo width $w]]
    set y [winfo rooty $w]
    tk_popup $m $x $y
}

proc showPreferences {} {
    global ADB_PATH MenuFace
    set w .preferences
    if {[winfo exists $w]} {
        raise $w
        return
    }
    toplevel $w
    wm title $w "Preferences"
    wm protocol $w WM_DELETE_WINDOW "destroy $w"
    wm transient $w .
    pack [frame $w.bottom -relief raised] -fill x -expand yes -side bottom -anchor s
    pack [button $w.bottom.close -text Close -command "destroy $w"] -side right
    pack [frame $w.f1] -fill x
    pack [label $w.f1.adblocationlabel -text "ADB_PATH : "] -side left
    pack [label $w.f1.adblocation -text "$ADB_PATH"] -side left
    pack [button $w.f1.changeadblocation -text "Change" -command "getAdbPath $w $w.f1.adblocation"] -side right
    pack [frame $w.f2] -fill x
    pack [label $w.f2.menubarormenubutton -text "Menu Face: "] -side left
    pack [radiobutton $w.f2.menubar -text "Menubar" -value bar -variable MenuFace -command "changeMenuFace"] -side left
    pack [radiobutton $w.f2.menubutton -text "MenuButton" -value button -variable MenuFace -command "changeMenuFace"] -side left
    pack [radiobutton $w.f2.menuboth -text "MenuBar and MenuButton" -value both -variable MenuFace -command "changeMenuFace"] -side left
    pack [frame $w.f3] -fill x
    pack [label $w.f3.editorlabel -text "External Editor Path: "] -side left
    pack [entry $w.f3.editorentry -textvariable Editor] -side left -fill x -expand yes
    pack [button $w.f3.editorpath -text "Browse" -command "changeEditor $w"] -side right
}

proc changeMenuFace {args} {
    global MenuFace
    puts "changeMenuFace $MenuFace"
    pack forget .top.menu .top.sources
    if {$MenuFace == "bar"} {
        . config -menu .mbar
        pack .top.sources -side left
    } elseif {$MenuFace == "button"} {
        . config -menu ""
        pack .top.menu -side left
        pack .top.menu .top.sources -side left
    } elseif {$MenuFace == "both"} {
        . config -menu .mbar
        pack .top.menu .top.sources -side left
    }
}

proc changeEditor {w} {
    global Editor
    set path [tk_getOpenFile -parent $w]
    puts "changeEditor $path"
    if { ([file isdirectory "$path"] &&
    ([string match "*.app" "$path"] || [string match "*.app/" "$path"])) ||
    [file executable "$path"]} {
        set Editor "$path"
    }
}

proc showHistoryBrowser {} {

}

#pack [button $t.clr -text "Clear Log" -command clearLogView -padx 20] -side right
pack [labelframe $t.sources -text "Source: " -labelanchor w] -side left
changeMenuFace

# pane
frame .p ;#-bg "#ff0000"
pack .p -side top -expand y -fill both -ipadx 5 -ipady 5

# left pane
#set l [frame .p.lf];# -bg lightgreen
#pack $l -side left -anchor w -fill both
#label $l.msg -text SelectTags
#pack $l.msg
#set lf [listbox $l.lf -bg white -xscrollcommand "$l.s0 set" -yscrollcommand "$l.s1 set" -width 2]
#pack $lf -fill both
#scrollbar $l.s0 -orient horizontal -command "$lf xview"
#scrollbar $l.s1 -command "$lf yview"
#grid $l.lf -row 0 -column 0 -sticky nsew
#grid $l.s0 -row 1 -column 0 -sticky ew
#grid $l.s1 -row 0 -column 1 -sticky ns
#pack $l.s1 -side right -anchor e -fill y
#pack $l.lf -anchor e -fill both -expand yes
#pack $l.s0 -anchor s -fill x
global tagview
#set tagview $lf

#pack [button $l.b1 -text b1] -side left

# right pane
set r [frame .p.rf -bg green]
pack $r -side right -anchor e -fill both -expand yes -padx 5 -pady 5

set hks [frame .p.rf.hks];# -bg lightblue
pack $hks -fill x
#pack [label $hks.l -text "show level: "] -side left
#pack [checkbutton $hks.v -text V -command "changeLevel V" -variable LogLevel(V)] -side left
#pack [checkbutton $hks.d -text D -command "changeLevel D" -variable LogLevel(D)] -side left
#pack [checkbutton $hks.i -text I -command "changeLevel I" -variable LogLevel(I)] -side left
#pack [checkbutton $hks.w -text W -command "changeLevel W" -variable LogLevel(W)] -side left
#pack [checkbutton $hks.e -text E -command "changeLevel E" -variable LogLevel(E)] -side left
#pack [checkbutton $hks.andor -textvariable LevelAndOr -variable LevelAndOr -offvalue "or" -onvalue "and"] -side left -padx 20
set wProcessFilter $hks.process
pack [label $hks.labelprocess -text "Process Filter: "] -side left
pack [button $wProcessFilter -command "after 0 showProcessList $wProcessFilter"] -side left
set wProcessAndOr $hks.or
pack [button $wProcessAndOr -text " OR " -command "changeProcessTagComplex $hks.or"] -side left
pack [label $hks.taglbl -text "Tag Filter: "] -side left
pack [entry $hks.tagent -textvariable TagFilter] -side left -fill x -expand y
pack [button $hks.tagclr -text Clear -command "set TagFilter \"\"" -takefocus 0] -side right
bind $hks.tagent <Return> openSource

# Filter entry
set filsi [frame .p.rf.filsi];# -bg lightblue
pack $filsi -fill x
pack [label $filsi.li -text "Inclusive Filter:"] -side left
pack [entry $filsi.ei -textvariable iFilter] -side left -expand y -fill x
pack [button $filsi.be -text Clear -command "set iFilter \"\"" -takefocus 0] -side right
set filse [frame .p.rf.fils];# -bg lightblue
pack $filse -fill x
pack [label $filse.le -text "Exclusive Filter:"] -side left
pack [entry $filse.ee -textvariable eFilter] -side left -fill x -expand y
pack [button $filse.be -text Clear -command "set eFilter \"\"" -takefocus 0] -side right
bind $filsi.ei <Return> "updateFilter $filsi.ei $filse.ee"
bind $filse.ee <Return> "updateFilter $filsi.ei $filse.ee"

# Search
set fsrch [frame .p.rf.search];# -bg lightblue
pack $fsrch -fill x
#pack [label $fsrch.l -text "Search:"] -side left
#pack [entry $fsrch.e -textvariable ssWord -width 20] -side left -fill x
#pack [button $fsrch.n -text "Next"  -command "searchWordAll $r.l -forward  $fsrch.e"] -side left
#pack [label $fsrch.idx -textvariable sIdx] -side left
#pack [label $fsrch.ecnt -textvariable sCnt] -side left
#pack [button $fsrch.p -text "Prev" -command "searchWordAll $r.l -backward $fsrch.e"] -side left
#pack [button $fsrch.x -text "Clear" -command "clearSearchAll"] -side left
#bind $fsrch.e <Return> "searchAuto $r.l $fsrch.e"
#bind $fsrch.e <Shift-Return> "searchAuto $r.l $fsrch.e -r"
#bind . <Control-f> "focus $fsrch.e"
#pack [entry $fsrch.2 -textvariable s2Word] -side left -fill x
#pack [entry $fsrch.3 -textvariable s3Word] -side left -fill x
#pack [entry $fsrch.4 -textvariable s4Word] -side left -fill x
#pack [entry $fsrch.5 -textvariable s5Word] -side left -fill x

# Clear Log
pack [button $fsrch.clr -text "Clear Log" -command clearLogView] -side right
# Highlight
pack [label $fsrch.highlight -text "Highlight:"] -side left
global LogLevelTags TextViewColorOptions
set LogLevelTags [list colorBlk colorBlu colorGre colorOrg colorRed]
set TextViewColorTag "colorTextView"
# load text color LogLevelTags
source $runDir/text_color_loader.tcl
set colorIndex 1
foreach colorTag [lsort [array names TextColorTags]] {
    if {[lsearch "$LogLevelTags" $colorTag] >= 0} {
        # puts "$colorTag continue"
        continue
    }
    set fgcolor [lindex $TextColorTags($colorTag) 0]
    set bgcolor [lindex $TextColorTags($colorTag) 1]
    set fgoption ""
    if {$fgcolor != ""} {
        set fgoption "-foreground $fgcolor"
    }
    set bgoption ""
    if {$bgcolor != ""} {
        set bgoption "-background $bgcolor"
    }
    if {$colorTag == $TextViewColorTag} {
        set TextViewColorOptions "$fgoption $bgoption"
        continue
    }
    puts "highlightColor fg:$fgoption bg:$bgoption"
    pack [eval entry ${fsrch}.hword${colorIndex} -textvariable hWord(${colorTag}) $fgoption $bgoption] -side left
    pack [eval label ${fsrch}.hword${colorIndex}cnt $fgoption $bgoption] -side left
    bind ${fsrch}.hword${colorIndex} <Return> "highlightWord $colorTag"
    bind ${fsrch}.hword${colorIndex} <KeyPress> "autoHighlight $colorTag"
    bind ${fsrch}.hword${colorIndex} <KeyPress> "+seekHighlight $colorTag %K"
    set HighlightWord($colorTag) "${fsrch}.hword${colorIndex} 0 0 1.0 {}"
    if {$OS == "Darwin"} {
        ${fsrch}.hword${colorIndex} config -width 13
    }
    incr colorIndex
}

proc entryVcmd {} {
    global LastKeyPress
    if {$LastKeyPress == "Up"} {
        return 0
    } elseif {$LastKeyPress == "Down"} {
        return 0
    } else {
        return 1
    }
}

# entry
#pack [entry .p.rf.e ] -fill x

# logview text/listbox
if {1} {
    set LogView $r.l
    puts "TextView Options: $TextViewColorOptions"
    eval text $r.l $TextViewColorOptions -xscrollcommand \"$r.s0 set\" -yscrollcommand \"$r.s1 set\" -wrap $WrapMode
    scrollbar $r.s0 -orient horizontal -command "$r.l xview"
    scrollbar $r.s1 -command "$r.l yview"
    #grid $r.l -row 0 -column 0 -sticky nsew
    #grid $r.s0 -row 1 -column 0 -sticky ew
    #grid $r.s1 -row 0 -column 1 -sticky ns
    bind $LogView <1> "focus $LogView"
} else {
    listbox $r.l -bg "#eeeeee" ;#-width 200
}
pack $r.s1 -side right -anchor e -fill y
pack $r.l -anchor e -fill both -expand yes
pack $r.s0 -anchor s -fill x
global logview
set logview $r.l
foreach colorTag [array names TextColorTags] {
    if {$colorTag == $TextViewColorTag} {
        continue
    }
    set fgcolor [lindex $TextColorTags($colorTag) 0]
    set bgcolor [lindex $TextColorTags($colorTag) 1]
    set fgoption ""
    if {$fgcolor != ""} {
        set fgoption "-foreground $fgcolor"
    }
    set bgoption ""
    if {$bgcolor != ""} {
        set bgoption "-background $bgcolor"
    }
    puts "make tag fg:$fgoption bg:$bgoption"
    eval $logview tag config $colorTag -foreground $fgcolor $bgoption
}


menu .logmenu -tearoff 0
.logmenu add command -label "Save all lines" -command "saveLines all"
.logmenu add command -label "Save selected lines" -command "saveLines selected"
.logmenu add separator
.logmenu add command -label "Select all lines" -command "selectLines all"
.logmenu add separator
#.logmenu add cascade -menu .logmenu.hi -label "Highlight selected keyword"
#.logmenu add separator
#.logmenu add cascade -menu .logmenu.fi -label "Add Filter Inclusive"
#.logmenu add cascade -menu .logmenu.fe -label "Add Filter Exclusive"
#.logmenu add separator
.logmenu add cascade -menu .logmenu.clear -label "Clear Log ..."
menu .logmenu.hi -tearoff 0
.logmenu.hi add command -label "Yellow" -command "highlight yellow"
.logmenu.hi add command -label "Purple" -command "highlight purple"
.logmenu.hi add command -label "Pink" -command "highlight pink"
.logmenu.hi add command -label "lightgreen" -command "highlight lightgreen"
menu .logmenu.fi -tearoff 0
.logmenu.fi add command -label "Start time by this line" -command "addFilter stime in"
.logmenu.fi add command -label "Stop  time by this line" -command "addFilter etime in"
.logmenu.fi add command -label "Process by this line" -command "addFilter process in"
.logmenu.fi add command -label "Tag by this line" -command "addFilter tag in"
.logmenu.fi add command -label "Thread by this line" -command "addFilter thread in"
menu .logmenu.fe -tearoff 0
.logmenu.fe add command -label "Start time by this line" -command "addFilter stime ex"
.logmenu.fe add command -label "Stop  time by this line" -command "addFilter etime ex"
.logmenu.fe add command -label "Process by this line" -command "addFilter process ex"
.logmenu.fe add command -label "Tag by this line" -command "addFilter tag ex"
.logmenu.fe add command -label "Thread by this line" -command "addFilter thread ex"
menu .logmenu.clear -tearoff 0
.logmenu.clear add cascade -menu .logmenu.clear.auto -label "Clear Auto .. disabled" -state disabled
menu .logmenu.clear.auto -tearoff 0
.logmenu.clear.auto add radiobutton -value none -variable ClearAuto -label "None .. leaving All" -command ""
.logmenu.clear.auto add radiobutton -value 3000 -variable ClearAuto -label "Auto .. leaving latest 3000L" -command ""
.logmenu.clear.auto add radiobutton -value 5000 -variable ClearAuto -label "Auto .. leaving latest 5000L" -command ""
.logmenu.clear.auto add radiobutton -value 8000 -variable ClearAuto -label "Auto .. leaving latest 8000L" -command ""
.logmenu.clear add separator
.logmenu.clear add command -label "Clear All" -command "clearLogView"

bind $logview <3> {tk_popup .logmenu %X %Y}
bind $logview <2> {tk_popup .logmenu %X %Y}
#bind $logview <1> {tk_popup .logmenu %X %Y}
# buttons
#button .update -text Update -underline 0 -command logcat
#pack .update
$logview config -font $LogViewFontName
set LogViewFontSize [font config $LogViewFontName -size]
if {$OS == "Linux"} {
    bind $logview <Control-Button-4> "+ changeFontSize LogViewFontName LogViewFontSize 1"
    bind $logview <Control-Button-5> "+ changeFontSize LogViewFontName LogViewFontSize -1"
} else {
    bind $logview <Control-MouseWheel> "+ changeFontSize LogViewFontName LogViewFontSize %D"
}

proc changeFontSize {fName fSize {delta 0}} {
    global logview
    upvar $fName fontName $fSize fontSize
    if {$delta > 0} {
        incr fontSize
    } elseif {$delta < 0 && $fontSize > 1} {
        incr fontSize -1
    }
    font config $fontName -size $fontSize
    # puts "$fontName $fontSize"
}

proc addCheckBtn {w ww text} {
    global tagview
    if {$ww != ""} {
        #checkbutton $w.$ww -text $text -command "xmen"
        #pack $w.$ww -side top -anchor w
        #$tagview window create end -window $w.$ww
        $tagview insert end "$text"
    }
}

proc getTag {loglevel} {
    global LogLevelTags LogLevels LastLogLevel
    if {[lsearch $LogLevels $loglevel] == -1 && [lsearch $LogLevels $LastLogLevel] > -1} {
        set loglevel $LastLogLevel
    }
    set index 0
    if {$loglevel == "V"} {
    } elseif {$loglevel == "D"} {
        incr index
    } elseif {$loglevel == "I"} {
        incr index 2
    } elseif {$loglevel == "W"} {
        incr index 3
    } elseif {$loglevel == "E"} {
        incr index 4
    }
    set LastLogLevel $loglevel
    return [lindex $LogLevelTags $index]
}

proc logcat {{clear 1} fd {doFilter 0}} {
    global logview Device Fd LineCount TrackTail

    if {$Fd == ""} {
        tk_messageBox \
        -title "Error" \
        -message "Failed to open log: $Device ." \
        -type ok \
        -icon error
        return
    }

    if {$clear == 1} {
        clearLogView
    }

    if {[tell $Fd] == -1} {
        # set focus to last entry
        set last_w [focus -lastfor .]
        if {[winfo class $last_w] == "Entry"} {
            focus $last_w
        } else {
            focus .p.rf.filsi.ei
        }
        # show logcat from not only device
        fileevent $Fd r "readLine $fd"
        fconfigure $Fd -translation auto;#"crlf lf"
    }
}

proc readLine {fd} {
    global logview LineCount statusOne statusTwo MaxRow TrackTail trackTailTask EndLabel EOFLabel
    $logview config -state normal
    if {[eof $fd]} {
        #$logview insert end $EndLabel colorBlk
        $logview config -state disabled
        $statusTwo config -text $EOFLabel -fg red
        closeLoadingFd
        closeWaitingFd
        stopAutoSavingFile
        return
    }

    gets $fd line

    #if {"$line" != ""} {
        set loglevel [getLogLevel "$line"]
        set tag [getTag $loglevel]
        incr LineCount
        $logview insert end "$line\n" $tag
        $logview config -state disabled
        $statusOne config -text $LineCount
        updateView
    #}
}

proc updateView {} {
    global trackTailTask LineCount
    if {"$trackTailTask" != ""} {
        after cancel $trackTailTask
    }
    set trackTailTask [after 200 trackTail]

    # update idletasks
    if {$LineCount%200 == 0} {
        update idletasks
    }
}

source $runDir/logtype.tcl

proc loadFile {{filename ""}} {
    global Fd PrevLoadFile LoadFile LoadedFiles Device LogType
    if {$filename == ""} {
        set dir ~
        if {$LoadFile != ""} {
            set dir [file dirname $LoadFile]
        }
        set filename [tk_getOpenFile -parent . -initialdir $dir]
    }
    puts \"$filename\"
    if [file readable $filename] {
        checkLogType "$filename"
        reloadProc
        set filename [escapeSpace $filename]
        if {"$filename" != "$LoadFile"} {
            set PrevLoadFile $LoadFile
        }
        set LoadFile $filename
        set Device "file:$filename"
        addLoadedFiles $filename
        closeLoadingFd
        closeWaitingFd
        stopAutoSavingFile
        clearSearchAll
        clearHighlightAll
        changeEncoding
        openSource
    } else {
        puts "not readable"
    }
}

proc addLoadedFiles {filename} {
    global LoadedFiles
    #lappend LoadedFiles $filename
    set files $filename
    foreach xfile $LoadedFiles {
        if {![string match $filename $xfile]} {
            lappend files $xfile
        }
    }
    set LoadedFiles $files
    updateLoadedFiles
    saveLastState
}

proc updateLoadedFiles {} {
    global LoadedFiles OS
    set idx [expr {$OS =="Darwin" ? "2" : "3"}]
    .mbar.i.f delete $idx end
    .mbar.i.f add command -label "Garbage History" -command "garbageHistory"
    .mbar.i.f add separator
    foreach afile $LoadedFiles {
        .mbar.i.f add radiobutton -label $afile -variable Device -value "file:$afile" -command "loadFile $afile"
    }
    updateSourceList
}

proc loadDevice {} {
    global Devices Device Encoding ADB_PATH statusTwo WaitingLabel WaitingFd
    closeLoadingFd
    closeWaitingFd
    stopAutoSavingFile
    set devices $Device
    foreach xdevice $Devices {
        if {![string match $Device $xdevice]} {
            lappend devices $xdevice
        }
    }
    set Devices $devices
    updateSourceList
    set serial [getSerial $Device]
    puts "device device: $Device serial: $serial"
    $statusTwo config -text $WaitingLabel -fg orange
    set WaitingFd [open "| $ADB_PATH -s $serial wait-for-device" "r"]
    if {$WaitingFd != "" && [tell $WaitingFd] == -1} {
        fileevent $WaitingFd r "delayedOpenSource $serial"
    }
}

proc delayedOpenSource {serial} {
    global CONST_DEFAULT_ENCODING ADB_PATH AutoSaveDeviceLog AutoSaveProcessId AutoSaveDirectory AutoSaveFileName
    puts "delayedOpenSource"
    closeWaitingFd
    # exec $ADB_PATH -s $serial wait-for-device
    if {$AutoSaveDeviceLog} {
        stopAutoSavingFile
        set autoSaveFileName [getAutoSaveFileName]
        set AutoSaveFileName "$AutoSaveDirectory/$autoSaveFileName"
        if {[file exists $AutoSaveFileName]} {
            file rename $AutoSaveFileName $AutoSaveDirectory/old_${autoSaveFileName}
        }
        puts "openAutoSavingFile: $AutoSaveFileName"
        set AutoSaveProcessId [exec $ADB_PATH -s $serial logcat -v threadtime > $AutoSaveFileName &]
        puts "AutoSaveProcessId: $AutoSaveProcessId"
    }
    updateProcessFilters
    changeEncoding $CONST_DEFAULT_ENCODING disabled
    openSource
}

proc closeWaitingFd {} {
    global WaitingFd
    puts "closeWaitingFd"
    if {$WaitingFd != ""} {
        fileevent $WaitingFd r ""
        fconfigure $WaitingFd -blocking 0
        close $WaitingFd
        set WaitingFd ""
    }
}

proc stopAutoSavingFile {} {
    global AutoSaveProcessId PLATFORM
    if {$AutoSaveProcessId != ""} {
        set err_status 0
        set err_msg ""
        if {$PLATFORM == "windows"} {
            puts "taskkill /F /PID $AutoSaveProcessId"
            set err_status [catch {exec  taskkill /F /PID $AutoSaveProcessId} err_msg]
        } else {
            puts "kill -9 $AutoSaveProcessId"
            set err_status [catch {exec kill -9 $AutoSaveProcessId} err_msg]
        }
        if {$err_status} {
            puts "err_msg: $err_msg"
        }
        set AutoSaveProcessId ""
    }
}

proc wrapMenu {} {
    global WrapMode
    set m .wmode
    menu $m -tearoff 0
    $m add radiobutton -label None -value none -variable WrapMode -command changeWrapMode
    $m add radiobutton -label Char -value char -variable WrapMode -command changeWrapMode
    $m add radiobutton -label Word -value word -variable WrapMode -command changeWrapMode
    bind .b.wmode <1> "tk_popup $m %X %Y"
}

proc changeWrapMode {args} {
    global WrapMode logview
    .b.wmode config -text "LineWrap: $WrapMode"
    $logview config -wrap  $WrapMode
    update idletasks
    puts "changeWrapMode $WrapMode"
}
wrapMenu

proc encodingMenu {{state "normal"}} {
    global Encoding Codes runDir
    set m .encodings
    if {[winfo exists $m] == 0} {
        menu $m -tearoff 0
        set defaultCode "utf-8"
        set lists [lsort [encoding names]]
        set defIdx [lsearch $lists $defaultCode]
        if {$defIdx > -1} {
            $m add radiobutton -label "Default: $defaultCode" -value $defaultCode -variable Encoding -command "changeEncoding ; openSource"
            $m add separator
        }
        source $runDir/codes.tcl
        set group [lsort [array names Codes]]
        foreach one $group {
            set gmenu $m.[string tolower $one]
            menu $gmenu -tearoff 0
            $m add cascade -menu $gmenu -label "$one"
            foreach two $lists {
                set idx [lsearch $Codes($one) $two]
                if {$idx > -1} {
                    $gmenu add radiobutton -label "$two" -value $two -variable Encoding -command "changeEncoding ; openSource"
                }
            }
        }
    }
    if {"$state" == "normal"} {
        bind .b.encode <1> "tk_popup $m %X %Y"
    } elseif {"$state" == "disabled"} {
        bind .b.encode <1> ""
    }
}

proc changeEncoding {{encoding ""} {state "normal"}} {
    global Encoding
    if {"$encoding" == ""} {
        set encoding $Encoding
    }
    encoding system $encoding
    .b.encode config -text "encoding: $encoding"
    .b.encode config -state $state
    encodingMenu $state
    update idletasks
    puts "changeEncoding to :${encoding}:"
}

encodingMenu

proc garbageHistory {} {
    global LoadedFiles
    set w [toplevel .garbage_history]
    wm title $w "Garbage History"
    set n [llength $LoadedFiles]
    pack [label $w.whoami -text "Choose files to forget out of $n"]
    pack [button $w.close -text Close -command "destroy $w"] -side bottom
    pack [frame $w.bbox] -fill x -side bottom
    pack [button $w.bbox.sel_all -text "Select All" -command "$w.list selection set 0 end"] -side left
    pack [button $w.bbox.desel_all -text "Deselect All" -command "$w.list selection clear 0 end"] -side left
    pack [button $w.bbox.forget_sel -text "Forget selected files." -command "clearHistory $w.list"] -side right
    pack [listbox $w.list -selectmode multiple] -fill both -expand yes
    foreach one $LoadedFiles {
        $w.list insert end $one
    }
    grab set $w
}

proc clearHistory {w} {
    global LoadedFiles
    set selectedIdx [$w curselection]
    if {$selectedIdx == ""} {
        return
    }
    set nlist ""
    set idx 0
    set n [llength $LoadedFiles]
    foreach one $LoadedFiles {
        if {[lsearch $selectedIdx $idx] == -1} {
            lappend nlist $one
        }
        incr idx
    }
    puts "new history: $nlist"
    set LoadedFiles $nlist
    set newn [llength $LoadedFiles]

    updateLoadedFiles
    tk_messageBox -title "" -message "Failed to open log: $Device ." -type ok -icon error
}

global taglist
set taglist ""
proc updateTags {tag} {
    global taglist
    set idx [lsearch $taglist $tag]
    if { $idx == -1 } {
        set taglist "$taglist $tag"
        set ltag [string tolower $tag]
        addCheckBtn .p.lf $ltag $tag
    }
}

proc showAbout {} {
    set w [toplevel .about]
    pack [button $w.close -text Close -command "destroy $w"] -side bottom
    pack [label $w.whoami -text "This is android logcat viewer by tcl/tk."]
}

proc safeQuit {} {
    catch {puts safequit} msg
    closeLoadingFd
    closeWaitingFd
    stopAutoSavingFile
    saveLastState
    exit 0
}


global Pref
set Pref(col:bg) "#000000"
set Pref(col:fg) "#FFFFFF"

proc savePreference {} {
    global Pref env
    set dir "$env(HOME)/.logcatch"
    set prefFile "logcatch.rc"
    if {! [file isdirectory $dir]} {
        file mkdir $dir
    }
    if {! [file isdirectory $dir]} {
        return
    }
    set fdW [open $dir/$prefFile w+]
    if {$fdW != ""} {
        close $fdW
    }
}

proc loadPreference {} {
    global Pref env
    set dir "$env(HOME)/.logcatch"
    set prefFile "logcatchrc"
    set path $dir/$prefFile
    if {[file readable $path]} {
        set fd [open $path r]
        if {$fd != ""} {
            while {[gets $fd line] > 0} {
                set spline [split $line :]
                set key [lindex $spline 0]
                set Pref($key) [lindex $spline 1]
            }
            close $fd
        }
    }
}

proc saveLastState {} {
    global env LoadedFiles iFilter eFilter WrapMode sWord Editor Encoding SDK_PATH ADB_PATH NO_ADB MenuFace \
TagFilter hWord LogViewFontName LogViewFontSize FilterDeadProcess
    global LoadFileMode AutoSaveDeviceLog
    set dir "$env(HOME)/.logcatch"
    set loadStateFile "last.state"
    if {! [file isdirectory $dir]} {
        file mkdir $dir
    }
    if {! [file isdirectory $dir]} {
        return
    }
    set fdW [open $dir/$loadStateFile w+]
    if {$fdW != ""} {
        # save loaded files list
        puts $fdW ":LoadedFiles"
        foreach one $LoadedFiles {
            puts $fdW $one
        }
        # save filter strings
        puts $fdW ":iFilter"
        puts $fdW $iFilter
        puts $fdW ":eFilter"
        puts $fdW $eFilter
        puts $fdW ":sWord"
        puts $fdW $sWord
        puts $fdW ":WrapMode"
        puts $fdW $WrapMode
        puts $fdW ":Editor"
        puts $fdW $Editor
        puts $fdW ":Encoding"
        puts $fdW $Encoding
        puts $fdW ":SDK_PATH"
        puts $fdW $SDK_PATH
        puts $fdW ":ADB_PATH"
        puts $fdW $ADB_PATH
        puts $fdW ":NO_ADB"
        puts $fdW $NO_ADB
        puts $fdW ":MenuFace"
        puts $fdW $MenuFace
        puts $fdW ":TagFilter"
        puts $fdW $TagFilter
        # HighlightWords
        foreach colorTag [array names hWord] {
            puts $fdW ":hWord(${colorTag})"
            puts $fdW $hWord(${colorTag})
        }
        puts $fdW ":LogViewFontName"
        puts $fdW $LogViewFontName
        puts $fdW ":LogViewFontSize"
        puts $fdW $LogViewFontSize
        puts $fdW ":FilterDeadProcess"
        puts $fdW $FilterDeadProcess
        puts $fdW ":LoadFileMode"
        puts $fdW $LoadFileMode
        puts $fdW ":AutoSaveDeviceLog"
        puts $fdW $AutoSaveDeviceLog
        puts $fdW ":"
        close $fdW
    }
}

proc loadLastState {} {
    global LoadedFiles env WrapMode iFilter eFilter sWord Editor SDK_PATH ADB_PATH NO_ADB MenuFace TagFilter
    global hWord LogViewFontName LogViewFontSize FilterDeadProcess LogLevelTags TextColorTags
    global LoadFileMode AutoSaveDeviceLog
    set dir "$env(HOME)/.logcatch"
    set loadLastState "last.state"
    if {! [file isdirectory $dir]} {
        file mkdir $dir
    }
    if {! [file isdirectory $dir]} {
        return
    }
    if {! [file readable $dir/$loadLastState]} { return }
    set fd [open $dir/$loadLastState r]
    set colorTags [array names TextColorTags]
    if {$fd != ""} {
        set flag 0
        while {[gets $fd line] > -1} {
           if {[string match ":*" $line]} {
                if {[string match ":LoadedFiles" $line]} {
                    set flag 1
                } elseif {[string match ":iFilter" $line]} {
                    set flag 2
                } elseif {[string match ":eFilter" $line]} {
                    set flag 3
                } elseif {[string match ":sWord" $line]} {
                    set flag 4
                } elseif {[string match ":WrapMode" $line]} {
                    set flag 5
                } elseif {[string match ":Editor" $line]} {
                    set flag 6
                } elseif {[string match ":Encoding" $line]} {
                    set flag 7
                } elseif {[string match ":SDK_PATH" $line]} {
                    set flag 8
                } elseif {[string match ":ADB_PATH" $line]} {
                    set flag 9
                } elseif {[string match ":NO_ADB" $line]} {
                    set flag 10
                } elseif {[string match ":MenuFace" $line]} {
                    set flag 11
                } elseif {[string match ":TagFilter" $line]} {
                    set flag 12
                } elseif {[string match ":hWord(*" $line]} {
                    set colorTag [lindex [split $line "()"] 1]
                    if {[lsearch $LogLevelTags $colorTag] == -1 && [lsearch $colorTags $colorTag] >= 0} {
                        gets $fd line
                        set hWord($colorTag) $line
                    }
                } elseif {[string match ":LogViewFontName" $line]} {
                    set flag 20
                } elseif {[string match ":LogViewFontSize" $line]} {
                    set flag 21
                } elseif {[string match ":FilterDeadProcess" $line]} {
                    set flag 22
                } elseif {[string match ":LoadFileMode" $line]} {
                    set flag 23
                } elseif {[string match ":AutoSaveDeviceLog" $line]} {
                    set flag 24
                } else {
                    set flag 0
                }
            } elseif {$flag == 1} {
                lappend LoadedFiles $line
            } elseif {$flag == 2} { 
                set iFilter $line
            } elseif {$flag == 3} { 
                set eFilter $line
            } elseif {$flag == 4} { 
                set sWord $line
            } elseif {$flag == 5} { 
                set WrapMode $line
            } elseif {$flag == 6} { 
                set Editor $line
            } elseif {$flag == 7} { 
                set Encoding $line
            } elseif {$flag == 8} { 
                set SDK_PATH $line
            } elseif {$flag == 9} { 
                set ADB_PATH $line
            } elseif {$flag == 10} { 
                set NO_ADB $line
            } elseif {$flag == 11} { 
                set MenuFace $line
            } elseif {$flag == 12} { 
                set TagFilter $line
            } elseif {$flag == 20} { 
                set LogViewFontName $line
            } elseif {$flag == 21} { 
                set LogViewFontSize $line
            } elseif {$flag == 22} { 
                set FilterDeadProcess $line
            } elseif {$flag == 23} {
                set LoadFileMode $line
            } elseif {$flag == 24} {
                set AutoSaveDeviceLog $line
            } else {
            }
        }
        close $fd
        updateLoadedFiles
        changeWrapMode
        changeEncoding
        changeMenuFace
        changeFontSize LogViewFontName LogViewFontSize
    }
}

proc initAutoSaveDirectory {} {
    global AutoSaveDirectory
    if {! [file isdirectory $AutoSaveDirectory]} {
        file mkdir $AutoSaveDirectory
    }
}
initAutoSaveDirectory

proc getAutoSaveFileName {} {
    global Device
    set splitname [split $Device :]
    set modelOs [lindex $splitname 0]
    set model [lindex [split $modelOs "/"] 0]
    set os [lindex [split $modelOs "/"] 1]
    set device [lindex $splitname 1]
    set port [lindex $splitname 2]
    set dateTime [exec date +%Y_%m%d_%H%M%S]
    set fileName "${dateTime}_OS${os}_${model}.txt"
    return "$fileName"
}

proc openSource {} {
    global Fd LoadFile eFilter iFilter Device LineCount LevelFilter LevelAndOr \
    statusTwo status3rd AppName ADB_PATH LogType ReadingLabel ProcessFilterExpression TagFilter ProcessTagFilter ProcessAndOrTag \
    LoadFileMode AutoSaveDeviceLog AutoSaveFileName
    closeLoadingFd
    set deny "!"
    set isFileSource [string match "file:*" $Device]
    puts "isFileSource: $isFileSource"
    updateProcessTagFilterExpression $isFileSource
    set xiFilter [checkEscapeAll [escapeSlash "$iFilter"]]
    set xeFilter [checkEscapeAll [escapeSlash "$eFilter"]]
    if {$eFilter == ""} {
        set deny ""
    }
    set lvlAndOr "&&"
    if {$LevelAndOr == "or"} {
        set lvlAndOr "||"
    }
    set title $Device
    puts "processFilter: \"$ProcessFilterExpression\""
    puts "tagFilter: \"$TagFilter\""
    puts "pAndOr: \"$ProcessAndOrTag\""
    puts "processTagFilter: \"$ProcessTagFilter\""

    if {$isFileSource} {
        updateProcessFilterStatus disabled
        set lvlstate normal
        if {$LogType == "raw"} {
            set lvlAndOr "||"
            set lvlstate disabled
        }
#      foreach w {v d i w e andor} {
#       .p.rf.hks.${w} config -state $lvlstate
#      }
        if {$LoadFileMode} {
            set Fd [open "| tail -f -n +1 $LoadFile | awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
        } else {
            set Fd [open "| awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" $LoadFile" r]
        }
        set title [file tail $Device]
    } else {
        updateProcessFilterStatus normal
        set splitname [split $Device :]
        set model  [lindex $splitname 0]
        set device [lindex $splitname 1]
        set port [lindex $splitname 2]
        if {$port != ""} {
            append device ":$port"
        }
        puts device\ $device
        set LogType threadtime
        reloadProc
#set Fd [open "|$ADB_PATH -s $device logcat -v time | awk \"NR > 0 &&  $deny /$xeFilter/ && (/$ProcessFilterExpression/ && (/$TagFilter/ && /$xiFilter/)) {print}{fflush()}\" " r]
puts "AutoSaveDeviceLog: $AutoSaveDeviceLog file: $AutoSaveFileName"
if {$AutoSaveDeviceLog} {
set Fd [open "|tail -f -n +1 $AutoSaveFileName | awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
} else {
set Fd [open "|$ADB_PATH -s $device logcat -v threadtime | awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
}
    }
    puts "src: $Device fd: $Fd"
    puts "LevelFilter => $LevelFilter $lvlAndOr"
    puts "eFilter: $xeFilter"
    puts "ifilter: $xiFilter"
    $statusTwo config -text $ReadingLabel -fg "#15b742"
    $status3rd config -text "Source: $Device"
    .b.logtype config -text "LogType: $LogType"
    wm title . "$title : $AppName"
    if {$Fd != ""} {
        set LineCount 0
        logcat 1 $Fd
    } else {
        puts "$Fd null"
    }
}

proc closeLoadingFd {} {
    global Fd
    if {$Fd != ""} {
        fconfigure $Fd -blocking 0
        close $Fd
        set Fd ""
    }
    updateProcessFilterStatus disabled
}

proc searchWordAll {w dir wentry} {
    global sWord sCnt sIdx LineCount pIndex
    set word [$wentry get]
    if {$word == ""} {
        clearSearchAll
        return
    }
    if {$sWord != $word} {
        clearSearchAll
        set sCnt 0
        set len [string length $word]
        set index 0.0
        set idx0 [$w search -forward -- $word $index]
        set index $idx0
        while {$index != ""} {
            set s [lindex [split $index "."] 0]
            set e [lindex [split $index "."] 1]
            incr sCnt
            incr e $len
            $w tag add colorYel $index $s.$e
            set index [$w search -forward -- $word $s.$e]
            if {$index == $idx0} { break }
        }
        if {$sCnt} {
            set sWord $word
            # .p.rf.search.cnt config -text $cnt
        }
        set toForward [expr {[string compare "$dir" "-forward"] == 0 ? 1 : 0}]
        set sIdx [expr $toForward ? 0 : $sCnt + 1]
        set pIndex [expr $toForward ? "1.0" : [$w index "end-1c"]]
        puts "pi $pIndex"
    }
    searchWord $w $dir $wentry
}

proc searchWord {w dir wentry} {
    global sIndex pIndex sDir sIdx sCnt
    set word [$wentry get]
    set len [string length $word]
    set toForward [expr {[string compare "$dir" "-forward"] == 0 ? 1 : 0}]
    set delta [expr {$toForward ? $len : -1}]
    set ps [lindex [split $pIndex "."] 0]
    set pe [lindex [split $pIndex "."] 1]
    set sIndex $ps.[expr $pe + $delta]
    set index [$w search $dir -- $word $sIndex]
    set s [lindex [split $index "."] 0]
    set e [lindex [split $index "."] 1]
    puts "index: $index pIndex: $pIndex  dir: $dir  len: $len"
    if {$s == "" || $e == ""} {
        set sIndex 1.0
        set sIdx 0
    } else {
        set peIndex $ps.[expr $pe + $len]
        $w tag remove colorOra $pIndex $peIndex
        puts "remove $pIndex $peIndex : $delta"
        puts "add $index $s.[expr $e + $len]"
#       $w tag add colorWht $s.0 $s.end
        $w tag add colorOra $index $s.[expr $e + $len]
        $w tag raise colorOra
        $w see $index
        $w see [expr {$toForward ? $s + 5 : $s - 5}].$e
        # next search starting index
        set sIndex $s.[expr $e + $delta]
        set pIndex $index
        set sDir $dir
        set sIdx [expr ($sIdx + ($toForward ? 1 : -1)) % $sCnt]
        if {$sIdx == 0} {
            set sIdx $sCnt
        }
    }
}

proc searchAuto {w wentry {reverse ""}} {
    global sDir sWord
    if {$reverse == "-r"} {
        if {$sDir == "-forward"} {
            set sDir "-backward"
        } elseif {$sDir == "-backward"} {
            set sDir "-forward"
        }
    }
    searchWordAll $w $sDir $wentry
}

proc highlightWord {colorTag {word ""}} {
    global HighlightWord logview
    set wentry [lindex $HighlightWord($colorTag) 0]
    set word [$wentry get]

    if {$word == ""} {
        removeHighlight $colorTag
        return
    }

    set sCnt [lindex $HighlightWord($colorTag) 2]
    set err [catch {$logview index ${colorTag}.last} index]
    if {$err} {
        set index 1.0
    } else {
        set indexes [$logview tag prevrange $colorTag $index]
        set curWord [$logview get [lindex $indexes 0] $index]
        if {$curWord != "" && $word != "" && $curWord != $word} {
            removeHighlight $colorTag
            set index 1.0
            set sCnt 0
        } else {
        }
    }
    # puts "highlightWord: $word from: $index cnt: $sCnt"

    set cnt $sCnt
    while 1 {
        # puts "\"$word $index\""
        set index [$logview search -count wordLen -- "$word" $index end]
        if {$index == ""} {
            break
        }
        incr sCnt
        $logview tag add $colorTag $index "$index + $wordLen chars"
        set index [$logview index "$index + $wordLen chars"]
    }
    set cntText ""
    if {$sCnt > 0} {
        set cntText "$sCnt"
    }
    ${wentry}cnt config -text $cntText
    if {$sCnt > $cnt} {
        $logview tag raise $colorTag
    }
    # set HighlightWord($colorTag) "$wentry 0 $sCnt 0.0 {}"
    set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 2 2 $sCnt]
}

proc incrementalHighlight {} {
    global HighlightWord
    foreach colorTag [array names HighlightWord] {
        after idle autoHighlight $colorTag
    }
    # search word all
#   after idle highlightWord .p.rf.search.e colorYel
}

proc autoHighlight {colorTag} {
    global HighlightWord AUTO_HIGHLIGHT_DELAY
    set xid [lindex $HighlightWord($colorTag) 4]
    if {$xid != ""} {
      # puts "auto cancel $xid"
        after cancel $xid
    }
    set xid [after $AUTO_HIGHLIGHT_DELAY after idle highlightWord $colorTag]
    set wentry [lindex $HighlightWord($colorTag) 0]
    set idx [lindex $HighlightWord($colorTag) 1]
    set cnt [lindex $HighlightWord($colorTag) 2]
    set seekId [lindex $HighlightWord($colorTag) 3]
    set HighlightWord($colorTag) "$wentry $idx $cnt $seekId $xid"
}

proc seekHighlight {colorTag key} {
    global logview HighlightWord
    if {$key == "Up" || $key == "Down" || $key == "dummy-clean"} {
        set bgcolor [$logview tag cget $colorTag -background]
        set fgcolor [$logview tag cget $colorTag -foreground]
        set bgDark [::tk::Darken $bgcolor 120]
        set fgLight [::tk::Darken $fgcolor 100]
        $logview tag config ${colorTag}Seek -background $bgDark -foreground $fgLight \
        -spacing1 5 -spacing3 5 -relief raised -borderwidth 2 -lmargin1 3 -lmargin2 3 -rmargin 3 -offset 3

        set err [catch {$logview index ${colorTag}.last} index]
        if {$err} {
            return
        }
        $logview config -state normal
        set idx [lindex $HighlightWord($colorTag) 1]
        set sCnt [lindex $HighlightWord($colorTag) 2]
        set err [catch {$logview index ${colorTag}Seek.first} seekFirst]
        set err [catch {$logview index ${colorTag}Seek.last} seekLast]
        if {!$err} {
            $logview delete $seekFirst $seekLast
            $logview tag remove ${colorTag}Seek 1.0 end
        }
        set indexes ""
        if {$key == "Up"} {
            if {$err} {
                set seekFirst [$logview index ${colorTag}.last]
                set idx [expr $sCnt + 1]
            }
            set indexes [$logview tag prevrange $colorTag $seekFirst]
            if {$indexes != ""} {
                incr idx -1
            }
        } elseif {$key == "Down"} {
            if {$err} {
                set seekLast [$logview index ${colorTag}.first]
                set idx 0
            }
            set indexes [$logview tag nextrange $colorTag $seekLast]
            if {$indexes != ""} {
                incr idx
            }
        }
        if {$indexes != ""} {
            set seekFirst [lindex $indexes 0]
            set seekText "$idx > "
            $logview insert $seekFirst $seekText
            set seekLast [$logview index "$seekFirst + [string length $seekText] chars"]
            $logview tag add ${colorTag}Seek $seekFirst $seekLast
            set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 1 1 $idx]
            spotLight $seekFirst $seekLast $key
        }
        $logview config -state disabled
    }
}

proc spotLight {seekFirst seekLast key} {
    global logview
    $logview see "$seekLast + 5 chars"
    if {$key == "Up"} {
        $logview see "$seekLast - 5 lines"
    } else {
        $logview see "$seekLast + 5 lines"
    }
}

proc cleanSeekHighlight {} {
    global HighlightWord
    foreach colorTag [array names HighlightWord] {
        seekHighlight $colorTag "dummy-clean"
    }
}

proc initFilter {} {
    global iFilter
    set iFilter .+
}

proc updateFilter {iw ew} {
    global iFilter eFilter Device
    set iFilter "[$iw get]"
    set eFilter "[$ew get]"
    puts "iF: $iFilter"
    puts "eF: $eFilter"
    clearSearchAll
    clearHighlightAll
    openSource
}

proc addFilter {kind which} {
    if {$which == "in"} {
    } elseif {$which == "ex"} {
    }
    puts "$FilterInEx : $kind"
}

proc trackTail {} {
    global logview TrackTail trackTailTask
    if {$TrackTail} {
        after idle $logview see end
    }
    set trackTailTask ""
    incrementalHighlight
}

proc clearSearchAll {} {
    global sWord sIndex sIdx sCnt
    set sIndex 1.0
    set sIdx 0
    set sCnt 0
    set sWord ""
    set pIndex 0.0
}

proc clearHighlightAll {} {
    global HighlightWord
    foreach colorTag [array names HighlightWord] {
        removeHighlight $colorTag
    }
}

proc removeHighlight {colorTag} {
    global LogView HighlightWord
    $LogView tag remove $colorTag 1.0 end
    set err [catch {$LogView index ${colorTag}Seek.first} seekFirst]
    if {!$err} {
        set err [catch {$LogView index ${colorTag}Seek.last} seekLast]
        puts "del $seekFirst $seekLast"
        $LogView config -state normal
        $LogView delete $seekFirst $seekLast
        $LogView config -state disabled
    } else {
        # puts "del err"
    }
    $LogView tag remove ${colorTag}Seek 1.0 end
    if {[info exists HighlightWord($colorTag)]} {
        set wentry [lindex $HighlightWord($colorTag) 0]
        ${wentry}cnt config -text ""
        set HighlightWord($colorTag) "$wentry 0 0 0.0 {}"
    }
}

proc chooseFontsAndColors {} {
    set w [toplevel .font_color]
    pack [button $w.close -text Close -command "destroy $w"] -side bottom
    pack [label $w.whoami -text "Choose fonts and colors."]
    pack [label $w.color -text "Colors"]
    pack [button $w.colorpick -text ColorPicker -command "getColorAndSet $w"] -side right
}

proc getColorAndSet {w} {
    set color [tk_chooseColor -title Colors -parent $w]
    if {$color != ""} {
        $w.color config -bg $color
    }
}

proc clearLogView {} {
    global logview LineCount statusOne StartLabel LastLogLevel
    $logview config -state normal
    $logview delete 1.0 end
    # $logview insert 1.0 $StartLabel colorBlk
    $logview config -state disabled
    set LastLogLevel "V"
    set LineCount 0
    clearSearchAll
    clearHighlightAll
    $statusOne config -text ""
}

proc changeLevel {lvl} {
    global LogLevel LevelFilter
    set lvlFilter ""
    foreach lvl {V D I W E} {
       set on $LogLevel($lvl)
       if {$on} {
            if {$lvlFilter != ""} {
                append lvlFilter "|"
            }
            append lvlFilter "$lvl/"
        }
    }
    set LevelFilter [escapeSlash $lvlFilter]
    puts "LevelFilter: $LevelFilter"
    openSource
}

proc checkEscapeAll {s} {
    set x $s
    set last_c [string index $s end]
    if {$last_c == "|"} {
        append x ".*"
    }
    return $x
}

proc escapeSlash {s} {
    set x ""
    set len [string length $s]
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $s $i]
        if {$c == "/"} {
            append x "\\\\" 
        }
        append x $c 
    }
    return $x
}

proc escapeSpace {s} {
    set x ""
    set len [string length $s]
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $s $i]
        if {"$c" == " "} {
            append x "\\"
        }
        append x $c 
    }
    return $x
}

proc saveLines {{which "all"}} {
    global logview LoadedFiles
    # default which==all
    set sdx "1.0"
    set edx "end"
    if {$which == "selected"} {
        set rangenums [split [$logview tag ranges sel] " ."]
        set sl [lindex $rangenums 0]
        set sc [lindex $rangenums 1]
        set el [lindex $rangenums 2]
        set ec [lindex $rangenums 3]
        puts "sel: $sl.$sc $el.$ec"
        set sdx "$sl.0"
        set edx "$el.end"
    }
    set dir ~
    set lastLoadedFile [lindex $LoadedFiles 0]
    if {[file exist $lastLoadedFile]} {
        set dir [file dirname $lastLoadedFile]
    }
    set ftypes {{"Text files" ".txt"} {"Log files" ".log"}}
    set default_exete ".txt"
    set filename [tk_getSaveFile -parent . -initialdir $dir -filetypes $ftypes -defaultextension $default_exete]
    if {$filename == ""} {
        return
    }
    cleanSeekHighlight
    set wp [open $filename w]
    if {$wp != ""} {
        set texts [$logview get $sdx $edx]
        puts $wp $texts
        close $wp
        addLoadedFiles $filename
    }
}

proc getModelOS {device} {
    global CONST_MODEL CONST_VERSION ADB_PATH
    set model [exec $ADB_PATH -s $device shell getprop $CONST_MODEL]
    set m ""
    foreach word $model {
        append m $word
    }
    set model $m
    set osversion [lindex [exec $ADB_PATH -s $device shell getprop $CONST_VERSION] 0]
    puts "\"$osversion\":$device\""
    return ${model}/${osversion}
}

proc getDevices {} {
    global Devices ADB_PATH
    set devices ""
    if {![checkAdbPath]} {
        getAdbPath
        return $devices
    }
    set errStatus [catch {exec $ADB_PATH devices -l} device_list]
    if {!$errStatus} {
        foreach line [lrange [split $device_list "\n"] 1 end] {
            set serial [lindex $line 0]
            set model "null"
            foreach one $line {
                foreach {key val} [split $one :] {
                    if {$key == "model"} {
                        set model $val
                        break
                    }
                }
            }
            if {$model != "null" || [lindex $line 1] == "device"} {
            # if {$model == "null"} {
                set model [getModelOS $serial]
            # }
                lappend devices "$model:$serial"
            }
        }
        set Devices $devices
    }
    return $devices
}

proc getSerial {device {lower 0}} {
    set rawSerial [lindex [split $device ":"] 1]
    if {$lower} {
        return [string tolower $rawSerial]
    } else {
        return $rawSerial
    }
}

proc detectDevices {} {
    global Device Devices OS MenuFace
    getDevices
    if {$MenuFace != "button"} {
       set idx [expr {$OS =="Darwin" ? "2" : "3"}]
       .mbar.i.d delete $idx end
       foreach device $Devices {
           .mbar.i.d add radiobutton -label $device -variable Device -value $device -command loadDevice
       }
    }
    updateSourceList
    return [lindex $Devices 0]
}

proc getProcessPackageList {} {
    global ADB_PATH Device ProcessPackageList
    set lists ""
    if {![string match "file:*" $Device]} {
        set splitname [split $Device :]
        set model  [lindex $splitname 0]
        set serial [lindex $splitname 1]
        set port  [lindex $splitname 2]
        puts "ppl device: $Device"
        if {$port != ""} {
            append serial ":$port"
        }
        if {$serial != ""} {
            foreach {pId pkgName uName} [exec $ADB_PATH -s $serial shell ps | awk "/^u0|^app/ {print \$2, \$9, \$1}"] {
                # puts "pId: $pId, pkgName: $pkgName, uName: $uName"
                # puts "[format "%5d %s" $pId $pkgName]"
                if {[string is integer "$pId"]} {
                    lappend lists "[format "%5d %s" $pId $pkgName]"
                }
            }
        }
        set lists [lsort -dictionary -index 1 -incr $lists] 
    }
    set ProcessPackageList $lists
    return $lists
}

proc updateProcessFilters {} {
    global ProcessPackageList ProcessFilters ProcessFilterExpression \
    ProcessFiltersOld FilterDeadProcess
    set pFilters ""
    set oldFilters ""
    getProcessPackageList
    foreach alist "$ProcessFilters $ProcessFiltersOld" {
        set newP ""
        set p [lindex $alist 0]
        set pkg [lindex $alist 1]
        set label [lindex $alist 2]
        # check new process already added to pFilters
        set pkgIdx [lsearch -index 1 $pFilters $pkg]
        if {$pkgIdx == -1} {
            set newPkgIdx [lsearch -index 1 $ProcessPackageList $pkg]
            if {$newPkgIdx >= 0} {
                # There is an alive process of pkg
                set blist [lindex $ProcessPackageList $newPkgIdx]
                set newP [lindex $blist 0]
                lappend pFilters $blist
                puts "updateProcessFilters newProcess: $alist"
            }
        }
        if {$newP == "" ||
            $FilterDeadProcess && $newP != $p} {
            # newP == "" : There is no new process. Keep dead process.
            # FilterDeadProcess && newP != p  : newP is new process of dead process p.
            set pkgIdx [lsearch -index 1 $oldFilters $pkg]
            if {$pkgIdx == -1 || $FilterDeadProcess == -1} {
                lappend oldFilters "[format "%5d %s %s" $p $pkg "(DEAD)"]"
                puts "updateProcessFilters oldProcess: $alist"
            }
        }
    }
    puts "oldFilters: $oldFilters"
    set ProcessFiltersOld $oldFilters
    set ProcessFilters $pFilters
    updateProcessFilterExpression
}

proc showProcessList {w} {
    global ProcessPackageList ProcessFilters ProcessFiltersOld FilterDeadProcess
    set m .processlist
    if {[winfo exists $m]} {
        destroy $m
    }
    updateProcessFilters
    set lists $ProcessPackageList
    menu $m -tearoff 0
    menu $m.plist -tearoff 0
    $m add cascade -menu $m.plist -label "Add Process Filter"
    $m add separator
    set cnt 0
    set mod 31
    set mpl $m.plist
    foreach alist $lists {
        incr cnt
        if {[expr $cnt % $mod] == 0} {
       	    menu $mpl.plist -tearoff 0
            $mpl add cascade -menu $mpl.plist -label "More.."
            set mpl $mpl.plist
        }
        set pId [lindex $alist 0]
        $mpl add command -label "$alist" -command "processFilter $w add \"$alist\""
    }
    set x 0
    foreach alist "$ProcessFilters" {
        menu $m.desel$x -tearoff 0
        $m.desel$x add command -label deselect -command "processFilter $w del \"$alist\" ALIVE"
        $m add cascade -menu $m.desel$x -label "$alist"
        incr x
    }
    foreach alist "$ProcessFiltersOld" {
        menu $m.desel$x -tearoff 0
        $m.desel$x add command -label deselect -command "processFilter $w del \"$alist\" DEAD"
        $m add cascade -menu $m.desel$x -label "$alist"
        incr x
    }
    $m add separator
    menu $m.menu_dead_process -tearoff 0
    $m.menu_dead_process add radio -label "None" -variable FilterDeadProcess -value 0
    $m.menu_dead_process add radio -label "Latest one" -variable FilterDeadProcess -value 1
    $m.menu_dead_process add radio -label "All" -variable FilterDeadProcess -value -1
    $m add cascade -label "Keep filtering \"DEAD\" processes" -menu $m.menu_dead_process
    $m add separator
    $m add command -label "Clear All Process Filter" -command "processFilter $w clear"
    set x [winfo rootx $w]
    set y [expr [winfo rooty $w] + [winfo height $w]]
    tk_popup $m $x $y
}

proc processFilter {w action {alist ""} {which ""}} {
    global ProcessFilters ProcessFiltersOld
    puts "processFilter $action $alist $which"
    if {"$action" == "clear"} {
        set ProcessFilters ""
        set ProcessFiltersOld ""
    } else {
        if {"$which" == "ALIVE"} {
            set idx [lsearch -index 1 $ProcessFilters [lindex $alist 1]]
            if {$idx >= 0} {
                set ProcessFilters [lreplace $ProcessFilters $idx $idx ]
            }
        } elseif {"$which" == "DEAD"} {
            set idx [lsearch -index 1 $ProcessFiltersOld [lindex $alist 1]]
            if {$idx >= 0} {
                set ProcessFiltersOld [lreplace $ProcessFiltersOld $idx $idx ]
            }
        }
        if {"$action" == "add"} {
            lappend ProcessFilters "$alist"
        }
    }
    updateProcessFilterExpression
}

proc updateProcessFilterExpression {} {
    global ProcessFilters ProcessFilterExpression ProcessFiltersOld
    set plist ""
    foreach onep "$ProcessFilters $ProcessFiltersOld" {
        append plist "|[lindex $onep 0]"
    }
    set ProcessFilterExpression [string range $plist 1 end]
    updateProcessFilterStatus normal
}

proc updateProcessFilterStatus {status} {
    global ProcessFilterExpression wProcessFilter wProcessAndOr
    set w $wProcessFilter
    # puts "updateProcessFilterStatus plist: $ProcessFilterExpression status: $status"
    $w config -state $status
    $wProcessAndOr config -state $status

    set lcnt [llength $ProcessFilterExpression]
    if {$status == "normal"} {
        if {$lcnt > 0} {
            set status "$ProcessFilterExpression"
        } elseif {$lcnt == 0} {
            set status "select..."
        }
    } else {
        set status "$ProcessFilterExpression : $status"
    }
    $w config -text $status
}

proc changeProcessTagComplex {w} {
    global ProcessAndOrTag
    if {$ProcessAndOrTag == "or"} {
        set ProcessAndOrTag "and"
        $w config -text " AND "
    } elseif {$ProcessAndOrTag == "and"} {
        set ProcessAndOrTag "or"
        $w config -text " OR "
    }
}

proc updateProcessTagFilterExpression {isFileSource} {
    global ProcessAndOrTag ProcessFilterExpression TagFilter ProcessTagFilter
    set filter ""
    set tfilter ""
    if {$TagFilter != ""} {
        set tfilter "[checkEscapeAll [escapeSlash $TagFilter]]"
    }
    if {$isFileSource} {
        if {$tfilter != ""} {
            append filter "$tfilter"
        }
        set filter "/$filter/"
    } elseif {$ProcessAndOrTag == "or"} {
        if {$ProcessFilterExpression != ""} {
            append filter "|$ProcessFilterExpression"
        }
        if {$tfilter != ""} {
            append filter "|$tfilter"
        }
        set filter "/[string range $filter 1 end]/"
    } elseif {$ProcessAndOrTag == "and"} {
        set filter "/$ProcessFilterExpression/ && /$tfilter/"
    }
    set ProcessTagFilter "$filter"
}

proc showHistoryList {w} {
    global Device LoadedFiles
    set m .loadhistory
    if {[winfo exist $m]} {
        destroy $m
    }
    menu $m -tearoff 0
    foreach afile [lrange $LoadedFiles 0 19] {
        set afile [escapeSpace $afile]
        $m add command -label "$afile" -command "loadFile $afile"
    }
    set x [expr [winfo rootx $w] + [winfo width $w]]
    set y [winfo rooty $w]
    tk_popup $m $x $y
}

proc getSerial7 {serialraw} {
    set shortserial ""
    set len [string length $serialraw]
    if {$len <= 7} {
        set shortserial $serialraw
    } else {
        set shortserial "[string range $serialraw 0 2]..[string range $serialraw end-1 end]"
    }
    return $shortserial
}

proc updateSourceList {} {
    global Devices Device LoadFile PrevLoadFile LoadedFiles LoadFileMode AutoSaveDeviceLog
    foreach one [winfo children .top.sources] {
        # puts "destroy\ $one\ [winfo class $one]"
    #    if {[winfo class $one] == "Radiobutton"} {
        destroy $one
    #    }
    }
    set device_label [expr {($AutoSaveDeviceLog == 1) ? "Devices..>>" : "Devices.."}]
    pack [button .top.sources.devices -text $device_label -command detectDevices] -side left
    bind .top.sources.devices <2> "after 200 showOption:AutoSaveMode .top.sources.devices"
    bind .top.sources.devices <3> "after 200 showOption:AutoSaveMode .top.sources.devices"
    set dlen [llength $Devices]
    foreach device [lrange $Devices 0 2] {
        set seriallow [getSerial $device 1]
        set serialraw [getSerial $device]
        set splitname [split $device :]
        set model  [lindex $splitname 0]
        set port  [lindex $splitname 2]
        puts "serial raw: $serialraw low: $seriallow device: $device"
        if {$port != ""} {
            set name "$model:$serialraw"
            set seriallow [regsub -all {\.} $serialraw {_}]
        } else {
            set name "$model:[getSerial7 $serialraw]"
        }
        pack [radiobutton .top.sources.$seriallow -variable Device -value $device -command loadDevice -text $name] -side left
    }
    if {$dlen > 3} {
        pack [button .top.sources.otherdevices -text "Other.." \
        -command "listOtherDevices .top.sources.otherdevices"] -side left
    }
    set file_label [expr {($LoadFileMode == 1) ? "Files..>>" : "Files.."}]
    pack [button .top.sources.files -text $file_label -command loadFile] -side left
    foreach w "loadfile1 loadfile2 loadfile3" afile "[lrange $LoadedFiles 0 2]" {
        if {[file exists $afile]} {
            set afile [escapeSpace $afile]
            set f [file tail $afile]
            pack [radiobutton .top.sources.$w -variable Device -value "file:$afile" -text $f \
            -command "loadFile $afile"] -side left
        }
    }
    bind .top.sources.files <2> "after 200 showOption:FileLoadMode .top.sources.files"
    bind .top.sources.files <3> "after 200 showOption:FileLoadMode .top.sources.files"
    pack [button .top.sources.filehistory -text History -command "after 0 showHistoryList .top.sources.filehistory"] -side left
    #  showHistoryList
    #  bind .top.sources.filehistory <1> {tk_popup .loadhistory %X %Y}
}

proc listOtherDevices {w} {
    global Devices LoadedFiles
    set m .connectedDevices
    if {[winfo exist $m]} {
        destroy $m
    }
    menu $m -tearoff 0
    foreach device [lrange $Devices 3 end] {
        set serialraw [getSerial $device]
        set splitname [split $device :]
        set model [lindex $splitname 0]
        set port [lindex $splitname 2]
        puts "se: $serialraw  device: $device"
        if {$port != ""} {
            set name "$model:$serial"
        } else {
            set name "$model:[string range $serialraw 0 3]"
        }
        $m add radiobutton -label $name -value $device -variable Device -command loadDevice
    }
    set x [expr [winfo rootx $w] + [winfo width $w]]
    set y [winfo rooty $w]
    tk_popup $m $x $y
}

proc showOption:FileLoadMode {w} {
    global Device LoadFileMode
    set m .opt_load_file_mode
    if {[winfo exist $m]} {
        destroy $m
    }
    menu $m -tearoff 0
    $m add radiobutton -label "Load File Mode: One Shot" -variable LoadFileMode -value "0" \
    -foreground orange -command "$w config -text \"Files..\""
    $m add radiobutton -label "Load File Mode: Incrementaly" -variable LoadFileMode -value "1" -foreground green \
    -command "$w config -text \"Files..>>\""
    set x [expr [winfo rootx $w] + [winfo width $w]]
    set y [winfo rooty $w]
    tk_popup $m $x $y
}

proc showOption:AutoSaveMode {w} {
    global Device AutoSaveDeviceLog
    set m .opt_autp_save_device_log_mode
    if {[winfo exist $m]} {
        destroy $m
    }
    menu $m -tearoff 0
    $m add radiobutton -label "Auto Save Device Log Mode: None" -variable AutoSaveDeviceLog -value "0" \
    -foreground orange -command "$w config -text \"Devices..\""
    $m add radiobutton -label "Auto Save Device Log Mode: Auto" -variable AutoSaveDeviceLog -value "1" -foreground green \
    -command "$w config -text \"Devices..>>\""
    set x [expr [winfo rootx $w] + [winfo width $w]]
    set y [winfo rooty $w]
    tk_popup $m $x $y
}

proc openEditor {} {
    global LoadFile Editor OS
    set editor [escapeSpace $Editor]
    puts "Editor: $editor, LoadFile: $LoadFile"
    if {[file readable $Editor] && [file readable $LoadFile]} {
        if {$OS == "Darwin" && [file isdirectory $Editor] &&
         ([string match "*.app" "$Editor"] || [string match "*.app/" "$Editor"])} {
            after 100 "exec open -a $editor $LoadFile &"
        } else {
            after 100 "exec $editor $LoadFile &"
        }
    }
}

proc selectAlllines {} {
}

proc selectLines {{opt all}} {
    global LogView
    $LogView config -state normal
    if {"all" == "$opt"} {
        $LogView tag add sel 1.0 end        
    }
    $LogView config -state disabled
#ttk::button $LogView.b -text "Push Me"
#$LogView window create 1.0 -window $LogView.b
}

proc onlyFocusEntry {} {
    wVector . {$clazz != "Text" && $clazz != "Entry" && $w != "."} "config -takefocus 0"
}

proc setupEntryKeyPressFilter {} {
    wBinder . {$clazz == "Entry"} "KeyPress" {+set LastKeyPress %K}
    wVector . {$clazz == "Entry"} "config -validate key -vcmd entryVcmd"
}

proc wVector {w {cond "1"} {cmd ""}} {
    set clazz [winfo class $w]
    if {[expr $cond]} {
        if {$cmd == ""} {
            puts "$clazz $w"
        } else {
            eval $w $cmd
        }
    }
    foreach w_child [winfo children $w] {
        wVector $w_child $cond $cmd
    }
}

proc wBinder {w {cond "1"} {key} {cmd ""}} {
    set clazz [winfo class $w]
    if {[expr $cond]} {
        if {$cmd == ""} {
            puts "$clazz $w"
        } else {
            bind $w <$key> "$cmd"
        }
    }
    foreach w_child [winfo children $w] {
        wBinder $w_child $cond $key $cmd
    }
}

proc checkAdbPath {{w ""} {w2 ""} args} {
    global SDK_PATH ADB_PATH
    puts "checkAdbPath $args"
    set status "Not confirmed"
    set statusSdk $status
    set statusConst 0;# NOT_CONFIRMED
    set bgAdb red
    set bgSdk $bgAdb
    set laterEnabled normal
    if {[file isdirectory $SDK_PATH/platform-tools] &&
        [file isdirectory $SDK_PATH/build-tools] &&
        [file isdirectory $SDK_PATH/tools]} {
        set statusSdk "confirmed"
        set bgSdk green
        # puts [exec /usr/bin/find $SDK_PATH -maxdepth 2 -type f -name "adb*"]
        if {[file executable $SDK_PATH/tools/adb]} {
            set ADB_PATH $SDK_PATH/tools/adb
        } elseif {[file executable $SDK_PATH/tools/adb.exe]} {
            set ADB_PATH $SDK_PATH/tools/adb.exe
        } elseif {[file executable $SDK_PATH/platform-tools/adb]} {
            set ADB_PATH $SDK_PATH/platform-tools/adb
        } elseif {[file executable $SDK_PATH/platform-tools/adb.exe]} {
            set ADB_PATH $SDK_PATH/platform-tools/adb.exe
        }
    } elseif {[file executable $SDK_PATH/adb]} {
        set ADB_PATH "$SDK_PATH/adb"
    } else {
        set ADB_PATH ""
    }
    if {[file executable $ADB_PATH]} {
        set status "confirmed"
        set statusConst 1;# CONFIRMED
        set bgAdb green
        set laterEnabled disabled
        updateSourceList
    }
    if [winfo exist $w] {
        $w.statusadb.val config -text "$status: \"$ADB_PATH\"" -bg $bgAdb
        $w.statussdk.val config -text "$statusSdk: \"$SDK_PATH\"" -bg $bgSdk
        $w.later config -state $laterEnabled
    }
    if [winfo exist $w2] {
        $w2 config -text "$status: \"$ADB_PATH\"" -bg $bgAdb
    }
    return $statusConst
}

proc getAdbPath {{parentWin ""} {w2 "none"}} {
    global SDK_PATH NO_ADB
    set w "${parentWin}.sdkpath"
    if [winfo exist $w] {
        raise $w
        return
    }
    toplevel $w
    wm title $w "Setup ADB_PATH"
    wm transient $w .
    wm minsize $w 500 140
    wm maxsize $w 9000 140
    # after 100 grab set -global $w
    wm protocol $w WM_DELETE_WINDOW "setTraceAdbPath $w $w2 0; destroy $w"
    pack [frame $w.btm -relief raised] -side bottom
    pack [button $w.btm.close -text Close -command "setTraceAdbPath $w $w2 0; destroy $w"] -side right
    pack [label  $w.msg -text "Please locate \"adb including directory\" or \"Android SDK directory\"."]
    pack [set wi [frame  $w.inputarea -relief ridge]] -fill x -expand yes
    pack [button  $wi.browse -text browse \
        -command {set SDK_PATH [tk_chooseDirectory -initialdir ~ \
        -title "Choose \"adb including directory\" or \"Android SDK directory\""]}] -side right
    pack [entry  $wi.path -textvariable SDK_PATH] -expand yes -fill x
    pack [set ws1 [frame  $w.statusadb -relief ridge]] -fill x -expand yes
    pack [label $ws1.msg -text "status of adb path:"] -side left
    pack [label $ws1.val] -side left
    pack [set ws2 [frame  $w.statussdk -relief ridge]] -fill x -expand yes
    pack [label $ws2.msg -text "status of SDK path:"] -side left
    pack [label $ws2.val] -side left
    pack [checkbutton $w.later -text "Setup ADB_PATH later" -variable NO_ADB] -side bottom
#   set SDK_PATH ""
#   set ADB_PATH ""
    checkAdbPath $w
    setTraceAdbPath $w $w2 1
}

proc setTraceAdbPath {w w2 on} {
    global SDK_PATH
    if {$on} {
        trace variable SDK_PATH w "after 1000 checkAdbPath $w $w2"
    } else {
        trace vdelete  SDK_PATH w "after 1000 checkAdbPath $w $w2"
    }
}

## init procedures
loadPreference
loadLastState
updateProcessFilterStatus disabled
onlyFocusEntry
#wVector . 1 "config -takefocus"
setupEntryKeyPressFilter
#bind $fsrch.hword1 <Key-Up> "seekHighlight colorLbl up"
#detectDevices
if {!$NO_ADB} {
    if {[checkAdbPath]} {
        puts "ADB_PATH already confirmed."
        return
    }
    updateSourceList
    after 2000 getAdbPath
}
setEditor
#getProcessPackageList

