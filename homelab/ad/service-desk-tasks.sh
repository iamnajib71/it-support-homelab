#!/bin/sh
set -eu
export LDAPTLS_REQCERT=never
user="sdtest_$(date +%s)_$$"
pass="$(python3 -c 'import secrets; print("Aa1!" + secrets.token_hex(16))')"
newpass="$(python3 -c 'import secrets; print("Bb2!" + secrets.token_hex(16))')"
cleanup() { samba-tool user delete "$user" >/dev/null 2>&1 || true; }
trap cleanup EXIT
check() {
    label="$1"; shift
    if "$@"; then echo "PASS $label"; else echo "FAIL $label"; exit 1; fi
}
samba-tool domain passwordsettings show
samba-tool user create "$user" "$pass" --userou=OU=Staff
check "create user in Staff" sh -c 'samba-tool user show "$1" | grep -q "OU=Staff"' sh "$user"
samba-tool user setpassword "$user" --newpassword="$newpass" --must-change-at-next-login
check "reset password and force change at next logon" sh -c 'samba-tool user show "$1" | grep -q "^pwdLastSet: 0$"' sh "$user"
samba-tool user setpassword "$user" --newpassword="$pass"
samba-tool user unlock "$user"
for attempt in 1 2 3 4 5; do
    if ldapwhoami -x -H ldaps://127.0.0.1 -D "$user@itops.lab" -w "Wrong-${pass}" 2>/tmp/ad-bind-error; then
        echo "FAIL unexpected successful bad bind"; exit 1
    fi
    printf 'Bad bind %s: ' "$attempt"; head -n 1 /tmp/ad-bind-error
done
check "five bad binds set lockoutTime" sh -c 'samba-tool user show "$1" | grep "^lockoutTime:" | grep -vq ": 0$"' sh "$user"
if ldapsearch -x -H ldaps://127.0.0.1 -D "$user@itops.lab" -w "$pass" -s base -b "" defaultNamingContext 2>/tmp/ad-bind-error; then
    echo "FAIL locked account accepted correct password"; exit 1
fi
echo "PASS locked account denies correct password"
samba-tool user unlock "$user"
check "unlock account and authenticate" ldapsearch -x -H ldaps://127.0.0.1 -D "$user@itops.lab" -w "$pass" -s base -b "" defaultNamingContext
samba-tool group addmembers GG-Finance "$user"
check "add user to GG-Finance" sh -c 'samba-tool group listmembers GG-Finance | grep -Fxiq "$1"' sh "$user"
samba-tool group listmembers GG-Finance
samba-tool user disable "$user"
check "disable leaver flag" sh -c 'v=$(samba-tool user show "$1" | sed -n "s/^userAccountControl: //p"); test $((v & 2)) -eq 2' sh "$user"
if ldapsearch -x -H ldaps://127.0.0.1 -D "$user@itops.lab" -w "$pass" -s base -b "" defaultNamingContext 2>/tmp/ad-bind-error; then
    echo "FAIL disabled leaver authenticated"; exit 1
fi
echo "PASS disabled leaver denied authentication"
cleanup
trap - EXIT
echo "PASS temporary account removed"
