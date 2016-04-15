#!/home/vivekpuri/.virtualenvs/boto/bin/python

#Boto3 scripts to launch aws instances

import boto3
import os
import sys
import ConfigParser
regions = ['us-west-2']
args = {	
    "DryRun":False,
    "ImageId" : 'ami-c229c0a2',
    "MinCount" : 1,
    "MaxCount" : 1,
    "KeyName" : '',
    "SecurityGroups" : [],
    "SecurityGroupIds" : [],
    "InstanceType" : 't2.micro',
    "BlockDeviceMappings" : [
        {
            'DeviceName': '/dev/xvdb',
            'Ebs': {
                'VolumeSize': 20,
                'DeleteOnTermination': True,
                'VolumeType': 'standard',
                'Encrypted': False
            },
        },
    ],
    "Monitoring" : {'Enabled': False},
    "SubnetId" : 'subnet-4f659f2b',
    "DisableApiTermination" : True,
    "InstanceInitiatedShutdownBehavior" : 'stop',
    "EbsOptimized" : False
}

def launch(args):
	if args['BlockDeviceMappings'][0]['DeviceName'] == '/dev/xvdb' and not args['InstanceType'].startswith(('t2', 'c4', 'm4')):
		print 'You may want to change the BlockDeviceMappings for %s instance type as it comes along\
		        with a instance storage other than EBS.' %(args['InstanceType'])
		exit(0)
	
	try:
		instance = ec2.create_instances(
			                           DryRun = args['DryRun'], 
			                           ImageId=args['ImageId'], 
			                           MinCount = args['MinCount'], 
			                           MaxCount = args['MaxCount'], 
			                           KeyName = args['KeyName'],
			                           SecurityGroups = args['SecurityGroups'], 
			                           SecurityGroupIds = args['SecurityGroupIds'],
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
		if substr in sg.group_name: 
			return sg.group_id
	return False

def create_sg(sg_name):
	## To create a security group to grant ssh access and common accessibility
	try :
		response = ec2.create_security_group(GroupName=sg_name, Description='sg_ssh for common accessibility rules')
		for port in [22, 80, 443]:
			response.authorize_ingress(IpProtocol="tcp",CidrIp="0.0.0.0/0",FromPort=port,ToPort=port)
		return response.group_id
	except Exception as e : 
		print "Error : ", e
		exit(1)

def create_key(key_name):
	if (not key_name):
		print 'Error !! Empty KeyName found..Exiting'
		exit(1)
	try :
		key_created = ec2.create_key_pair(KeyName=key_name)
		file_name = key_name + '.pem'
		with open(file_name, 'w') as file:
			file.write(key_created.key_material)
		os.system('sudo chmod 600 %s' %(file_name))
	except Exception as e:
		print 'Error in create_keys', e
		exit(1)


##Funtion def ends here

##Main start here

if __name__ == "__main__" :
	try :
		key_name = sys.argv[1]
	except :
		key_name = None

	try :
		ec2 = boto3.resource('ec2', region_name = regions[0])
	except Exception as e :
		print "Couldn't connect error: ", e
	config_file = config.cfg
	config = ConfigParser.RawConfigParser()
	config.read(config_file)
	server_name = config.get('Section', 'server_name')
	environment = config.get('Section', 'environment')
	name = server_name + "-" + environment + "." + server_name + '.com'

	if (not key_name) :
		while True :
			print 'You have not specified the key. Do you want to create a new one (y/n)? : ',
			choice = raw_input()
			if choice == 'y' or choice == 'Y':
				print 'Enter key name : ',
				key_name = raw_input()
				create_key(key_name)
				args['KeyName'] = key_name
				break
			elif choice == 'n' or choice == 'N':
				print 'Cannot proceed without a key..exiting',
				exit(0)

	else :
		args['KeyName'] = key_name

	args['SecurityGroupIds'].append(check_sg('ssh') or create_sg('sg_ssh'))

	print args['BlockDeviceMappings'][0]['DeviceName']
	instance = launch(args)
	print instance[0].instance_id
	ec2.create_tags(Resources = [instance[0].instance_id], Tags=[{'Key': 'Name', 'Value': name}])


