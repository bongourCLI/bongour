#!/bin/bash
server=`cat config.cfg | grep "ServerName" | awk -F "=" {'print$2'}`
env=`cat config.cfg | grep "Environment" | awk -F "=" {'print$2'}`
key=`cat config.cfg | grep "Key" | awk -F "=" {'print$2'}`
os=`cat config.cfg | grep "OS" | awk -F "=" {'print$2'}`
sed -i.bak 's|SERVER|'"$server"'|g' script.sh
sed -i.bak 's|ENV|'"$env"'|g' script.sh
export AWS_PROFILE=$server-admin
if [ ${#key} -gt 0 ]
then
    python server_launch.py $key
else
    python server_launch.py 
fi
echo "Waiting for the server to come up....."
sleep 60
if [ "$env" == "dev" ]
then
    if [ "$os" == "centos" ];
    then
        user="ec2-user"
    elif [ "$os" == "ubuntu" ];
    then 
        user="ubuntu"
    fi
    echo "Creating SSH key for the pm2 user"
    ssh-keygen -f $server-$env.pem -t rsa -N ''
    IP=`cat serverInfo.txt | grep "PublicIP" | awk -F "=" {'print$2'}`
    cat $server-$env.pem.pub | ssh -i $server.pem $user@$IP "sudo su - pm2 -c 'mkdir -p /apps/pm2/.ssh && cat >  /apps/pm2/.ssh/authorized_keys && chmod -R 700 /apps/pm2/.ssh'"
fi
sed -i.bak 's|server=.*|server=SERVER|g' script.sh
sed -i.bak 's|env=.*|server=ENV|g' script.sh
rm -rf serverInfo.txt
