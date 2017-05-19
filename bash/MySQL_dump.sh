#!/bin/bash

conf_file="do_mysql_dump.conf"
log_file="do_mysql_dump.log"
meta_file="do_mysql_dump.meta"

pushd /usr/local/dumps
{
grep -vE "^\s*$|^#" < $conf_file | while read -r line
do
read id host db user pass <<< "$line"
echo "`date` initiating dump for $id $host $db"
db_name=`echo "$id"_"$db"`
dump_name="$db_name"`date +"%H-%M-%d-%m-%Y"`".sql"

mysqldump --single-transaction -h [$host] -u [$user] -p[$pass] $db > $dump_name 2>&1

if [[ $? == 0 ]];then
        echo "`date` Dump completed"
        tar -cf "$dump_name".tar $dump_name
        echo "`date` Moving to s3"
        aws s3 cp "$dump_name".tar s3://ab-mongo-dumps/

        echo "`date` Removing dump directory $dump_name"
        rm -rf $dump_name*
else
        echo "`date` Error in obtainign dump."
fi
done
} | tee -a $log_file
popd

