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
set CONST_DEFAULT_LOGLEVEL "V"
set Devices ""
set Device ""
set Fd ""
set AutoSaveDeviceLog 0; # default: 0
set AutoSaveFileName ""
set HOME_PATH [regsub -all {\\} $env(HOME) {/}]; # } switch windows path to unix path
set AutoSaveDirectory "$HOME_PATH/${AppName}_AutoSavedDeviceLogs"
set AutoSaveProcessId ""
set LoadFile ""
set LoadFiles ""
set LoadedFiles ""
set LoadFileMode 0; # 0: Load file one shot, 1: load file incrementaly
set LineCount 0
set statusOne .b.1
set statusTwo .b.2
set status3rd .b.3
set MaxRow 2500
set TrackTail 0
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
set IgnoreCaseFilter 0
set UseGnuAwk 0
set LogView ""
set LastLogLevel "V"
set Win "."

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

proc checkGnuAwk {} {
    global UseGnuAwk
    set foundStatus [catch {exec awk --version | grep -qs "GNU Awk"}]
    set UseGnuAwk [expr $foundStatus == 0 ? 1 : 0]
    puts "UseGnuAwk: $UseGnuAwk"
}
checkGnuAwk

# Windows
source $runDir/ui/windows.tcl


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

proc getTag {loglevel} {
    global LogLevelTags LogLevels LastLogLevel CONST_DEFAULT_LOGLEVEL
    set index [lsearch $LogLevels $loglevel]
    if {$index == -1} {
        set index [lsearch $LogLevels $LastLogLevel]
        if {$index > -1} {
            set loglevel $LastLogLevel
        } else {
            set loglevel $CONST_DEFAULT_LOGLEVEL
            set index [lsearch $LogLevels $loglevel]
        }
    }
    set LastLogLevel $loglevel
    return [lindex $LogLevelTags $index]
}

proc logcat {{clear 1} fd {doFilter 0}} {
    global logview Device Fd Encoding LineCount TrackTail

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
        fconfigure $Fd -encoding $Encoding
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
        set acceptLevel [checkAcceptLevel $loglevel]
        if {$acceptLevel} {
            set tag [getTag $loglevel]
            incr LineCount
            $logview insert end "$line\n" $tag
            $logview config -state disabled
            $statusOne config -text $LineCount
            updateView
        }
    #}
}

proc updateView {} {
    global trackTailTask LineCount
    if {"$trackTailTask" != ""} {
        after cancel $trackTailTask
    }
    set trackTailTask [after 200 trackTail]

    if {$LineCount%100 == 0} {
        update idletasks
    }
}

proc checkAcceptLevel {loglevel} {
    global LogLevels LogLevelsLong LogLevel LogType
    # puts "checkAcceptLevel: $loglevel"
    if {$LogType == "none"} {
        return 1
    }
    set sel_index [lsearch $LogLevelsLong $LogLevel(selected)]
    set index [lsearch $LogLevels $loglevel]
    if {$sel_index <= $index} {
        return 1
    } else {
        return 0
    }
}

proc updateLogLevelView {} {
    global LogType LogLevelView
    set state [expr {($LogType == "none") ? "disabled" : "readonly"}]
    $LogLevelView config -state $state
}

