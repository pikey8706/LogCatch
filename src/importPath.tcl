
set PATH_LIST "./path.list"
set PATH_SEPARATOR ":"

proc importPath {pathlist separator} {
    global env

    set all_lines ""

    if {[file readable $pathlist]} {
	set rp [open $pathlist "r"]
	if {$rp != ""} {
	    while {[gets $rp line] >= 0} {
		append all_lines "$line"
	    }
	    close $rp
	}
    }

    set path_line ""
    foreach onePath [split $all_lines $separator] {
	if {[file isdirectory $onePath]} {
	    append path_line ":$onePath"
	}
    }
    # update PATH
    set env(PATH) "${env(PATH)}${path_line}"
}

importPath $PATH_LIST $PATH_SEPARATOR

