# long
proc getLogLevel {line} {
    if {"[string index $line 0]" == "\["} {
	return [string index "[lindex $line 5]" 0]
    }
    return "V"
}
