#!/bin/sh
# the next line restarts using wish \
exec /usr/local/Cellar/tcl-tk/8.6.12/bin/wish "$0" "$@"

puts $tk_patchLevel

exit 0
