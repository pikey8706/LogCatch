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
set CONST_ENCODING "utf-8"
set LogTypes "brief process tag thread raw time threadtime long"
set Devices ""
set Device ""
set Fd ""
set PrevLoadFile ""
set LoadFile ""
set LoadedFiles ""
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
set OS [exec uname -s]
# set StartLabel "--- Start Viewing Log ---\n"
# set EndLabel "--- End Of File reached ---\n"
set ReadingLabel "Reading..."
set EOFLabel "End Of File"
set Encoding $CONST_ENCODING
set ProcessPackageList ""
set ProcessFilters ""
set ProcessFilterList ""
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
set hWord1 ""
set hWord1Color "#ff7777"
set hWord1Cnt ""
set hWord2 ""
set hWord2Color "#ff7777"
set hWord2Cnt ""
set hWord3 ""
set hWord3Color "#ff7777"
set hWord3Cnt ""
set AUTO_HIGHLIGHT_DELAY 1111

set LastKeyPress ""

# Update
set trackTailTask ""

# Editor
set Editor ""

# Clear Auto
set ClearAuto none

# Menu Face
set MenuFace bar; # bar button both

# Font fot logview
set LogViewFont TkTextFont

proc setEditor {} {
    global Editor OS
    # first check EDITOR env
    if {[info exist env(EDITOR)] && $env(EDITOR) != ""} {
        set Editor $env(EDITOR)
    }
    # default for each platform
    if {$Editor == ""} {
       if {$OS == "Darwin"} {
	  set Editor TextEdit
       } elseif {$OS == "Linux"} {
	  set Editor Nano
       } else {
	  set Editor Notepad
       }
   }
}

# Windows
wm deiconify .
wm title . $AppName
wm protocol . WM_DELETE_WINDOW safeQuit
#image create photo app_icon -file lc_icon.gif
#wm iconphoto . app_icon
# Encoding
encoding system $Encoding
# bottom status line
frame .b -relief sunken
pack .b -side bottom -fill x
pack [label .b.1 -text "0" -relief sunken] -side left
pack [label .b.2 -text $EOFLabel -relief sunken -fg red] -side left
pack [checkbutton .b.stick -text TrackTail -command "trackTail" -variable TrackTail -relief sunken] \
	-side right -padx 3
pack [label .b.wmode -text LineWrap -relief sunken] -side right
pack [label .b.encode -text Encoding -relief sunken] -side right
pack [label .b.logtype -text "LogType:" -relief sunken] -side right
pack [label .b.3 -text "Source:" -relief ridge] -side left
pack [button .b.b -text Editor -command openEditor] -side left

# top menu
menu .mbar
. config -menu .mbar
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
pack $t -side top -fill x
#pack [button $t.rec -text Rec] -side left
#image create photo menu_icon -file menu.gif
button $t.menu -text Menus -command "menuLogcatch $t.menu" ;# -image menu_icon

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
    toplevel $w
    wm title $w "Preferences"
    wm protocol $w WM_DELETE_WINDOW "destroy $w"
    pack [frame $w.bottom -relief raised] -fill x -expand yes -side bottom -anchor s
    pack [button $w.bottom.close -text Close -command "destroy $w"] -side right
    pack [frame $w.f1] -fill x
    pack [label $w.f1.adblocationlabel -text "ADB_PATH : "] -side left
    pack [label $w.f1.adblocation -text "$ADB_PATH"] -side left
    pack [button $w.f1.changeadblocation -text "Change" -command "getAdbPath $w.f1.adblocation"] -side right
    pack [frame $w.f2] -fill x
    pack [label $w.f2.menubarormenubutton -text "Menu Face: "] -side left
    pack [radiobutton $w.f2.menubar -text "Menubar" -value bar -variable MenuFace -command "changeMenuFace"] -side left
    pack [radiobutton $w.f2.menubutton -text "MenuButton" -value button -variable MenuFace -command "changeMenuFace"] -side left
}

