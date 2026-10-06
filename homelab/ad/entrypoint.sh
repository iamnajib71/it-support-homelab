#!/bin/sh
set -eu
: "${AD_ADMIN_PASSWORD:?Set AD_ADMIN_PASSWORD in .env}"
if [ ! -f /var/lib/samba/.provisioned ]; then
    rm -f /etc/samba/smb.conf
    samba-tool domain provision --realm=ITOPS.LAB --domain=ITOPS --server-role=dc \
      --dns-backend=SAMBA_INTERNAL --use-rfc2307 --adminpass="$AD_ADMIN_PASSWORD" \
      --host-name=dc1 --option="dns forwarder = 1.1.1.1" --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
      --option="xattr_tdb:file = /var/lib/samba/xattr.tdb"
    touch /var/lib/samba/.provisioned
fi
sh /lab/seed.sh
exec samba -i --no-process-group
