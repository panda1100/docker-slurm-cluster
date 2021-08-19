#!/bin/bash

set -e

if [ ! -z "$IS_HEADNODE" ]; then
  # Create munge key
  if [ ! -f /etc/munge/munge.key ]; then
    create-munge-key -f
  fi

  # Create slurmcltd data directory
  if [ ! -d /var/spool/slurm/ctld ]; then
    mkdir -p /var/spool/slurm/ctld
    chown -R slurm: /var/spool/slurm
  fi

  # Init slurm acct database
  IS_DATABASE_EXIST='0'
  while [ "1" != "$IS_DATABASE_EXIST" ]; do
    echo "Waiting for database $MARIADB_DATABASE on $MARIADB_HOST..."
    IS_DATABASE_EXIST="`mysql -h $MARIADB_HOST -u root -p"$MARIADB_ROOT_PASSWORD" -qfsBe "select count(*) as c from information_schema.schemata where schema_name='$MARIADB_DATABASE'" -H | sed -E 's/c|<[^>]+>//gi' 2>&1`"
    sleep 5
  done

  # check mandatory input
  [ -z "${KERBEROS_REALM}" ] && echo "KERBEROS_REALM must be defined" && exit 1
  [ -z "${LDAP_URI}" ] && echo "LDAP_URI must be defined" && exit 1
  [ -z "${LDAP_USER_SEARCH_BASE}" ] && echo "LDAP_USER_SEARCH_BASE must be defined" && exit 1
  [ -z "${LDAP_SEARCH_BASE}" ] && echo "LDAP_SEARCH_BASE must be defined" && exit 1
  [ -z "${LDAP_BIND_DN}" ] && echo "LDAP_BIND_DN must be defined" && exit 1
  [ -z "${LDAP_BIND_PASSWORD}" ] && echo "LDAP_BIND_PASSWORD must be defined" && exit 1

  # put config files in place
  cat >/etc/krb5.conf <<EOL
[libdefaults]

  default_realm = ${KERBEROS_REALM}
	dns_lookup_realm = false
	dns_lookup_kdc = true
EOL

  cat >/etc/sssd/sssd.conf <<EOL
[sssd]
config_file_version = 2
services = nss, pam
domains = ${KERBEROS_REALM}

[domain/${KERBEROS_REALM}]
default_shell = /bin/bash
ad_server = ${KERBEROS_REALM}
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = ${KERBEROS_REALM}
realmd_tags = manages-system joined-with-adcli
id_provider = ldap
auth_provider = krb5
krb5_realm = ${KERBEROS_REALM}
krb5_ccname_template = FILE:%d/krb5cc_%U
fallback_homedir = /home/%u
ad_domain = ${KERBEROS_REALM}
use_fully_qualified_names = False
ldap_id_mapping = False
access_provider = ldap

ldap_schema = rfc2307bis
ldap_user_search_base = ${LDAP_USER_SEARCH_BASE}
ldap_user_object_class = user
ldap_user_name = cn
ldap_user_principal = userPrincipalName
ldap_user_objectsid = objectSID
ldap_user_primary_group = primaryGroupID
ldap_user_home_directory = /home/%u
ldap_access_order = expire
ldap_account_expire_policy = ad
ldap_force_upper_case_realm = true
ldap_user_gecos = displayName
ldap_search_base = ${LDAP_SEARCH_BASE}
ldap_referrals = false
ldap_uri = ${LDAP_URI}
ldap_tls_reqcert = never
ldap_default_bind_dn = ${LDAP_BIND_DN}
ldap_default_authtok_type = password
ldap_default_authtok = ${LDAP_BIND_PASSWORD}"
EOL

  cat >/etc/nsswitch.conf <<EOL
passwd:         compat sss
group:          compat sss
shadow:         compat
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files
netgroup:       nis sss
EOL

  # fix permissions
  chmod 600 /etc/sssd/sssd.conf

  # create db directory if not exists
  mkdir -p /var/lib/sss/db
  mkdir -p /var/lib/sss/pipes/private
  mkdir -p /var/lib/sss/mc
fi

# Prepare munge dirs
chown -R munge: /etc/munge /var/lib/munge /var/run/munge
chmod 0700 /etc/munge
chmod 0711 /var/lib/munge
chmod 0755 /var/run/munge

# Prepare slurm and munge spool dirs
if [ ! -d /var/spool/slurm/d -o ! -d /var/spool/slurm/ctld ]; then
  mkdir -p /var/spool/slurm/d /var/spool/slurm/ctld
  chown -R slurm: /var/spool/slurm
fi
if [ ! -d /var/spool/munge ]; then
  mkdir /var/spool/munge
  chown -R munge: /var/spool/munge
fi


exec "$@"
