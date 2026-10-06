#!/bin/sh
set -eu
i=0
until lpstat -r 2>/dev/null | grep -q "scheduler is running"; do
    i=$((i+1)); [ "$i" -lt 60 ] || exit 1; sleep 1
done
if ! lpstat -p Office-PDF >/dev/null 2>&1; then
    model="$(lpinfo -m | awk '/[Cc][Uu][Pp][Ss]-[Pp][Dd][Ff].*[Nn]o [Oo]ptions/ {print $1; exit}')"
    if [ -z "$model" ]; then
        model="$(lpinfo -m | awk '/[Cc][Uu][Pp][Ss]-[Pp][Dd][Ff]/ {print $1; exit}')"
    fi
    if [ -n "$model" ] && [ -x /usr/lib/cups/backend/cups-pdf ]; then
        lpadmin -p Office-PDF -E -v cups-pdf:/ -m "$model" -D "Lab PDF output to Scans/pdf"
    else
        lpadmin -p Office-PDF -E -v file:/dev/null -m raw -D "LAB SIMULATION: discard backend (no PDF renderer)"
    fi
fi
if ! lpstat -p Office-Laser >/dev/null 2>&1; then
    model="$(lpinfo -m | awk '/[Gg]eneric.*[Pp]ost[Ss]cript/ {print $1; exit}')"
    [ -n "$model" ] || model=drv:///sample.drv/generic.ppd
    lpadmin -p Office-Laser -E -v ipp://192.0.2.10/ipp/print -m "$model" \
      -D "LAB SIMULATION: Office-Laser, no physical printer (TEST-NET-1)"
fi
lpadmin -d Office-PDF
lpstat -p -d