proc loadFile {{filenames ""}} {
    global Fd LoadFile LoadFiles LoadedFiles LoadFileMode Device LogType
    set filename ""
    if {$filenames == ""} {
        set dir ~
        if {$LoadFile != ""} {
            set dir [file dirname $LoadFile]
        }
        set multiple [expr {!$LoadFileMode ? true : false}]
        set filenames [tk_getOpenFile -multiple $multiple -parent . -initialdir $dir]
    }
    set fileCount [llength $filenames]
    if {$LoadFileMode && $fileCount > 1} {
        tk_messageBox -title "" -message "Select one file in Load_File_Mode: Incremental." -type ok -icon error
        return
    }
    set filename [lindex $filenames 0]
    puts \"$filenames\"

    if [file readable $filename] {
        checkLogType "$filename"
        updateLogLevelView
        reloadProc
        set LoadFile $filename
        set LoadFiles $filenames
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
    lappend files $filename
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

proc changeWrapMode {args} {
    global WrapMode logview
    .b.wmode config -text "LineWrap: $WrapMode"
    $logview config -wrap  $WrapMode
    update idletasks
    puts "changeWrapMode $WrapMode"
}

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
    # encoding system $encoding
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
    after 300 refreshGeometry $w
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

proc showAbout {} {
    set w [toplevel .about]
    pack [button $w.close -text Close -command "destroy $w"] -side bottom
    pack [label $w.whoami -text "This is android logcat viewer by tcl/tk."]
    after 300 refreshGeometry $w
}

proc safeQuit {} {
    catch {puts safequit} msg
    closeLoadingFd
    closeWaitingFd
    stopAutoSavingFile
    saveLastState
    exit 0
}

proc saveLastState {} {
    global env LoadedFiles iFilter eFilter WrapMode sWord Editor Encoding SDK_PATH ADB_PATH NO_ADB MenuFace \
TagFilter hWord LogViewFontName LogViewFontSize FilterDeadProcess IgnoreCaseFilter
    global LoadFileMode AutoSaveDeviceLog LogLevel
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
        puts $fdW ":IgnoreCaseFilter"
        puts $fdW $IgnoreCaseFilter
        puts $fdW ":LogLevel(selected)"
        puts $fdW $LogLevel(selected)
        puts $fdW ":"
        close $fdW
    }
}

proc loadLastState {} {
    global LoadedFiles env WrapMode iFilter eFilter sWord Editor SDK_PATH ADB_PATH NO_ADB MenuFace TagFilter
    global hWord LogViewFontName LogViewFontSize FilterDeadProcess LogLevelTags TextColorTags IgnoreCaseFilter
    global LoadFileMode AutoSaveDeviceLog LogLevel
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
                } elseif {[string match ":IgnoreCaseFilter" $line]} {
                    set flag 25
                } elseif {[string match ":LogLevel(selected)" $line]} {
                    set flag 26
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
            } elseif {$flag == 25} {
                set IgnoreCaseFilter $line
            } elseif {$flag == 26} {
                set LogLevel(selected) $line
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

proc isFileSource {} {
    global Device
    return [string match "file:*" $Device]
}

proc getAutoSaveFileName {} {
    global Device
    set dateTime [exec date +%Y_%m%d_%H%M%S]
    if [isFileSource] {
        set fileName "${dateTime}.txt"
    } else {
        set splitname [split $Device :]
        set modelOs [lindex $splitname 0]
        set model [lindex [split $modelOs "/"] 0]
        set os [lindex [split $modelOs "/"] 1]
        set device [lindex $splitname 1]
        set port [lindex $splitname 2]
        set fileName "${dateTime}_OS${os}_${model}.txt"
    }
    return "$fileName"
}

proc openSource {} {
    global Fd LoadFile eFilter iFilter Device LineCount \
    statusTwo status3rd AppName ADB_PATH LogType ReadingLabel ProcessFilterExpression TagFilter ProcessTagFilter ProcessAndOrTag \
    LoadFileMode AutoSaveDeviceLog AutoSaveFileName IgnoreCaseFilter UseGnuAwk LoadFiles
    closeLoadingFd
    set deny "!"
    set isFileSource [isFileSource]
    puts "isFileSource: $isFileSource"
    updateProcessTagFilterExpression $isFileSource
    set xiFilter [checkEscapeAll [escapeSlash "$iFilter"]]
    set xeFilter [checkEscapeAll [escapeSlash "$eFilter"]]
    if {$eFilter == ""} {
        set deny ""
    }
    set title $Device
    puts "openSource $Device"
    puts "processFilter: \"$ProcessFilterExpression\""
    puts "tagFilter: \"$TagFilter\""
    puts "pAndOr: \"$ProcessAndOrTag\""
    puts "processTagFilter: \"$ProcessTagFilter\""

    set beginCondition [expr $UseGnuAwk && $IgnoreCaseFilter ? "{BEGIN{IGNORECASE = 1}}" : "{BEGIN{}}"]
    puts "beginCondition: $beginCondition"
    if {$isFileSource} {
        updateProcessFilterStatus disabled
        if {$LoadFileMode} {
            set Fd [open "| tail -f -n +1 \"$LoadFile\" | awk \"$beginCondition NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
        } else {
            set Fd [open "| awk \"$beginCondition NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" $LoadFiles" r]
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
        updateLogLevelView
        reloadProc
        puts "AutoSaveDeviceLog: $AutoSaveDeviceLog file: $AutoSaveFileName"
        if {$AutoSaveDeviceLog} {
            set Fd [open "|tail -f -n +1 \"$AutoSaveFileName\" | awk \"$beginCondition NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
        } else {
            set Fd [open "|$ADB_PATH -s $device logcat -v threadtime | awk \"$beginCondition NR > 0 && $ProcessTagFilter && $deny /$xeFilter/ && /$xiFilter/ {print}{fflush()}\" " r]
        }
    }
    puts "src: $Device fd: $Fd"
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
        fileevent $Fd r ""
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
    set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 4 4 $xid]
}

proc seekHighlight {colorTag key} {
    global logview HighlightWord
    if {$key == "Up" || $key == "Down" || $key == "dummy-clean"} {
        set err [catch {$logview index ${colorTag}.last} index]
        if {$err} {
            return
        }
        set bgcolor [$logview tag cget $colorTag -background]
        set fgcolor [$logview tag cget $colorTag -foreground]
        set bgDark [::tk::Darken $bgcolor 120]
        set fgLight [::tk::Darken $fgcolor 100]
        $logview tag config ${colorTag}Seek -background $bgDark -foreground $fgLight \
        -spacing1 5 -spacing3 5 -relief raised -borderwidth 2 -lmargin1 3 -lmargin2 3 -rmargin 3 -offset 3

        $logview config -state normal
        set w [lindex $HighlightWord($colorTag) 0]
        set idx [lindex $HighlightWord($colorTag) 1]
        set sCnt [lindex $HighlightWord($colorTag) 2]
        set err [catch {$logview index ${colorTag}Seek.first} seekFirst]
        set err [catch {$logview index ${colorTag}Seek.last} seekLast]
        if {!$err} {
            $logview tag remove ${colorTag}Seek 1.0 end
            $logview delete $seekFirst $seekLast
            set seekText [$w get]
            set seekLast [$logview index "$seekFirst + [string length $seekText] chars"]
        }
        if {$err || $idx == "-1"} {
            set indexes [lindex $HighlightWord($colorTag) 3]
            set seekFirst [lindex $indexes 0]
            set seekLast  [lindex $indexes 1]
        }
        set idxDelta 0
        set indexes ""
        if {$key == "Up"} {
            if {$seekFirst == ""} {
                set seekFirst [$logview index ${colorTag}.last]
                set idx [expr $sCnt + 1]
            }
            set indexes [$logview tag prevrange $colorTag $seekFirst]
            set idxDelta -1
        } elseif {$key == "Down"} {
            if {$seekLast == ""} {
                set seekLast [$logview index ${colorTag}.first]
                set idx 0
            }
            set indexes [$logview tag nextrange $colorTag $seekLast]
            set idxDelta 1
        }
        if {$indexes != ""} {
            set seekFirst [lindex $indexes 0]
            if {$idx == -1} {
                set tagList [$logview tag ranges $colorTag]
                set idx [expr [lsearch $tagList $seekFirst] / 2 + 1]
            } else {
                incr idx $idxDelta
            }
            set seekText "$idx > "
            $logview insert $seekFirst $seekText
            set seekLast [$logview index "$seekFirst + [string length $seekText] chars"]
            $logview tag add ${colorTag}Seek $seekFirst $seekLast
            set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 1 1 $idx]
            set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 3 3 {}]
            spotLight $seekFirst $seekLast $key
        }
        $logview config -state disabled
    }
}

proc nearHighlight {colorTag key idx} {
    global logview WrapMode LineCount HighlightWord
    set w [lindex $HighlightWord($colorTag) 0]
    set insertIdx [$w index insert]
    set len [string length [$w get]]
    if {"Left" == "$key" && 0 == $insertIdx} {
        set key "Up"
    } elseif {"Right" == "$key" && $len == $insertIdx} {
        set key "Down"
    } else {
        return
    }
    set yportions [$logview yview]
    set startPortion [lindex $yportions 0]
    set endPortion [lindex $yportions 1]
    set startLine [expr int(floor($LineCount * $startPortion))]
    set endLine [expr int(ceil($LineCount * $endPortion))]
    if {$key == "Up"} {
        set indexes "${endLine}.end ${endLine}.end"
    } elseif {$key == "Down"} {
        set indexes "${startLine}.0 ${startLine}.0"
    }
    set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 1 1 "-1"]
    set HighlightWord($colorTag) [lreplace $HighlightWord($colorTag) 3 3 "$indexes"]
    # puts "$colorTag: $HighlightWord($colorTag)"
    # puts "start: $startLine -> $endLine // $LineCount // indexes: $indexes"
    seekHighlight $colorTag $key
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
        set HighlightWord($colorTag) "$wentry 0 0 {} {}"
    }
}

proc chooseFontsAndColors {} {
    set w [toplevel .font_color]
    pack [button $w.close -text Close -command "destroy $w"] -side bottom
    pack [label $w.whoami -text "Choose fonts and colors."]
    pack [label $w.color -text "Colors"]
    pack [button $w.colorpick -text ColorPicker -command "getColorAndSet $w"] -side right
    after 300 refreshGeometry $w
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
    set default_file [getAutoSaveFileName]
    set filename [tk_getSaveFile -parent . -initialdir $dir -filetypes $ftypes -defaultextension $default_exete -initialfile $default_file]
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
            set psHeaders [exec $ADB_PATH -s $serial shell ps | head -1]
            set userIndex [lsearch $psHeaders "USER"]
            set pidIndex  [lsearch $psHeaders "PID"]
            set nameIndex [lsearch $psHeaders "NAME"]
            if {$userIndex > -1 && $pidIndex > -1 && $nameIndex > -1} {
                incr userIndex
                incr pidIndex
                incr nameIndex
                set pLists [exec $ADB_PATH -s $serial shell ps | awk "/^u|^app/ || (\$$nameIndex ~ /^system_server/) || (\$$nameIndex ~ /^zygote/) {print \$$pidIndex, \$$nameIndex, \$$userIndex}"]
                foreach {pId pkgName uName} $pLists {
                    # puts "pId: $pId, pkgName: $pkgName, uName: $uName"
                    # puts "[format "%5d %s" $pId $pkgName]"
                    if {[string is integer "$pId"]} {
                        lappend lists "[format "%5d %s" $pId $pkgName]"
                    }
                }
            } else {
                puts "getProcessPackageList header index error for shll ps."
            }
        }
        set lists [lsort -dictionary -index 0 -decr $lists] 
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
        $m add command -label "$afile" -command "loadFile \"$afile\""
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
    global Devices Device LoadFile LoadedFiles LoadFileMode AutoSaveDeviceLog Win
    puts "updateSourceList"
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
        } else {
            set name "$model:[getSerial7 $serialraw]"
        }
        set seriallow [regsub -all {\.} $seriallow {_}]
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
            set f [file tail $afile]
            pack [radiobutton .top.sources.$w -variable Device -value "file:$afile" -text $f \
            -command "loadFile \"$afile\""] -side left
        }
    }
    bind .top.sources.files <2> "after 200 showOption:FileLoadMode .top.sources.files"
    bind .top.sources.files <3> "after 200 showOption:FileLoadMode .top.sources.files"
    pack [button .top.sources.filehistory -text History -command "after 0 showHistoryList .top.sources.filehistory"] -side left
    #  showHistoryList
    #  bind .top.sources.filehistory <1> {tk_popup .loadhistory %X %Y}
    after 300 refreshGeometry $Win
}

