#!/bin/sh
set -eu
name="check-$(date +%s)-$$"
file="/tmp/$name.txt"
printf 'IT Ops Lab access-control test %s\n' "$name" > "$file"
trap 'rm -f "$file" /tmp/"$name"-download.txt' EXIT
export PASSWD="$SMB_ALICE_PASSWORD"
smbclient -L //fileserver -U alice -m SMB3
smbclient //fileserver/Finance -U alice -m SMB3 -c "put $file $name.txt; get $name.txt /tmp/$name-download.txt; del $name.txt"
cmp "$file" "/tmp/$name-download.txt"
echo "PASS Alice Finance write"
export PASSWD="$SMB_BOB_PASSWORD"
if smbclient //fileserver/Finance -U bob -m SMB3 -c ls >/tmp/"$name"-denial.txt 2>&1; then
    echo "FAIL Bob accessed Finance"; exit 1
fi
cat /tmp/"$name"-denial.txt
grep -q NT_STATUS_ACCESS_DENIED /tmp/"$name"-denial.txt
rm -f /tmp/"$name"-denial.txt
echo "PASS Bob Finance denied"
for user in alice bob; do
    case "$user" in alice) export PASSWD="$SMB_ALICE_PASSWORD";; bob) export PASSWD="$SMB_BOB_PASSWORD";; esac
    smbclient //fileserver/Public -U "$user" -m SMB3 -c "put $file $name.txt; get $name.txt /tmp/$name-download.txt; del $name.txt"
    cmp "$file" "/tmp/$name-download.txt"
    echo "PASS $user Public read/write"
done