proc changeMenuFace {args} {
    global MenuFace
    if {$MenuFace == "bar"} {
        . config -menu .mbar
        pack forget .top.menu
    } elseif {$MenuFace == "button"} {
        . config -menu ""
        pack .top.menu -side right
    } elseif {$MenuFace == "both"} {
        # button case.
        . config -menu .mbar
        pack .top.menu -side right
    }
}

proc showHistoryBrowser {} {

}

#pack [button $t.clr -text "Clear Log" -command clearLogView -padx 20] -side right
pack [labelframe $t.sources -text "Source" -labelanchor w] -side left

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
pack [button $hks.or -text " OR " -command "changeProcessTagComplex $hks.or"] -side left
pack [label $hks.taglbl -text "TagFilter: "] -side left
pack [entry $hks.tagent -textvariable TagFilter -width 50] -side left
bind $hks.tagent <Return> openSource

# Filter entry
set filsi [frame .p.rf.filsi];# -bg lightblue
pack $filsi -fill x
pack [label $filsi.li -text "Filter Inclusive:"] -side left
pack [entry $filsi.ei -textvariable iFilter] -side left -expand y -fill x
pack [button $filsi.be -text Clear -command "set iFilter \"\"" -takefocus 0] -side right
set filse [frame .p.rf.fils];# -bg lightblue
pack $filse -fill x
pack [label $filse.le -text "Filter Exclusive:"] -side left
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

# Highlight
pack [label $fsrch.highlight -text "Highlight:"] -side left
pack [entry $fsrch.hword1 -textvariable hWord1 -bg lightblue] -side left
pack [label $fsrch.hword1cnt -text "" -bg lightblue] -side left
pack [entry $fsrch.hword6 -textvariable hWord6 -bg aquamarine1] -side left
pack [label $fsrch.hword6cnt -text "" -bg aquamarine1] -side left
pack [entry $fsrch.hword2 -textvariable hWord2 -bg lightgreen] -side left
pack [label $fsrch.hword2cnt -text "" -bg lightgreen] -side left
pack [entry $fsrch.hword7 -textvariable hWord7 -bg yellow] -side left
pack [label $fsrch.hword7cnt -text "" -bg yellow] -side left
pack [entry $fsrch.hword5 -textvariable hWord5 -bg LightSalmon1] -side left
pack [label $fsrch.hword5cnt -text "" -bg LightSalmon1] -side left
pack [entry $fsrch.hword3 -textvariable hWord3 -bg pink] -side left
pack [label $fsrch.hword3cnt -text "" -bg pink] -side left
pack [entry $fsrch.hword4 -textvariable hWord4 -bg white] -side left
pack [label $fsrch.hword4cnt -text "" -bg white] -side left
if {$OS == "Darwin"} {
    foreach idx {1 2 3 4 5 6 7} {
        $fsrch.hword${idx} config -width 15
    }
}
bind $fsrch.hword1 <Return> "highlightWord colorLbl"
bind $fsrch.hword2 <Return> "highlightWord colorLgr"
bind $fsrch.hword3 <Return> "highlightWord colorPnk"
bind $fsrch.hword4 <Return> "highlightWord colorWht"
bind $fsrch.hword5 <Return> "highlightWord colorLSm"
bind $fsrch.hword6 <Return> "highlightWord colorAQm"
bind $fsrch.hword7 <Return> "highlightWord colorYel"
bind $fsrch.hword1 <KeyPress> "autoHighlight colorLbl"
bind $fsrch.hword2 <KeyPress> "autoHighlight colorLgr"
bind $fsrch.hword3 <KeyPress> "autoHighlight colorPnk"
bind $fsrch.hword4 <KeyPress> "autoHighlight colorWht"
bind $fsrch.hword5 <KeyPress> "autoHighlight colorLSm"
bind $fsrch.hword6 <KeyPress> "autoHighlight colorAQm"
bind $fsrch.hword7 <KeyPress> "autoHighlight colorYel"
bind $fsrch.hword1 <KeyPress> "+seekHighlight colorLbl %K"
bind $fsrch.hword2 <KeyPress> "+seekHighlight colorLgr %K"
bind $fsrch.hword3 <KeyPress> "+seekHighlight colorPnk %K"
bind $fsrch.hword4 <KeyPress> "+seekHighlight colorWht %K"
bind $fsrch.hword5 <KeyPress> "+seekHighlight colorLSm %K"
bind $fsrch.hword6 <KeyPress> "+seekHighlight colorAQm %K"
bind $fsrch.hword7 <KeyPress> "+seekHighlight colorYel %K"
set HighlightWord(colorLbl) "$fsrch.hword1 0 0 1.0 {}"
set HighlightWord(colorLgr) "$fsrch.hword2 0 0 1.0 {}"
set HighlightWord(colorPnk) "$fsrch.hword3 0 0 1.0 {}"
set HighlightWord(colorWht) "$fsrch.hword4 0 0 1.0 {}"
set HighlightWord(colorLSm) "$fsrch.hword5 0 0 0.0 {}"
set HighlightWord(colorAQm) "$fsrch.hword6 0 0 0.0 {}"
set HighlightWord(colorYel) "$fsrch.hword7 0 0 0.0 {}"

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

