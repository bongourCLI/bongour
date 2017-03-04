#!/bin/bash
{
disk="/dev/xvdb"
lv_size=20 ##in GB
server=SERVER
env=ENV
hostname="$server-$env.$server.com"
swap_size="2048" #in MB
lv_size=$((lv_size-1))

if [[ "$1" == "input" ]];then
    echo -n "Setup hostname: "
    read hostname
    echo -n "Set lv size: "
    read lv_size
fi

echo "setting hostname"
sed -i 's/127.0.0.1.*/127.0.0.1 localhost localhost.localdomain/g' /etc/hosts
hostname $hostname
sed -i.bak "s/\(HOSTNAME\).*/\1=$hostname/g" /etc/sysconfig/network 

echo "enabling wheel"
echo "%wheel ALL=NOPASSWD: ALL" >> /etc/sudoers

echo "Creating LVM lv_app"
pvcreate $disk
vgcreate vg_app $disk
lvcreate -L"$lv_size"G -n lv_app vg_app
mkfs.ext4 /dev/vg_app/lv_app
echo "/dev/mapper/vg_app-lv_app /apps ext4 defaults   0   0"   >> /etc/fstab
mkdir /apps
mount -a

echo "creating directory structures"
pushd /apps
mkdir node-apps lib local tmp src backup logs mysql mongo
chmod 777 /apps/tmp/
popd

echo "Updating Yum Updates"

yum update
yum groupinstall 'Development Tools'

echo "installing node and pm2" 
pushd /apps/lib
yum install -y wget
yum install -y git	
wget https://nodejs.org/dist/v4.4.7/node-v4.4.7-linux-x64.tar.gz
tar -zxf node-v4.4.7-linux-x64.tar.gz
ln -s -f /apps/lib/node-v4.4.7-linux-x64/bin/node /usr/bin/node
ln -s -f /apps/lib/node-v4.4.7-linux-x64/bin/npm /usr/bin/npm
npm install pm2
useradd pm2 -d /apps/pm2
rm -f `which pm2`
echo "export PATH=$PATH:/apps/lib/node_modules/pm2/bin" >> /apps/pm2/.bashrc
echo "export HISTTIMEFORMAT='%d/%m/%y %T	'" >> /apps/pm2/.bashrc
echo "export LC_ALL=en_US.UTF-8" >> /apps/pm2/.bashrc
chown pm2. /apps/pm2/.bashrc
chown pm2. /apps/node-apps
popd 

echo "Custom access to pm2"
echo $hostname | grep -E 'dev|poc' 
if [[ $? == 0 ]];then
    echo 'granting sudo access to pm2'
    usermod -G wheel pm2
fi

echo "Creating swap file"
dd if=/dev/zero of=/apps/.swap bs=1M count=$swap_size
chmod 0600 /apps/.swap
mkswap /apps/.swap
swapon /apps/.swap
echo "/apps/.swap    none    swap    sw    0   0"  >> /etc/fstab 

echo "installing mongo"
echo "[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/6/mongodb-org/3.2/x86_64/
gpgcheck=0
enabled=1" >> /etc/yum.repos.d/mongodb-org-3.2.repo
yum install -y mongodb-org
sed -i.bak 's/dbPath.*/dbPath: \/apps\/mongo/g'  /etc/mongod.conf
sed -i.bak 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
chown -R mongod. /apps/mongo
service mongod start

echo "installing redis"
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm 
yum install -y redis --enablerepo=epel

echo "installing mysql"
wget http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm
rpm -ivh mysql-community-release-el6-5.noarch.rpm
rpm -Uvh ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home:/michalstrnad/CentOS_CentOS-6/x86_64/pwgen-2.06-278.1.x86_64.rpm
yum install -y mysql-server
sed -i.bak 's/\/var\/lib\/mysql/\/apps\/mysql/g' /etc/my.conf
chown -R mysql. /apps/mysql
service mysqld start
password=`pwgen -s 16 1`
echo "MySQL password is $password"
mysql_secure_installation <<EOF

y
$password
$password
y
y
y
y
EOF
echo "export MYSQL_USER=root">> /apps/pm2/.bashrc
echo "export MYSQL_PASS=$password">> /apps/pm2/.bashrc

export LC_ALL=C
adminpass=`pwgen -s 16 1`
userpass=`pwgen -s 16 1`
mongo <<EOF
use admin
db.createUser({user : 'mongoadmin', pwd : '$adminpass', roles : ['root']})
use $server-dev
db.createUser({user : '$server', pwd : '$userpass', roles : ['readWrite']})
use $server-test
db.createUser({user : '$server', pwd : '$userpass', roles : ['readWrite']})
use $server-live
db.createUser({user : '$server', pwd : '$userpass', roles : ['readWrite']})
EOF
echo "export ADMIN_PASS='$adminpass'" >> /apps/pm2/.bashrc
echo "export MONGO_USER='$server'" >> /apps/pm2/.bashrc
echo "export MONGO_PASS='$userpass'" >> /apps/pm2/.bashrc
echo "export MONGO_DBNAME_DEV='$server-dev'" >> /apps/pm2/.bashrc
echo "export MONGO_DBNAME_TEST='$server-test'" >> /apps/pm2/.bashrc
echo "export MONGO_DBNAME_LIVE='$server-live'" >> /apps/pm2/.bashrc
sed -i.bak 's/#security:/security:\n  authorization: enabled/g' /etc/mongod.conf
sudo service mongod restart

echo "Installation of Imagemagick and graphicsmagick"
yum install -y gcc libpng libjpeg libpng-devel libjpeg-devel ghostscript libtiff libtiff-devel freetype freetype-devel
wget ftp://ftp.graphicsmagick.org/pub/GraphicsMagick/1.3/GraphicsMagick-1.3.21.tar.gz
tar zxvf GraphicsMagick-1.3.21.tar.gz
cd GraphicsMagick-1.3.21
./configure --enable-shared
make
make install
sudo ln -s /usr/local/bin/gm /usr/bin/
gm version
yum install -y php-pear gcc php-devel php-pear
yum install -y ImageMagick ImageMagick-devel

echo "installing other packages"
yum install -y ant ant-contrib
yum install -y telnet
yum groupinstall -y 'Development Tools'
yum install -y sysstat
yum install -y httpd24
echo "Installing NMON"
wget http://sourceforge.net/projects/nmon/files/nmon16e_mpginc.tar.gz
tar -xzvf nmon16e_mpginc.tar.gz
cp nmon_x86_64_centos7 /usr/bin/
chmod a+x /usr/bin/nmon_x86_64_centos7 
ln -s /usr/bin/nmon_x86_64_centos7 /usr/bin/nmon
rm -f nmon_*
sed -i "s/#ServerName www.example.com:80/ServerName $hostname:80/g" /etc/httpd/conf/httpd.conf
sed -i "s/Indexes//g" /etc/httpd/conf/httpd.conf 

echo "updating config"
mv /var/www/ /apps/
ln -s /apps/www /var/www
mv /var/log /apps/logs/var_log
ln -s /apps/logs/var_log /var/log
#chown -R mysql. /apps/mysql

echo "Installing phpmyadmin"
rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
rpm -e `rpm -qa | grep php`
rpm -e `rpm -qa | grep httpd`
yum install -y php56
yum --enablerepo=remi install -y phpmyadmin
sed -i 's/local/all granted/g'  /etc/httpd/conf.d/phpMyAdmin.conf
sed -i 's/Deny from All/Allow from All/g'  /etc/httpd/conf.d/phpMyAdmin.conf
sed -i 's/Allow from None/#Allow from None/g'  /etc/httpd/conf.d/phpMyAdmin.conf

echo "Jenkins config"
pushd /home/ec2-user/.ssh
touch config deploy.pem
echo "IdendityFile /home/ec2-user/.ssh/deploy.pem
StrcitHostKeyChecking=no" >> /home/ec2-user/.ssh/config
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCdolGmvoo8Vz6QIpaDEHlFrsXwJ2Ifcfwd/hTD57bhzOeTk2yhidXneoyXbigrDZHukZwpmu7dqFy6BAXH2QbA7dzhhkVaB9FHpG/69lTVouSe+rGWunaTn9pS+UBlXSznZqBqixBk40m+29EZkdx1PdOZpF+QNggWTfETjQ9/fmcoq47M9zQFate3047bXOG/pKLGtDf3dQjbBIAiX8eU5XHlB4dryVcf3zbg0w3eubEzekOz4uUSolmc6Le/sd2EQ2b7ugOpigZI8MQmBPerqPtrqwqPK7D1gxLtvqnLady9ltJTSDh5IoW/TTtCc2glZLZeUEuxOsBPCnNbGNfD jenkins" >> /home/ec2-user/.ssh/authorized_keys
echo "-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAqImHRzkkcikwkKb8L1eAWyVyiEsx57aryGIgNP+uUmf4Cvw9
kEO0aMHLXqR+ZKOG11yffpWstsUFZ2xdFTK42pNAGyWri4j3eR+3pFJqCvfJDBaI
7GQJgATjciMoBkcx5EQXawdKdBWE+bHV/1VYCXjCL9iqb3YSXkhO4UBIenykY3VL
5biWbMkfEoEi2zwvh2nh/H4iqEZn166ViwVN+0+MOTDwms98UeQB/vkqJ1p++vDZ
+gjfh05NOSRgQbsTvDV3IRbR2cxeNRqPANmFbE0mJbHVm+0eKhHLRNKpnO7Vb4co
2UMSnaUZ2rZ/2uPvTJTTBomuAERB5mzkN/NKiwIDAQABAoIBAQCVL4gLx803MLbI
lMfOsEnyZKeJdeZrEgvliNaxk1Ifp+Cs+LMWLJhZ0pHO6RToyMfngxm714nXD3fF
IOsUhJ2U/ZtVbHb5QPiuwyCv2DP+GXBhvuDdP4AZTjp3Ih+fzw2e3ZdNKlsBfrsC
vCSNrGINoFNkPwo/N+jyhFculNSTdqjNfDWvf0Apu9BQeGBhSogyXKqIqLQOlRPp
XX/ScJNQpJzDyVFY0+lCPYhri4YQiJrljwIHTmEJ4jhHy/WL9/CnAqV0a918+akO
al98/zXVKQkPxu6v/vbb/qPetEAaxZRiNa5wUHE4en74gWCPsVMxCzqqtVQ9iuIJ
3ixjPYhhAoGBAOA5th3WdsNUPSWzBTtRijO08ZAQIsZDh39KXZjVjVNTJeR+ocIp
e0rf0FAOQ42u291Qq9iN1k396Rtx3EfW4PGyKmEZ3KIK4Rl97BrUgp9kOX9M4gSz
Ps226OXYaufF4RzB/PxCe1ZdsEZ2bjvIgJc0EmcGtI0JdSkrhVA1+kNdAoGBAMBr
maOIIW+AbRMtohAzGghnW1UPNFAF4ac7CVEVWZfWmqvyGXVbZm+EOmAe51iZr3VH
ltJ6H27Hmj7QY4UZHnWSI75AV39cJxAUEPek/ksIK4ZCNYNjXo1Vo8ljDKm2+S3C
6BhVeXq5K6vkXDUZPwWwIBYmxZUZMrA2TjGzPQ8HAoGAM0B9xCw1UUh8AZX96CUn
NdJyNL+7cx4UZqAU7M5DU3x5+NSJHNxmdiLadrIL9uK1Fs1Nul4RUhprof5Qn4sa
N6TF0xQaPl/GPBFwWmGgydYa3mIwd2qRPGxGp+Lj7L5qSix9Kxv3HTKlDDYd1ERs
QCOC4VHDC0nSIer0ufTck3ECgYAxAXZwqrPxROECuGWFAK7JoyEkqammE8ljoOp/
hxN5U0OzNQZ82Blfn2qKnnRHIWUJVoE3+7hTq2xCQSqHdF1Ijj6iLpraKesc8i9c
Et5c16jWGbitTLqA/mWnXZ2U/6+4kuIviF1W/x/7OD6vm01ssm2JlrhNf8xkCoCh
sceEMwKBgApun6Vj8ZKWAQkW948sGNdY28kKQ4cZTYi3tIb3LlGmq4yKt9IOaKbg
u+HheXQ3kxuy15/oRalO62xUseuA+9lrZW5GOSW0HM64b6ztPmAM0hiY3xp2gp3A
AV6/C7rsoaKh/LqISlUpr70ITbV3f1na09Ai1jIjV64BFWn2IQ99
-----END RSA PRIVATE KEY-----" >> /home/ec2-user/.ssh/deploy.pem
chmod -R 700 /home/ec2-user/.ssh
chown -R ec2-user:ec2-user /home/ec2-user/.ssh
popd

chkconfig httpd on
chkconfig mongod on
chkconfig redis on
chkconfig mysqld on

service httpd start
service redis start

} | tee /tmp/setup.log