proc refreshGeometry {win} {
    set cur_geometry [wm geometry $win]
    set geo_list [split $cur_geometry "x+"]
    set w [lindex $geo_list 0]
    set h [lindex $geo_list 1]
    set x [lindex $geo_list 2]
    set y [lindex $geo_list 3]
    set cur_geometry [format "%sx%s+%s+%s" [incr w] $h $x $y]
    wm geometry $win $cur_geometry
    update idletasks
    set cur_geometry [format "%sx%s+%s+%s" [incr w -1] $h $x $y]
    wm geometry $win $cur_geometry
    update idletasks
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
            after 100 "exec open -a $editor \"$LoadFile\" &"
        } else {
            after 100 "exec $editor \"$LoadFile\" &"
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
        -command {selectAndroidSdkDirectory}] -side right
    pack [entry  $wi.path -textvariable SDK_PATH] -expand yes -fill x
    pack [set ws1 [frame  $w.statusadb -relief ridge]] -fill x -expand yes
    pack [label $ws1.msg -text "status of adb path:"] -side left
    pack [label $ws1.val] -side left
    pack [set ws2 [frame  $w.statussdk -relief ridge]] -fill x -expand yes
    pack [label $ws2.msg -text "status of SDK path:"] -side left
    pack [label $ws2.val] -side left
    pack [checkbutton $w.later -text "Setup ADB_PATH later" -variable NO_ADB] -side bottom
    after 300 refreshGeometry $w
#   set SDK_PATH ""
#   set ADB_PATH ""
    checkAdbPath $w
    setTraceAdbPath $w $w2 1
}

proc selectAndroidSdkDirectory {} {
    global SDK_PATH
    set sdkPath [tk_chooseDirectory -initialdir ~ \
        -title "Choose \"adb including directory\" or \"Android SDK directory\""]
    if {"$sdkPath" != ""} {
        set SDK_PATH $sdkPath
    }
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
loadLastState
updateProcessFilterStatus disabled
onlyFocusEntry
#wVector . 1 "config -takefocus"
setupEntryKeyPressFilter
#bind $fsrch.hword1 <Key-Up> "seekHighlight colorLbl up"
#detectDevices
if {!$NO_ADB} {
    updateSourceList
    if {[checkAdbPath]} {
        puts "ADB_PATH already confirmed."
        return
    }
    after 2000 getAdbPath
}
setEditor
#getProcessPackageList

