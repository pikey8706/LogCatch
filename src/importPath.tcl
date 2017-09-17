
set PATH_LIST "./path.list"
set PATH_SEPARATOR ":"
set PLATFORM "windows" ;#"unix"

proc importPath {pathlist separator} {
    global env PLATFORM

    set path_lines ""
    if {[file readable $pathlist]} {
	set rp [open $pathlist "r"]
	if {$rp != ""} {
	    while {[gets $rp line] >= 0} {
                if {$PLATFORM == "windows"} {
		    regsub -all -- "\\\\" $line "/" line
                }
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
    # puts "${env(PATH)}${path_line}"
    set env(PATH) "${env(PATH)}${uniq_path_lines}"
}

importPath $PATH_LIST $PATH_SEPARATOR

