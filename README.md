# Amazon
AWS Suport Scripts

# list

This script list all your AWS EC2 instances, and format the output in a nice table:

```sh
+-----------------------+----------------+----------------+------------+---------+---------------------------+
| Name                  | Private IP     | Public IP      | Type       | State   | Launch Time               |
+-----------------------+----------------+----------------+------------+---------+---------------------------+
| RentOS 1.0.10         | 192.168.4.134  | None           | t2.micro   | running | 2017-08-25 14:44:33+00:00 |
| evaluations           | 192.168.4.165  | None           | t2.micro   | running | 2016-05-18 16:11:53+00:00 |
| prod-mongodb          | 192.168.4.124  | None           | t2.large   | running | 2016-12-27 11:44:13+00:00 |
| prod-monyog           | 192.168.4.202  | None           | t2.large   | running | 2016-09-16 14:22:57+00:00 |
+-----------------------+----------------+----------------+------------+---------+---------------------------+
```

# waitDeploy.sh

This shell was desingned to run inside a jenkins step: it receive a json (which is the return of the AWS code deploy cli call) and then monitors the code deploy until it finishes. If the deploy fails, jenkins will receive the failure.

```sh
stage("Deploy") {
sh "aws deploy create-deployment --region ${appRegion} " +
  "--application-name ${appName} " +
  "--deployment-group ${appEnv} " +
  "--revision '{" +
  "  \"revisionType\": \"S3\"," +
  "  \"s3Location\": {" +
  "    \"bucket\": \"${appBucket}\"," +
  "    \"key\": \"jobs/Rentcars/${appName}/${env.BRANCH_NAME}/${env.BUILD_NUMBER}/${env.BUILD_TAG}.tar.gz\"," +
  "    \"bundleType\": \"tgz\"" +
  "  }" +
  "}' | tee output.json"
  sh "waitDeploy output.json ${appRegion}"
}
```

# gitlab-autoclone.sh

Script to clone all repos from some gitlab organization.

# github-repolist.php

Script to clone all repos from some github organization.

# checkMemory.sh

Calculates and return the true memory used by the system. Usefull for monitoring scripts (Made for an old cacti server)

# custom.php

Custom healthcheck. It returns the CPU load true memory usage and some trivial data from the machine. Made as a custom health check for AWS. The return is curl-friendly.

```sh
luis.brandao@pc144 ~ $ curl 192.168.1.161/custom.php
Used memory: 64%
5 min load: 0.34
Number of cores 4
```

# fedoraInstall

My set of pos-install scripts for fedora.
