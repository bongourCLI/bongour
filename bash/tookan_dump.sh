#!/bin/bash
user="root"
pass="KhfkDgEtQHgHXS8mBaAd"
db_name="tookan"
echo "`date` initiating dump for $db_name"
dump_name="$db_name"`date +"%H-%M-%d-%m-%Y"`".sql"
mysqldump --single-transaction -u $user -p$pass $db_name > $dump_name
if [[ $? == 0 ]];then
        echo "`date` Dump completed"
        tar -cf "$dump_name".tar $dump_name
        echo "`date` Moving to s3"
        aws s3 cp "$dump_name".tar s3://tookandumps/

        echo "`date` Removing dump directory $dump_name"
        rm -rf $dump_name*
else
        echo "`date` Error in obtaining dump."
fi

