import json
import logging
import time
import json
import os
from time import sleep
import boto3
from boto3.dynamodb.conditions import Key
from boto3.dynamodb.conditions import Attr

SSM_AFT_REQUEST_METADATA_PATH = "/aft/resources/ddb/aft-request-metadata-table-name"
AFT_REQUEST_METADATA_EMAIL_INDEX = "emailIndex"
session = boto3.Session()
logger = logging.getLogger()
dynamodb = boto3.resource('dynamodb', region_name='us-west-2')
table = dynamodb.Table('aft-request-metadata')

if 'log_level' in os.environ:
    logger.setLevel(os.environ['log_level'])
    logger.info("Log level set to %s" % logger.getEffectiveLevel())
else:
    logger.setLevel(logging.INFO)



def lambda_handler(event, context):
	print('------------------------')
	print(event)
	#1. Iterate over each record
	try:
		for record in event['Records']:
			#2. Handle event by type
			if record['eventName'] == 'INSERT':
				handle_insert(record)
			elif record['eventName'] == 'REMOVE':
				logger.info("Ignore Remove Event")
			elif record['eventName'] == 'MODIFY':
				logger.info("Ignore Modify Event")				
		print('------------------------')
		return "Success!"

	except Exception as e: 
		print(e)
		print('------------------------')
		return "Error"


def handle_insert(record):
	try:

		print("Handling INSERT Event")
	
	#3a. Get newImage content
		newImage = record['dynamodb']['NewImage']
		logger.debug(newImage)
	#3b. Parse values
		AccName = newImage['control_tower_parameters']['M']['AccountName']['S']
		AccEmail = newImage['control_tower_parameters']['M']['AccountEmail']['S']
		SSOEmail = newImage['control_tower_parameters']['M']['SSOUserEmail']['S']
		SSOFirstName = newImage['control_tower_parameters']['M']['SSOUserFirstName']['S']
		SSOLastName = newImage['control_tower_parameters']['M']['SSOUserLastName']['S']
		DDEvent = newImage['ddb_event_name']['S']
		SourceOU = newImage['control_tower_parameters']['M']['ManagedOrganizationalUnit']['S']	

	#3c. Print it
		print ('Account Email is '  + AccEmail)
		print ('Account Name is '  + AccName)
		print ('Account SSOEmail is '  + SSOEmail)
		print ('Account SSOFirstName is '  + SSOFirstName)
		print ('Account SSOLastName is '  + SSOLastName)
		print ('Account DDEvent is '  + DDEvent)
		print ('Source OU  is '  + SourceOU)	

		if DDEvent == 'REMOVE':

		# boto3 dynamo query
			print('Retrieve Account ID from AFT Metadata Table')
			response = table.query(
				IndexName='emailIndex',
				KeyConditionExpression=Key('email').eq(AccEmail))
	
			print("The query returned the following items:")

			for i in response['Items']:
				print(i['id'])
				Account=i['id']

			print('------------------------')
			print(Account + ' with Account Email as ' +  AccEmail + ' will be closed and moved from ' +  SourceOU + ' to  SUSPENDED OU')
			print('------------------------')

			handle_account_close(Account, SourceOU)

	except Exception as e: 
		print(e)
		print('------------------------')
		return "Error"			

def handle_account_close(Account, SourceOU):

	try:

		stsMaster = boto3.client("sts")
		cross_account_role_name = os.getenv("CROSS_ACC_ROLE_NAME")
		ct_account_info = os.getenv("AFT_CT_ACCOUNT")
		role_arn = f"arn:aws:iam::{ct_account_info}:role/{cross_account_role_name}"
		source_ou = SourceOU
		ct_destination_ou = os.getenv("DESTINATIONOU")
		parentouid = os.getenv("ROOTOU_ID")

		
		print("Handling Account Closure with Assume CT Role")
		assumeRoleResult  = stsMaster.assume_role (
        	RoleArn=role_arn,
        	RoleSessionName="AWSAFT-Acc-CloseSession"
    	)

		sessionAccount = boto3.Session (
        	aws_access_key_id=assumeRoleResult["Credentials"]["AccessKeyId"],
        	aws_secret_access_key=assumeRoleResult["Credentials"]["SecretAccessKey"],
        	aws_session_token=assumeRoleResult["Credentials"]["SessionToken"],
        	region_name=os.getenv("REGION"),
    	)

		print('Retrieve Org ID of ' + SourceOU + 'from Control Tower Account')

		SourceOrgIdclient = sessionAccount.client(service_name='organizations', region_name=os.getenv("REGION"))

		paginator = SourceOrgIdclient.get_paginator('list_organizational_units_for_parent')
		ou_list = paginator.paginate(ParentId=str(parentouid))

		for page in ou_list:
			for ou in page['OrganizationalUnits']:
				if ou['Name'] == source_ou:
				# if ou['Name'] == 'Sandbox':
					source_ou_id = ou['Id']
					break
	

		print('Org ID of ' + SourceOU + ' is ' + source_ou_id)


		accountclient = sessionAccount.client(service_name='organizations', region_name=os.getenv("REGION"))

		close_account_resp = accountclient.close_account(
			AccountId=Account)
			
		print('------------------------')		
		print("Account closure initiated for account: {}".format(Account))
		print('------------------------')		

		print('------------------------')
		print('Sleep for 10 seconds to move Account to SUSPENDED OU')
		print('------------------------')
		sleep(10)

		move_ou_account_resp = accountclient.move_account(
			AccountId=Account,
			SourceParentId=source_ou_id,
			DestinationParentId=ct_destination_ou
		)
		
		print('------------------------')		
		print("Account Moved to SUSPENDED OU")
		print('------------------------')



	except Exception as e: 
		print(e)
		print('------------------------')
		return "Error"

