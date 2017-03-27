# threadtime
proc getLogLevel {line} {
    set xline [string map {\" \\" \{ \\{ \} \\}} "$line"]
    return [lindex $xline 4]
}
