#!/bin/sh
set -eu
lpstat -p -d
lpstat -p Office-PDF
lpstat -p Office-Laser
lpstat -d | grep -q 'Office-PDF'
name="check-$(date +%s)-$$"
printf 'IT Ops Lab test page %s\n' "$name" > /tmp/"$name".txt
trap 'rm -f /tmp/"$name".txt' EXIT
result="$(lp -d Office-PDF -t "$name" /tmp/"$name".txt)"
echo "$result"
job="$(printf '%s' "$result" | sed -n 's/.*Office-PDF-\([0-9][0-9]*\).*/\1/p')"
test -n "$job"
i=0
until ipptool -t -d "jobid=$job" ipp://localhost /lab-job-completed.test >/tmp/"$name"-ipp.txt 2>&1; do
    i=$((i+1))
    if [ "$i" -ge 45 ]; then cat /tmp/"$name"-ipp.txt; exit 1; fi
    sleep 1
done
cat /tmp/"$name"-ipp.txt
rm -f /tmp/"$name"-ipp.txt
lpstat -W completed -o Office-PDF | grep "Office-PDF-$job"
if lpstat -v Office-PDF | grep -q 'cups-pdf:/'; then
    output="$(find /shares/scans/pdf -type f -name "*$name*.pdf" | head -n 1)"
    test -n "$output"
    test "$(head -c 5 "$output")" = '%PDF-'
    echo "PDF artifact: $output"
fi
echo "PASS PDF job completed (IPP job-state=9)"