# Clear Log
pack [button $fsrch.clr -text "Clear Log" -command clearLogView] -side right

# entry
#pack [entry .p.rf.e ] -fill x

# logview text/listbox
if {1} {
set LogView $r.l
text $r.l -bg "#000000" -xscrollcommand "$r.s0 set" -yscrollcommand "$r.s1 set" -wrap $WrapMode
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
# click menu
$logview tag config colorBlk -foreground white
$logview tag config colorBlu -foreground lightblue
$logview tag config colorGre -foreground chartreuse3;# "#15b742"
$logview tag config colorOrg -foreground orange
$logview tag config colorRed -foreground red
global tags
set tags [list colorBlk colorBlu colorGre colorOrg colorRed]

# search colors
$logview tag config colorYel -background yellow -foreground black
$logview tag config colorPnk -background pink -foreground black
$logview tag config colorPup -background purple -foreground white
$logview tag config colorOra -background orange -foreground black -relief raised
# search highlight colors
$logview tag config colorWht -background white -foreground black
$logview tag config colorLbl -background lightblue -foreground black
$logview tag config colorLgr -background lightgreen -foreground black
$logview tag config colorLSm -background LightSalmon1 -foreground black
$logview tag config colorAQm -background aquamarine1 -foreground black

menu .logmenu -tearoff 0
.logmenu add command -label "Save all lines" -command "saveLines all"
.logmenu add command -label "Save selected lines" -command "saveLines selected"
.logmenu add command -label "Select all lines" -command "selectLines all"
.logmenu add separator
.logmenu add cascade -menu .logmenu.hi -label "Highlight selected keyword"
.logmenu add separator
.logmenu add cascade -menu .logmenu.fi -label "Add Filter Inclusive"
.logmenu add cascade -menu .logmenu.fe -label "Add Filter Exclusive"
.logmenu add separator
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
.logmenu.clear add cascade -menu .logmenu.clear.auto -label "Clear Auto .."
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
    global tags LogLevels LastLogLevel
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
    return [lindex $tags $index]
}

proc logcat {{clear 1} fd {doFilter 0}} {
    global logview Device Fd LineCount TrackTail

    if {$Fd == ""} {
       tk_messageBox -title "Error" -message "Failed to open log: $Device ." -type ok -icon error
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
    }
}

