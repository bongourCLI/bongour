#!/bin/bash
#
hit_status=`curl -is tookanapp.com | grep HTTP`

recipients="devops@clicklabs.in, vikas.kumar@clicklabs.in, sanjay@click-labs.com"

if [[ ($hit_status == *"200"*) || ($hit_status == *"301"*) || ($hit_status == *"302"*) ]]
then
else
	echo -e "HTTP Status of tookanapp.com : $hit_status \nIP : 54.173.213.236 \nPlease check http://tookanapp.com/" | mail -s "Alert | Tookan website | Critical" $recipients
fi

