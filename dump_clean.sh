#!/bin/bash
 
#Correct file for s3 dump cleaning

pushd ~/Downloads/dumps/

# Script for removing 3 days back databackups
dt=`date +"%d-%m-%Y" -d "-3 day"`
for i in `aws s3 ls s3://ab-mongo-dumps| grep $dt | awk '{print $4}'|sort`
do 
	echo "Removing file $i"	
	aws s3 rm s3:://ab-mongo-dumps/$i &
done

# Script for removing 2 days back databackups
dt=`date +"%d-%m-%Y" -d "-2 day"`
arr=()
for i in `aws s3 ls s3://ab-mongo-dumps| grep $dt | awk '{print $4}'|sort`
do 
	arr+=("$i")
done

for(( i=0; i < ${#arr[@]}; i++ ))
do
	name=${arr[$i]::-20}
	for(( j=$i+1; j < ${#arr[@]}; j++ ))	
	do
		rname=${arr[$j]::-20}
		if [[ "$name" == "$rname" ]]; then
			echo "Removing file ${arr[$j]}"			
			aws s3 rm s3:://ab-mongo-dumps/${arr[$j]} &
			i=$i+1
		else
			break
		fi
	done
done

# Script for removing 1 day back databackups

dt1=`date +"%d-%m-%Y" -d "-1 day"`
arr1=()
for i in `aws s3 ls s3://ab-mongo-dumps| grep $dt | awk '{print $4}'|sort`
do 
	arr1+=("$i")
done

for(( i=0; i < ${#arr1[@]}; i++ ))
do
	if [[ -n  ${arr1[$i]} ]]; then
		m1=`md5sum  ${arr1[$i]}`	
		for(( j=$i+1; j < ${#arr1[@]}; j++ ))	
		do
			if [[ -n  ${arr1[$j]} ]]; then	
				m2=`md5sum  ${arr1[$j]}`
				m1=${m1::-20}
				m2=${m2::-20}
				echo "Checking file ${arr1[$i]} and ${arr1[$j]}"			
				if [[ "$m1" == "$m2" ]]; then
					echo "Removing file ${arr1[$j]}"			
					aws s3 rm s3:://ab-mongo-dumps/${arr1[$j]} &
					delete=( ${arr1[$j]} )
					arr1=( "${arr1[@]/$delete}" )
				else
					break
				fi
			fi
		done
	fi
done
popd


