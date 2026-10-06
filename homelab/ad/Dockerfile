FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends samba samba-ad-provision samba-dsdb-modules samba-vfs-modules winbind krb5-user ldap-utils smbclient dnsutils python3 && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh seed.sh service-desk-tasks.sh /lab/
RUN chmod 755 /lab/*.sh
ENTRYPOINT ["/lab/entrypoint.sh"]
