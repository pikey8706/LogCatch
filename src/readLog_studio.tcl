# studio
proc getLogLevel {line} {
    set idx [string first " " $line" 22]
    return [string index "$line" [incr idx]]
}
