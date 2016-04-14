string=`sudo service mysqld status`;
recipients="devops@clicklabs.in, vikas.kumar@clicklabs.in, kunal.sethiya@click-labs.com, sanjay@click-labs.com"

if [[ $string != *"running"* ]]
then
	echo -e "Here is the status of MySQL service on Tookan website server \n<< $string >>\nPlease check." | mail -s "Alert!!! MySQL service stopped on tookan website (54.173.213.236)!!!" $recipients
fi
