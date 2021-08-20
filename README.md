docker-slurm-sssd
=================

SSSD(Active Directory configuration) spiced up version of Simple Slurm cluster in docker.

You can manage slurm jobs on your Active Directory managed baremetal compute node with this docker image.


docker-slurm-cluster
====================

This is a demonstration of how the Slurm could be deployed in the docker infrastructure using docker compose.

It consist of the following services:
- MariaDB (for accounting data)
- head node (munge, slurmd, slurmctld, slurmdbd, sssd)
- compute node x4 (munge, slurmd)

The slurm version is `v20.02.7`

# How to deploy

Clone the repository

```
git checkout https://github.com/panda1100/docker-slurm-cluster.git docker-slurm-cluster
cd docker-slurm-cluster
```

Next, build the node image.
```
docker-compose build
```

Edit .env file

```
KERBEROS_REALM=EXAMPLE.LOCAL
LDAP_USER_SEARCH_BASE="CN=users,DC=example,DC=local"
LDAP_SEARCH_BASE="DC=example,DC=local"
LDAP_URI=ldaps://example.local
LDAP_BIND_DN="CN=Administrator,CN=users,DC=example,DC=local"
LDAP_BIND_PASSWORD=STRONG_PASSWORD
```

Start the cluster

```
docker-compose up -d
```

To access the head node:

```
docker exec -it axc-hednode bash
```

NOTE: the first running of Slurm might take up to 1 minute because a new MariaDB database initiation procedure is slow a bit.
