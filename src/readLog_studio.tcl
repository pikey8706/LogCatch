# studio
proc getLogLevel {line} {
    set idx [string first " " $line" 24]
    return [string index "$line" [incr idx]]
}
