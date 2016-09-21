#!/home/vivekpuri/.virtualenvs/boto/bin/python

#Boto3 scripts to launch aws instances

import boto3, os, sys, ConfigParser
args = {	
     "DryRun":False,
     "ImageId" : '',
     "MinCount" : 1,
     "MaxCount" : 1,
     "KeyName" : '',
     "SecurityGroups" : [],
     "SecurityGroupIds" : [],
     "UserData" : '',
     "InstanceType" : 't2.small',
     "BlockDeviceMappings" : [
         {
             'DeviceName': '/dev/xvda',
             'Ebs': {
                 'VolumeSize': 10,
                 'VolumeType': 'standard'
             },
         },
         {
             'DeviceName': '/dev/xvdb',
             'Ebs': {
                 'VolumeSize': 20,
                 'DeleteOnTermination': True,
                 'VolumeType': 'standard',
             },
         },
     ],
     "Monitoring" : {'Enabled': False},
     "SubnetId" : '',
     "DisableApiTermination" : True,
     "InstanceInitiatedShutdownBehavior" : 'stop',	
     "EbsOptimized" : False
 }

def launch(args):
	try:
		instance = ec2.create_instances(
			                           DryRun = args['DryRun'], 
			                           ImageId=args['ImageId'], 
			                           MinCount = args['MinCount'], 
			                           MaxCount = args['MaxCount'], 
			                           KeyName = args['KeyName'],
			                           SecurityGroups = args['SecurityGroups'], 
			                           SecurityGroupIds = args['SecurityGroupIds'],
                                       UserData = args['UserData'],
			                           InstanceType = args['InstanceType'],
                                       BlockDeviceMappings = args['BlockDeviceMappings'], 
			                           Monitoring = args['Monitoring'], 
			                           SubnetId = args['SubnetId'],
			                           DisableApiTermination = args['DisableApiTermination'], 
			                           InstanceInitiatedShutdownBehavior = args['InstanceInitiatedShutdownBehavior'],
			                           EbsOptimized = args['EbsOptimized']
										)
		return instance
	
	except Exception as e:
		print "Couldn't launch Instance !! Error: " , e
		exit(1)

def check_sg(substr):
	## TO check if there exists a security group with the string 'ssh' in its name.
    sgs = ec2.security_groups.all()
    for sg in sgs:
        if substr in sg.group_name :
            return sg.group_id
    return False

def create_sg(sg_name):
	## To create a security group to grant ssh access and common accessibility
	try:
            response = ec2.create_security_group(GroupName=sg_name, Description='sg_ssh for common accessibility rules')
            for port in [80, 443]:
                response.authorize_ingress(IpProtocol="tcp",CidrIp="0.0.0.0/0",FromPort=port,ToPort=port)    
            for port in [22, 27017, 3306]:
                response.authorize_ingress(IpProtocol="tcp", CidrIp="112.196.55.64/28", FromPort=port, ToPort=port)
                response.authorize_ingress(IpProtocol="tcp", CidrIp="115.248.185.130/32", FromPort=port, ToPort=port)
                response.authorize_ingress(IpProtocol="tcp", CidrIp="182.19.85.146/32", FromPort=port, ToPort=port)
                response.authorize_ingress(IpProtocol="tcp", CidrIp="52.202.38.111/32", FromPort=port, ToPort=port)
        
            response.authorize_ingress(IpProtocol="tcp",CidrIp="0.0.0.0/0",FromPort=3000,ToPort=3005)    
            return response.group_id
	except Exception as e :
            print "Error : ", e
            exit(1)

def createKey(keyName):
	if (not keyName):
		print 'Error !! Empty KeyName found..Exiting'
		exit(1)
	try :
		key_created = ec2.create_key_pair(KeyName=keyName)
		file_name = keyName + '.pem'
		with open(file_name, 'w') as file:
			file.write(key_created.key_material)
		os.system('chmod 600 %s' %(file_name))
	except Exception as e:
		print 'Error in createKeys', e
		exit(1)


##Funtion def ends here

##Main start here

if __name__ == "__main__" :
        try :
            keyName = sys.argv[1]
        except :
            keyName = None
        config = ConfigParser.RawConfigParser()
        osconfig = ConfigParser.RawConfigParser()
        config.read("config.cfg")
        OS = config.get('Config', 'OS')
        if ( OS == "centos" ):
            osconfig.read("centos.cfg")
        elif ( OS == "ubuntu" ):
            osconfig.read("ubuntu.cfg")
        serverName = config.get('Config', 'ServerName')
        environment = config.get('Config', 'Environment')
        region = config.get('Config', 'Region')
        amiId = osconfig.get(region, 'ImageId')
        args['ImageId'] = amiId
        with open('script.sh', 'r') as myfile:
            data=myfile.read()
        args['UserData'] = data
        try :
            ec2 = boto3.resource('ec2', region_name = region)
        except Exception as e :
            print "Couldn't connect error: ", e
        name = serverName + "-" + environment + "." + serverName + '.com'
        flag=0
        if (not keyName) :
            while True :
                sgs = ec2.key_pairs.all()
                for i in sgs:
                    if i.name in serverName :
                        args['KeyName'] = i.name
                        print "Key with name"+ i.name +" already present"
                        flag=1
                        break
                if ( flag==0):
                    print 'You have not specified the key. Do you want to create a new one (y/n)? : ',
                    choice = raw_input()
                    if choice == 'y' or choice == 'Y':
                        print 'Enter key name : ',
                        keyName = raw_input()
                        createKey(keyName)
                        args['KeyName'] = keyName
                        break   
                    elif choice == 'n' or choice == 'N':
                        print 'Cannot proceed without a key..exiting',
                        exit(0)
                elif (flag==1):
                    break
        else :
            args['KeyName'] = keyName
        args['SecurityGroupIds'].append(check_sg('ssh') or create_sg('sg_ssh'))
        instance = launch(args)
        instance[0].wait_until_running()
        instance[0].load()
        info = open("serverInfo.txt", "w+")
        instanceId=instance[0].instance_id
        publicIp=instance[0].public_ip_address
        print instanceId, publicIp
        info.write("PublicIP="+publicIp + "\nInstanceID=" + instanceId);
        ec2.create_tags(Resources = [instance[0].instance_id], Tags=[{'Key': 'Name', 'Value': name}])