#!/bin/bash 
dt=`date +"%d-%m-%Y"`
for i in `aws s3 ls s3://ab-mongo-dumps | awk '{print $4}'`
do 
    	if [[ $i != *"$dt"* ]]
	then
		echo "Removing file $i"	
		aws s3 rm s3://ab-mongo-dumps/$i
	fi
done
