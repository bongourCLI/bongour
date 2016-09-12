#!/bin/bash
. ~/.bashrc
gitlab () 
{
    new="new"$1".json"
    old="old"$1".json"
    echo `jq '.' $1.json` > file$1.json
	echo `jq '.[]' $old` > file1$1.json
	cat file$1.json file1$1.json > file2$1.json
	jq -s '.' file2$1.json > $new
    > $old
	cp $new $old
  	rm -rf $1.json file$1.json file1$1.json file2$1.json
}
tailf /var/log/gitlab/nginx/gitlab_access.log | grep --line-buffered "git-upload-pack\|git-receive-pack\|archive.zip" | while read output;
do
    username=`echo $output | awk -F'-' {'print$2'} | awk -F'[' {'print$1'}`
    dtime=`date`
    echo $output$dtime
    if [[ "$output" == *"git-upload-pack"* && "$output" == *"POST"* ]]; 
    then    
        echo "Git clone is done"
        gitrepo=`echo $output | awk -F'POST' {'print$2'} | awk -F'git-upload-pack' {'print$1'}| awk -F' ' {'print$1'}| awk -F'/' {'print$2"/"$3'}`
        echo "{ \"time\": \"$dtime\", \"gitrepo\": \"$gitrepo\", \"info\" : \"Git clone done by $username on  $dtime\" }" > clone.json
        gitlab clone  
    fi
    if [[ "$output" == *"git-receive-pack"* && "$output" == *"200 181"* ]]; 
    then    
        echo "Git push is done"
        gitrepo=`echo $output | awk -F'GET' {'print$2'} | awk -F'git-receive-pack' {'print$1'}| awk -F' ' {'print$1'}| awk -F'/' {'print$2"/"$3'}`
        echo "{ \"time\": \"$dtime\", \"gitrepo\": \"$gitrepo\", \"info\" : \"Git push done by $username on  $dtime\" }" > push.json
        gitlab push
    fi
    if [[ "$output" == *"archive.zip"* && "$output" == *"200"* ]]; 
    then    
        echo "Zip file downloaded"
        gitrepo=`echo $output | awk -F'GET' {'print$2'} | awk -F'archive.zip' {'print$1'}| awk -F' ' {'print$1'}| awk -F'/' {'print$2"/"$3'}`
        IP=`echo $output | awk {'print$1'}`
        echo "{ \"time\": \"$dtime\", \"gitrepo\": \"$gitrepo\", \"info\" : \"Git repo downloaded from IP $IP on  $dtime\" }" > download.json
        gitlab download
    fi
done
