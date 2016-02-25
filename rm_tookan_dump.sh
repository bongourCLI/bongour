#!/bin/bash 
dt=`date +"%H-%M-%d-%m-%Y"`
timing=""
for i in `aws s3 ls s3://tookandumps | awk '{print $4}'| sort`
do 
	cur_time=`echo $i | rev | cut -c 20- | rev`
	if [[ "$timing" == "$cur_time" ]]; then
		echo "Removing file $i"	
		aws s3 rm s3://tookandums/$i
	else
		timing=$cur_time
	fi
done
