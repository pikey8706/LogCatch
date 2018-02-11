
proc load_text_color_tags {filename} {
    global TextColorTags hWord
    set COLOR_TAG ":TextColorTags"
    puts "load_text_color_tags from $filename"
    set rp [open "$filename" "r"]
    set loadCnt 0
    if {"$rp" != ""} {
        set reading 0
        while {[gets $rp line] >= 0} {
            if {[regexp "^ *#" "$line"]} {
                puts "skip comment $line"
            } elseif {$reading && [llength $line] >= 2} {
                set colorTag [lindex $line 0]
                set fgcolor [lindex $line 1]
                set bgcolor [lindex $line 2]
                set TextColorTags($colorTag) "$fgcolor $bgcolor"
                incr loadCnt
            } elseif {!$reading && [regexp "$COLOR_TAG" "$line"]} {
                set reading 1
            } elseif {[regexp "^:" "$line"]} {
                break;
            }
        }
        close $rp
    }
    puts "$loadCnt tags loaded."
}

set configDir "config"
set configFile "text_color_tags.list"
set separator "/"
if {$PLATFORM == "windows"} {
    set separator "¥"
}

set configPath "${runDir}${separator}..${separator}${configDir}${separator}${configFile}"

load_text_color_tags $configPath

