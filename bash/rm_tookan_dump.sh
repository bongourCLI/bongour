#!/bin/bash 
{
cur_dt=`date +"%Y-%m-%d %H:%M"`
for i in `aws s3 ls s3://tookandumps | awk '{print $4}'`
do 
	dt=`echo $i | rev | cut -c 9- |  cut -c -16 | rev`
	diff=`echo $(( ( $(date -ud "$cur_dt" +'%s') - $(date -ud "$dt" +'%s') )/60/60 ))`
	if [[ "$diff" -ge 24 ]]; then
		echo "Removing file $i"	
		aws s3 rm s3://tookandums/$i
	fi
done
} | tee -a log_file.log

