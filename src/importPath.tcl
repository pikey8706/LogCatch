
set PATH_LIST "$runDir/path.list"
# set PATH_LIST "$env(HOME)/.logcatch/path.list"

set PATH_SEPARATOR ":"
if {$PLATFORM == "windows"} {
    set PATH_SEPARATOR ";"
}

proc importPath {pathlist separator} {
    global env

    puts "importPath pathlist: $pathlist separator: $separator"
    set path_lines ""
    if {[file readable $pathlist]} {
        set rp [open $pathlist "r"]
        if {$rp != ""} {
            while {[gets $rp line] >= 0} {
                set onePath "$line"
                if {[file isfile "$onePath"]} {
                    set onePath [file dirname "$onePath"]
                }
                if {[file isdirectory "$onePath"]} {
                    lappend path_lines "${onePath}"
                }
            }
            close $rp
        }
    }

    set uniq_path_lines ""
    set path_lines [lsort $path_lines]
    set prevPath ""
    foreach onePath "$path_lines" {
        if {"$onePath" == "$prevPath"} {
            continue
        }
        append uniq_path_lines "${separator}${onePath}"
        set prevPath "$onePath"
    }

    # update PATH
    puts  " importPath=${uniq_path_lines}"
    puts  "currentPath=${env(PATH)}"
    set env(PATH) "${env(PATH)}${uniq_path_lines}"
    puts  " mergedPath=${env(PATH)}"
}

importPath $PATH_LIST $PATH_SEPARATOR

