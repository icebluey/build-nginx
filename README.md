Diffie-Hellman parameters
```
openssl dhparam -out dhparam.pem 3072
openssl dhparam -dsaparam -out dhparam.pem 4096
```

RHEL/CentOS
```
yum install -y gd
yum install -y perl-libs
```

Debian/Ubuntu
```
apt install -y libgd3
apt install -y perl
```

