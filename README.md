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


# waitDeploy

This shell was designed to run inside a Jenkins step: it receive a json (which is the return of the AWS code deploy cli call) and then monitors the code deploy until it finishes. If the deploy fails, Jenkins will receive the failure.

