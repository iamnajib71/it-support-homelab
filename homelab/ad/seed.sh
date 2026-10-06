#!/bin/sh
set -eu
for ou in Staff Finance IT; do
    if ! samba-tool ou list | grep -Fxq "OU=$ou"; then
        samba-tool ou create "OU=$ou"
    fi
done
for group in GG-Finance GG-Staff GG-IT-Admins; do
    if ! samba-tool group list | grep -Fxq "$group"; then
        case "$group" in GG-Finance) ou=Finance;; GG-IT-Admins) ou=IT;; *) ou=Staff;; esac
        samba-tool group add "$group" --groupou="OU=$ou"
    fi
done
create_user() {
    name="$1"; ou="$2"; password="$3"
    if ! samba-tool user list | grep -Fxq "$name"; then
        samba-tool user create "$name" "$password" --userou="OU=$ou"
    fi
}
create_user alice Finance "$AD_ALICE_PASSWORD"
create_user bob Staff "$AD_BOB_PASSWORD"
create_user carol IT "$AD_CAROL_PASSWORD"
add_member() {
    if ! samba-tool group listmembers "$1" | grep -Fxiq "$2"; then
        samba-tool group addmembers "$1" "$2"
    fi
}
for user in alice bob carol; do add_member GG-Staff "$user"; done
add_member GG-Finance alice
add_member GG-IT-Admins carol
samba-tool domain passwordsettings set --complexity=on --history-length=12 \
  --min-pwd-length=12 --min-pwd-age=0 --max-pwd-age=90 \
  --account-lockout-threshold=5 --account-lockout-duration=15 \
  --reset-account-lockout-after=15