proc readLine {fd} {
     global logview LineCount statusOne statusTwo MaxRow TrackTail trackTailTask EndLabel EOFLabel
     $logview config -state normal
     if {[eof $fd]} {
         #$logview insert end $EndLabel colorBlk
	 $logview config -state disabled
	 $statusTwo config -text $EOFLabel -fg red
	 closeFd
	 return
     }

     gets $fd line

     if {"$line" != ""} {
        set loglevel [getLogLevel "$line"]
	set tag [getTag $loglevel]
	incr LineCount
	$logview insert end "$line\n" $tag
	$logview config -state disabled
	$statusOne config -text $LineCount
	updateView
    }
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
	clearSearchAll
	clearHighlightAll
	openSource
    } else {
puts not\ radable
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
    global Devices Device
    set devices $Device
    foreach xdevice $Devices {
	if {![string match $Device $xdevice]} {
	   lappend devices $xdevice
	}
    }
    set Devices $devices
    updateSourceList
    openSource
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

proc encodingMenu {} {
  global Encoding Codes runDir
  set defaultCode "utf-8"
  set lists [lsort [encoding names]]
  set defIdx [lsearch $lists $defaultCode]
  set m .encodings
  menu $m -tearoff 0
  if {$defIdx > -1} {
     $m add radiobutton -label "Default: $defaultCode" -value $defaultCode -variable Encoding -command changeEncoding
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
        $gmenu add radiobutton -label "$two" -value $two -variable Encoding -command changeEncoding
      }
    }

  }
  bind .b.encode <1> "tk_popup $m %X %Y"
}

proc changeEncoding {} {
  global Encoding
  encoding system $Encoding
  .b.encode config -text "encoding: $Encoding"
  update idletasks
  puts "changeEncoding to :${Encoding}:"
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
puts safequit
    closeFd
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
            exec mkdir -p $dir
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
TagFilter
    set dir "$env(HOME)/.logcatch"
    set loadStateFile "last.state"
    if {! [file isdirectory $dir]} {
            exec mkdir -p $dir
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
	    puts $fdW ":"
        close $fdW
    }
}

proc loadLastState {} {
    global LoadedFiles env WrapMode iFilter eFilter sWord Editor SDK_PATH ADB_PATH NO_ADB MenuFace TagFilter
    set dir "$env(HOME)/.logcatch"
    set loadLastState "last.state"
    if {! [file isdirectory $dir]} {
	    exec mkdir -p $dir
    }
    if {! [file isdirectory $dir]} {
            return
    }
    if {! [file readable $dir/$loadLastState]} { return }
    set fd [open $dir/$loadLastState r]
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
		} else {
                }
        }
	close $fd
	updateLoadedFiles
	changeWrapMode
	changeEncoding
        changeMenuFace
    }
}

