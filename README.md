# Tools

A personal collection of DevOps, sysadmin, and cloud-automation scripts — covering Linux post-install provisioning, AWS operations, CI/CD helpers, monitoring, SSL/PKI, Nexus Repository Manager maintenance, and RPM packaging.

## Repository layout

```
tools/
├── linuxInstall/          # Post-install setup scripts for various distros
├── packages/              # RPM-packaged utilities (list, kubetail, techmago-settings)
└── scripts/               # Standalone utility scripts
    ├── aws/               # AWS automation (EC2, RDS, Route53, CodeDeploy)
    ├── nexus-repository/  # Nexus artifact cleanup tools
    └── ssl/               # OpenSSL PKI generation helpers
```

---

## linuxInstall/

Automated post-install scripts that configure third-party repositories, install desktop/media/dev packages, set the timezone to `America/Sao_Paulo`, and disable unneeded services.

| Distro family | Scripts |
|---|---|
| **Rocky Linux** | `rocky8/rocky8.sh`, `rocky9/rocky9.sh`, `rocky10/rocky10.sh` |
| **CentOS** | `centos/centos7.sh`, `centos/centos8.sh` |
| **Fedora** | `fedora/fedoraInstall18.sh` through `fedoraInstall34.sh` |

Each Rocky directory also ships repo definitions (`repos/`) and config files (`confs/chrony.conf`). The Rocky 9/10 variants add repos for Docker CE, Google Chrome, Brave, Slack, TeamViewer, VirtualBox, CUDA, and Kubernetes.

---

## scripts/

### General utilities

| Script | Language | Purpose |
|---|---|---|
| `backupmysql.sh` | bash | Per-database `mysqldump` with selectable compression (gzip/xz/pigz/pxz/lrzip) and retention |
| `bitbucketClone.sh` | bash | Clones all repos from Bitbucket projects via the 2.0 API |
| `checkMemory.sh` | sh | Reports real RAM usage (excluding buffers/cache) — originally for Cacti |
| `custom.php` | php | Curl-friendly HTTP health check returning memory %, load average, core count, uptime |
| `dnsmasq_stats.py` | python | Parses dnsmasq logs into SQLite and exports Prometheus textfile metrics |
| `fpm.sh` | bash | Builds a Solr RPM from a directory tree using `fpm` |
| `ftpython.py` | python | HTTP file server with upload support (modernized, Python 3.11) |
| `github-repolist.py` | python | Lists all repos in a GitHub organization via REST API (paginated) |
| `gitlab-autoclone.sh` | bash | Clones all repos in a GitLab group using an API token |
| `intCredCheck.rb` | ruby | Validates tenant credentials against an Agrotis platform + SAP Service Layer |
| `kubeMEMextract.sh` | bash | Kubernetes resource audit — node allocation, namespace breakdown, top pods, and actual-vs-requested usage comparison |
| `luksMount.sh` | bash | Opens/closes LUKS-encrypted volumes with a random mapper name |
| `recriaBranch.rb` | ruby | Deletes and recreates GitLab branches (with safety guards on `master`/`deploy`) |
| `redisTestSource.py` | python | Redis key audit — scans all keys (non-blocking SCAN), reports type breakdown, TTL distribution, and memory usage |
| `redisTransfer.py` | python | Redis-to-Redis migration — copies all keys preserving types and TTLs, with progress bar and dry-run mode |
| `rpmMassRebuild.sh` | bash | Installs build deps and rebuilds all SRPMs in a directory (parallel builds, dry-run, debug-info toggle) |
| `solr.py` | python | Lists Solr cores, item counts, and triggers data imports |
| `urlmontor.py` | python | Hash-based website change monitor (compares SHA-224 of page content) |
| `weblogicDeploy.py` | python (WLST) | WebLogic deployment automation: undeploy existing app, then deploy & start |

### scripts/aws/

| Script | Language | Purpose |
|---|---|---|
| `backupimages.rb` | ruby | Creates AMI images of running EC2 instances tagged `Backup=True` |
| `ipupdate.py2` | python 2 | Dynamic DNS updater for Route53 (uses `boto` v2) |
| `ipupdate.py3` | python 3 | Same as above, modernized (uses `boto3`, `dnspython`, `click`) |
| `recriaBanco.sh` | bash | Clones an RDS instance to a new DB instance (with size validation) |
| `waitDeploy.sh` | bash | Polls an AWS CodeDeploy deployment until completion — designed for Jenkins pipeline steps |

### scripts/nexus-repository/

Tools to list and delete artifacts from Sonatype Nexus Repository Manager (REST API v1). All prompt for confirmation before deleting.

| Script | Format | Notes |
|---|---|---|
| `nexusRMgeneric.py` | any | Generic path-pattern search & delete with `tqdm` progress |
| `nexusRMversionDocker.sh` | docker | Delete Docker image versions by SHA-256 manifest |
| `nexusRMversionDockerAuto.py` | docker | Auto-keep last N versions, delete the rest |
| `nexusRMversionMVN.sh` | maven | Delete Maven artifacts by group + version glob |
| `nexusRMversionStatic.sh` | static | Delete static `.txz` artifacts by module + version |
| `nexusRMversionStaticAuto.sh` | static | Same, but auto-keeps the 5 newest |

### scripts/ssl/

Zsh scripts for generating a local PKI with OpenSSL:

| Script | Purpose |
|---|---|
| `generateROOT.zsh` | Generate a self-signed root CA (4096-bit, 7300 days) |
| `generateSERVICE.zsh` | Generate a service key/CSR and sign it with an existing root CA |
| `generateALL.zsh` | One-shot: generate root CA + service certificate |
| `openssl.cnf` | Shared OpenSSL config |
| `readme.md` | Verification commands (`openssl x509`, `openssl verify`, etc.) |

---

## packages/

RPM-packaged utilities, each with a `Makefile` supporting `make rpm` / `make srpm`.

### list

Python 3 CLI (boto3 + `terminaltables` + `click`) that lists AWS EC2 instances in a formatted table:

```
+-----------------------+----------------+----------------+------------+---------+---------------------------+
| Name                  | Private IP     | Public IP      | Type       | State   | Launch Time               |
+-----------------------+----------------+----------------+------------+---------+---------------------------+
| RentOS 1.0.10         | 192.168.4.134  | None           | t2.micro   | running | 2017-08-25 14:44:33+00:00 |
+-----------------------+----------------+----------------+------------+---------+---------------------------+
```

Options: `-c/--column` to select columns, `-r/--region` to pick an AWS region.

### kubetail

Bash utility (v1.6.8) to tail logs from multiple Kubernetes pods simultaneously, with color coding, label selectors, jq parsing, and namespace/context support. Includes bash completion.

### techmago-settings

Noarch RPM that deploys custom system settings (skel files, yum repo definitions, profile.d hooks) for RHEL 8 and RHEL 9. Each variant has a `pack.sh` build script and a `workdir/` tree.

---

## License

Personal/internal use. See individual scripts for upstream licenses (e.g., kubetail, Solr).
