set LogTypes "none brief process tag time thread threadtime long time_eclipse studio"
set LogType "none"
set LogLevels "V D I W E A F"

# check first 6 line
proc checkLogType {filename} {
    global LogType LogLevels
    set LogType "none"
    puts "checking logtype ... \"$filename\""
    set rp [open "$filename" r]
    if {"$rp" != ""} {
        set lcnt 0        ;# line
        set ncnt 0        ;# none
        set bcnt 0        ;# brief
        set tagcnt 0      ;# tag
        set pcnt 0        ;# process
        set longcnt 0     ;# long 
        set timecnt 0     ;# time
        set timeecnt 0    ;# time eclipse cnt
        set threadcnt 0   ;# thread
        set studiocnt 0   ;# studio
        set minimax 2
        set linemax 100
        while {[gets $rp line] >= 0 && $lcnt <= $linemax} {
            # puts $lcnt/{$line}
            set line [string map {\" \\" \{ \\{ \} \\}} "$line"]
            if {"$line" != ""} {
                set second [string index $line 1]
                if {"$second" == " "} {
                    set first [string index $line 0]
                    if {"$first" == "\["} {
                        # long
                        incr longcnt
                        if {$longcnt == $minimax} {
                            set LogType long
                            break
                        }
                    }
                } elseif {"$second" == "("} {
                    # process/thread
                    set closer [string first ")" "$line"]
                    set colonspace [string first ": " "$line"]
                    if {$colonspace > -1 && $colonspace < $closer} {
                        # thread
                        incr threadcnt
                        if {$threadcnt == $minimax} {
                            set LogType thread
                            break
                        }
                    } else {
                        # process
                        incr pcnt
                        if {$pcnt == $minimax} {
                            set LogType process
                            break
                        }
                    }
                } elseif {"$second" == "/"} {
                    # brief/tag
                    set colonspace [string first ": " "$line"]
                    if {"$colonspace" >= 0} {
                        if {"[string index $line [expr $colonspace -1]]" == ")"} {
                            # brief
                            incr bcnt
                            if {$bcnt == $minimax} {
                                set LogType brief
                                break
                            }
                        } else {
                            # tag
                            incr tagcnt
                            if {$tagcnt == $minimax} {
                                set LogType tag
                                break
                            }
                        }
                    }
                } else {
                    set colon_space [string range $line 18 19]
                    set slash20 [string index $line 20]
                    set slash21 [string index $line 21]
                    set if_level [lindex "$line" 4]
                    puts "LogLevels: $LogLevels , if_level: $if_level"
                    if {"$slash20" == "/"} {
                        # time
                        incr timecnt
                        if {$timecnt == $minimax} {
                            set LogType "time"
                            break
                        }
                    } elseif {"$colon_space" == ": " && [lsearch $LogLevels "$slash20"] >= 0} {
                        # time_eclipse
                        incr timeecnt
                        if {$timeecnt == $minimax} {
                            set LogType time_eclipse
                            break
                        }
                    } elseif {[string length "$if_level"] == 1 && [lsearch $LogLevels "$if_level"] >= 0} {
                        # threadtime
                        # puts "LogLevels: \"$LogLevels\" if_level: \"$if_level\""
                        incr threadtimecnt
                        if {$threadtimecnt == $minimax} {
                            set LogType threadtime
                            break
                        }
                    } elseif {"[string index [lindex $line 3] 1]" == "/"} {
                        # studio
                        incr studiocnt
                        if {$studiocnt == $minimax} {
                            set LogType studio
                            break
                        }
                    }
                }
                incr lcnt
            }
        }
        close $rp
    }
    puts "logtype maybe $LogType"
}

proc reloadProc {} {
    global LogType runDir
    if {"$LogType" == "none"} {
        source $runDir/readLog_none.tcl
    } elseif {"$LogType" == "time"} {
        source $runDir/readLog_time.tcl
    } elseif {"$LogType" == "time_eclipse"} {
        source $runDir/readLog_time_eclipse.tcl
    } elseif {"$LogType" == "studio"} {
        source $runDir/readLog_studio.tcl
    } elseif {"$LogType" == "long"} {
        source $runDir/readLog_long.tcl
    } elseif {"$LogType" == "threadtime"} {
        source $runDir/readLog_threadtime.tcl
    } elseif {"$LogType" == "brief"} {
        source $runDir/readLog_brief.tcl
    }
    puts "reload proc readLog for logtype: $LogType"
}
