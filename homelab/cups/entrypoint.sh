#!/bin/sh
set -eu
: "${CUPS_ADMIN_PASSWORD:?Set CUPS_ADMIN_PASSWORD in .env}"
printf 'print:%s\n' "$CUPS_ADMIN_PASSWORD" | chpasswd
mkdir -p /run/cups /shares/scans/pdf
chmod 1777 /shares/scans/pdf
if [ -x /usr/lib/cups/backend/cups-pdf ]; then
    sed -i 's|^Out .*|Out /shares/scans/pdf|; s|^#\?AnonDirName .*|AnonDirName /shares/scans/pdf|; s|^#\?AnonUser .*|AnonUser nobody|; s|^#\?UserUMask .*|UserUMask 0002|' /etc/cups/cups-pdf.conf
else
    grep -q '^FileDevice Yes' /etc/cups/cups-files.conf || echo 'FileDevice Yes' >> /etc/cups/cups-files.conf
fi
/usr/sbin/cupsd -f &
pid=$!
trap 'kill "$pid"; wait "$pid"' TERM INT
sh /setup-printers.sh
wait "$pid"
