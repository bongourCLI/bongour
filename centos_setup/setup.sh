#!/bin/bash

{
disk="/dev/xvdb"
lv_size=20 ##in GB
hostname="test-server.test.in"
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

echo "installing node and pm2" 
pushd /apps/lib
yum install -y wget
yum install -y git	
wget https://nodejs.org/dist/v0.12.7/node-v0.12.7-linux-x64.tar.gz
tar -zxf node-v0.12.7-linux-x64.tar.gz
ln -s -f /apps/lib/node-v0.12.7-linux-x64/bin/node /usr/bin/node
ln -s -f  /apps/lib/node-v0.12.7-linux-x64/bin/npm /usr/bin/npm
npm install pm2
useradd pm2 -d /apps/pm2
rm -f `which pm2`
echo "export PATH=$PATH:/apps/lib/node_modules/pm2/bin" >> /apps/pm2/.bashrc
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
echo "[mongodb-org-3.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/6/mongodb-org/3.0/x86_64/
gpgcheck=0
enabled=1" >> /etc/yum.repos.d/mongodb-org-3.0.repo
yum install -y mongodb-org
sed -i.bak 's/dbPath.*/dbPath: \/apps\/mongo/g'  /etc/mongod.conf
chown -R mongod. /apps/mongo

echo "installing redis"
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm 
yum install -y redis --enablerepo=epel

echo "installing other packages"
yum install -y telnet
yum install -y sysstat
yum install -y httpd
sed -i "s/#ServerName www.example.com:80/ServerName $hostname:80/g" /etc/httpd/conf/httpd.conf
sed -i "s/Indexes//g" /etc/httpd/conf/httpd.conf 

echo "updating config"
mv /var/www/ /apps/
ln -s /apps/www /var/www
mv /var/log /apps/logs/var_log
ln -s /apps/logs/var_log /var/log
#chown -R mysql. /apps/mysql

chkconfig httpd on
chkconfig mongod on
chkconfig redis on

service httpd start
service mongod start
service redis start
} | tee /tmp/setup.log