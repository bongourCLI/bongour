#!/bin/bash 
dt=`date +"%d-%m-%Y"`
for i in `aws s3 ls s3://transvip/db_backup/ | awk '{print $4}'`
do 
    	if [[ $i != *"$dt"* ]]
	then
		echo "Removing file $i"	
		aws s3 rm s3://transvip/db_backup/$i
	fi
done
