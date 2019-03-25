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

### Automated Install

First you have to setup your rpm build environment. For details see
[How to create an RPM package - Preparing your system](http://fedoraproject.org/wiki/How_to_create_an_RPM_package#Preparing_your_system).

    # Short version of the howto
    sudo yum install @development-tools fedora-packager
    rpmdev-setuptree

    # the real thing(tm)
    make rpm
    sudo rpm -Uhv ~/rpmbuild/RPMS/noarch/list-*.noarch.rpm
