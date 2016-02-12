string=`sudo service mysqld status`
if [[ $string == *"stopped"* ]]
then
        mail -s "Alert!!! MySQL stopped!!!" devops@clicklabs.in <<< "Service MySQL is stopped. Please check."
fi

