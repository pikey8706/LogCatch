# Windows

wm deiconify .
wm title . $AppName
wm protocol . WM_DELETE_WINDOW safeQuit
image create photo app_icon -file $runDir/icon_logcatch.gif
wm iconphoto . app_icon
# Encoding
# encoding system $Encoding
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
    after 300 refreshGeometry $w
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

source $runDir/reading/logtype.tcl

# right pane
set r [frame .p.rf]
pack $r -side right -anchor e -fill both -expand yes -padx 5 -pady 5

set hks [frame .p.rf.hks];# -bg lightblue
pack $hks -fill x
pack [labelframe $hks.loglevelframe -text "LogLevel: " -labelanchor w] -side left -padx 2
set LogLevelView ".p.rf.hks.loglevelframe.loglevel"
pack [ttk::combobox $LogLevelView -textvariable LogLevel(selected) -state readonly -values $LogLevelsLong -width 7] -side left
bind $LogLevelView <<ComboboxSelected>> "after 300 openSource"

set wProcessFilter $hks.process
if {$UseGnuAwk} {
    pack [checkbutton $hks.toggle_case_insensitive -text "Ignore case for filters.   " -command "after 300 openSource" -variable IgnoreCaseFilter -relief ridge] -side left
}
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

# Clear Log
pack [button $fsrch.clr -text "Clear Log" -command clearLogView] -side right
# Highlight
pack [label $fsrch.highlight -text "Highlight:"] -side left
global LogLevelTags TextViewColorOptions
set LogLevelTags [list colorBlk colorBlu colorGre colorOrg colorRed colorBlk colorBlk]
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
    bind ${fsrch}.hword${colorIndex} <Triple-Left> "nearHighlight $colorTag %K %i"
    bind ${fsrch}.hword${colorIndex} <Triple-Right> "nearHighlight $colorTag %K %i"
    set HighlightWord($colorTag) "${fsrch}.hword${colorIndex} 0 0 {} {}"
    if {$OS == "Darwin"} {
        ${fsrch}.hword${colorIndex} config -width 13
    }
    incr colorIndex
}

# logview text/listbox
set LogView $r.l
puts "TextView Options: $TextViewColorOptions"
eval text $r.l $TextViewColorOptions -xscrollcommand \"$r.s0 set\" -yscrollcommand \"$r.s1 set\" -wrap $WrapMode
scrollbar $r.s0 -orient horizontal -command "$r.l xview"
scrollbar $r.s1 -command "$r.l yview"
bind $LogView <1> "focus $LogView"
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
$logview config -font $LogViewFontName
set LogViewFontSize [font config $LogViewFontName -size]
if {$OS == "Linux"} {
    bind $logview <Control-Button-4> "+ changeFontSize LogViewFontName LogViewFontSize 1"
    bind $logview <Control-Button-5> "+ changeFontSize LogViewFontName LogViewFontSize -1"
} else {
    bind $logview <Control-MouseWheel> "+ changeFontSize LogViewFontName LogViewFontSize %D"
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

wrapMenu