proc openSource {} {
    global Fd LoadFile eFilter iFilter Device LineCount LevelFilter LevelAndOr \
	statusTwo status3rd AppName ADB_PATH LogType ReadingLabel ProcessFilterList TagFilter ProcessTagFilter
    closeFd
    set deny "!"
    updateProcessTagFilter
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
puts "ptag: $ProcessTagFilter"

    if {[string match "file:*" $Device]} {
      updateProcessFilterStatus disabled
      set lvlstate normal
      if {$LogType == "raw"} {
         set lvlAndOr "||"
         set lvlstate disabled
      }
#      foreach w {v d i w e andor} {
#       .p.rf.hks.${w} config -state $lvlstate
#      }
set Fd [open "| awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" $LoadFile" r]
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
        set LogType time
        reloadProc
#set Fd [open "|$ADB_PATH -s $device logcat -v time | awk \"NR > 0 &&  $deny /$xeFilter/ && (/$ProcessFilterList/ && (/$TagFilter/ && /$xiFilter/)) {print}{fflush()}\" " r]
set Fd [open "|$ADB_PATH -s $device logcat -v time | awk \"NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
    }
    puts "src: $Device fd: $Fd"
    puts "LevelFilter => $LevelFilter $lvlAndOr"
    puts "eFilter: $xeFilter"
    puts "ifilter: $xiFilter"
    $statusTwo config -text $ReadingLabel -fg "#15b742"
    $status3rd config -text "Source: $Device"
    .b.logtype config -text "LogType: $LogType"
    wm title . "$AppName Source: $title"
    if {$Fd != ""} {
	set LineCount 0
        logcat 1 $Fd
    } else {
puts "$Fd null"
    }
}

proc closeFd {} {
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
#        $w tag add colorWht $s.0 $s.end
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
  if {$sCnt == 0} {
      ${wentry}cnt config -text ""
  } else {
      ${wentry}cnt config -text $sCnt
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
  if {$key == "Up" || $key == "Down"} {
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
      if {$key == "Up"} {
          if {$err} {
              set seekFirst [$logview index ${colorTag}.last]
              set idx [expr $sCnt + 1]
          }
          set indexes [$logview tag prevrange $colorTag $seekFirst]
          if {$indexes != ""} {
	      incr idx -1
          }
      } else {
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
  #  $logview insert 1.0 $StartLabel colorBlk
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
    set filename [tk_getSaveFile -parent . -initialdir $dir]
    if {$filename == ""} {
       return
    }
    set wp [open $filename w]
    if {$wp != ""} {
      set texts [$logview get $sdx $edx]
      puts $wp $texts
      close $wp
      addLoadedFiles $filename
    }
}

proc getModel {device} {
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
      return
  }
  foreach line [lrange [split [exec $ADB_PATH devices -l] \n] 1 end] {
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
#	  if {$model == "null"} {
             set model [getModel $serial]
#          }
	  lappend devices "$model:$serial"
      }
  }
  set Devices $devices
  return $devices
}

proc getSerial {device {lower 0}} {
  if {$lower} {
    return [string tolower [lindex [split $device :] 1]]
  } else {
    return [lindex [split $device :] 1]
  }
}

proc detectDevices {} {
  global Device Devices OS
  getDevices
  set idx [expr {$OS =="Darwin" ? "2" : "3"}]
  .mbar.i.d delete $idx end
  foreach device $Devices {
    .mbar.i.d add radiobutton -label $device -variable Device -value $device -command loadDevice
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
		lappend lists "$pId $pkgName"
	    }
	}
	set lists [lsort -integer -index 0 -decr $lists] 
   }
   set ProcessPackageList $lists
   return $lists
}

proc updateProcessFilters {} {
    global ProcessPackageList ProcessFilters ProcessFilterList
    set pFilters ""
    foreach p [split $ProcessFilterList "|"] {
      set idx [lsearch -index 0 $ProcessFilters $p]
      set alist [lindex $ProcessFilters $idx]
      set pkg [lindex $alist 1]
      set pidx [lsearch -index 1 $ProcessPackageList $pkg]
      if {$pidx >= 0} {
        set blist [lindex $ProcessPackageList $pidx]
        lappend pFilters $blist
        set newP [lindex $blist 0]
#        append pFilterList "|$newP"
        puts "updateProcessFilters oldProcess: $p newProcess: $newP newlist: $blist"
      }
    }
    set ProcessFilters $pFilters
    updateProcessFilterList
}

proc showProcessList {w} {
    global ProcessFilters
    set m .processlist
    if {[winfo exist $m]} {
      destroy $m
    }
    menu $m -tearoff 0
    menu $m.plist -tearoff 0
    $m add cascade -menu $m.plist -label "Add Process Filter"
    $m add separator
    set lists [getProcessPackageList]
    updateProcessFilters
    set cnt 0
    set mod 31
    set mx $m.plist
    foreach alist $lists {
	incr cnt
	if {[expr $cnt % $mod] == 0} {
   	   menu $mx.plist -tearoff 0
	   $mx add cascade -menu $mx.plist -label "More.."
	   set mx $mx.plist
        }
	set pId [lindex $alist 0]
	$mx add command -label "$alist" -command "processFilter $w add \"$alist\""
    }
    set x 0
    foreach alist $ProcessFilters {
	menu $m.desel$x -tearoff 0
	$m.desel$x add command -label deselect -command "processFilter $w del \"$alist\""
	$m add cascade -menu $m.desel$x -label "$alist"
	incr x
    }
    $m add separator
    $m add command -label "Clear All Process Filter" -command "processFilter $w clear"
    set x [winfo rootx $w]
    set y [expr [winfo rooty $w] + [winfo height $w]]
    tk_popup $m $x $y
}

proc processFilter {w action {alist ""}} {
  global ProcessFilters ProcessFilterList
  puts "processFilter $action $alist"
  if {"$action" == "clear"} {
    set ProcessFilters ""
  } else {
    set idx [lsearch -index 0 $ProcessFilters [lindex $alist 0]]
    if {$idx >= 0} {
      set ProcessFilters [lreplace $ProcessFilters $idx $idx ]
    }
    if {"$action" == "add"} {
       lappend ProcessFilters "$alist"
    }
  }
  updateProcessFilterList
}

proc updateProcessFilterList {} {
  global ProcessFilters ProcessFilterList
  set plist ""
  foreach onep $ProcessFilters {
    append plist "|[lindex $onep 0]"
  }
  set ProcessFilterList [string range $plist 1 end]
  updateProcessFilterStatus normal
}

proc updateProcessFilterStatus {status} {
  global ProcessFilters ProcessFilterList wProcessFilter
  set w $wProcessFilter
# puts "updateProcessFilterStatus plist: $ProcessFilterList status: $status"
  $w config -state $status

  if {$status == "normal"} {
    set lcnt [llength $ProcessFilterList]
    if {$lcnt > 0} {
      set status "$ProcessFilterList"
    } elseif {$lcnt == 0} {
      set status "select..."
    }
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

proc updateProcessTagFilter {} {
    global ProcessAndOrTag ProcessFilterList TagFilter ProcessTagFilter
    set filter ""
    set tfilter ""
    if {$TagFilter != ""} {
        set tfilter "[checkEscapeAll [escapeSlash $TagFilter]]"
    }
    if {$ProcessAndOrTag == "or"} {
        if {$ProcessFilterList != ""} {
            append filter "|$ProcessFilterList"
        }
        if {$tfilter != ""} {
            append filter "|$tfilter"
        }
        set filter "/[string range $filter 1 end]/"
    } elseif {$ProcessAndOrTag == "and"} {
        set filter "/$ProcessFilterList/ && /$tfilter/"
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
  global Devices Device LoadFile PrevLoadFile LoadedFiles
  foreach one [winfo children .top.sources] {
      # puts "destroy\ $one\ [winfo class $one]"
#    if {[winfo class $one] == "Radiobutton"} {
      destroy $one
#    }
  }
  pack [button .top.sources.devices -text "Devices.." -command detectDevices] -side left
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
  pack [button .top.sources.files -text "Files.." -command loadFile] -side left
  foreach w "loadfile1 loadfile2 loadfile3" afile "[lrange $LoadedFiles 0 2]" {
    if {[file exists $afile]} {
       set afile [escapeSpace $afile]
       set f [file tail $afile]
       pack [radiobutton .top.sources.$w -variable Device -value "file:$afile" -text $f \
	   -command "loadFile $afile"] -side left
    }
  }
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

proc openEditor {} {
    global LoadFile Editor OS
    if {$Editor != "" && [file readable $LoadFile]} {
       if {$OS == "Darwin"} {
           after 100 "exec open -a $Editor $LoadFile &"
        } else {
	   after 100 "exec $Editor $LoadFile &"
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

if {$OS == "Darwin"} {
  proc tk::mac::Quit {} {
      safeQuit
  }
  $LogView config -font systemSystemFont
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

proc getAdbPath {{w2 "none"}} {
    global SDK_PATH NO_ADB
    set w .sdkpath
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
    pack [checkbutton $w.later -text "Setup ADB_PATH Later" -variable NO_ADB] -side bottom
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
    getAdbPath
}

#getProcessPackageList

