# Start/Stop RDS periodically and Enable/Disable CloudWatch alarms.

# This function allows you to create startup/stop routines for RDS Instances on different days and 
# times and enable/disable CloudWatch alarms corresponding to the Instance that suffered the action.

import boto3
import os
from datetime import datetime, timedelta

# Define AWS Region
REGIONS_AWS = os.environ['REGIONS']
REGIONS = REGIONS_AWS.replace(' ', '')
AWS_REGIONS = REGIONS.split(',')

# Define Disable/Enable 
ALARMS_MANAGER = os.environ['ALARMS_MANAGER']

DAYS = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
]

def manage_alarms(list_alarms, instance_name, db_identifier, action, cloudwatch):
    print(f'----------------------------------------')
    print(f'Checking alarms for {instance_name}.')
    for alarms in list_alarms:
        for dimensions in alarms['Dimensions']:

            if dimensions['Name'] == db_identifier and dimensions['Value'] == instance_name:
        
                if action == 'disable':
                    cloudwatch.disable_alarm_actions(AlarmNames=[alarms['AlarmName']])
                    print(f"Alarm {alarms['AlarmName']} is disabled!")
                elif action == 'enable':
                    cloudwatch.enable_alarm_actions(AlarmNames=[alarms['AlarmName']])
                    print(f"Alarm {alarms['AlarmName']} is enabled!")


def lambda_handler(event, context):

    print(f'----------------------------------------')

    # Get actual local time
    current_time = datetime.now() - timedelta(hours=3)
    current_time_local = current_time.strftime("%H:%M")
    current_day = current_time.strftime("%A")
    print(f'Current time: {current_time_local}')
    print(f'Current day: {current_day}')
    
    # Iterate over each region
    for region in AWS_REGIONS:
        
        # Define RDS client connection
        rds = boto3.client('rds', region_name=region)

        # Define CloudWatch client connection
        cloudwatch = boto3.client('cloudwatch', region_name=region)

        # Set empty lists
        alarms = []
        
        stop_instances = []   
        start_instances = []
        v_read_replica=[]

        all_alarms = cloudwatch.describe_alarms()
        for metric_alarms in all_alarms['MetricAlarms']:
            alarms.append(metric_alarms)

        response = rds.describe_db_instances()
        db_instances = response['DBInstances']

        # Increase the read replica array if it exists
        for r_instance in db_instances:
            readReplica = r_instance['ReadReplicaDBInstanceIdentifiers']
            v_read_replica.extend(readReplica)

        # Traverses all RDS instances
        for db_instance in db_instances:

            # The if condition below excludes aurora and documentdb clusters.
            if db_instance['Engine'] not in ['aurora-mysql','aurora-postgresql', 'docdb']:

                # The if condition below excludes read replicas.
                if db_instance['DBInstanceIdentifier'] not in v_read_replica and len(db_instance['ReadReplicaDBInstanceIdentifiers']) == 0:

                    print(f'----------------------------------------')
                    print(f"Checking instance {db_instance['DBInstanceIdentifier']} in {region}.")

                    period = []
                    i = 0
                    j = 0
                    scheduled = 'Inactive'
                    
                    # Get instances tags
                    tags_response = rds.list_tags_for_resource(ResourceName=db_instance['DBInstanceArn'])
                    tags = tags_response['TagList']
                    
                    for tag in tags:
                        if 'Scheduled' in tag['Key']:
                            scheduled = tag['Value'].strip()
                    
                    print(f'Scheduled: {scheduled}')
                    
                    if scheduled == 'Active':
                        # Get all Period tag keys (e.g. Period-1, Period-2, ...) 
                        for tag in tags:      
                            if 'Period' in tag['Key']:
                                period.append(tag['Key'].split('-')[1])
                                i = i+1
                        
                        # Get all Period tag values (e.g. Sunday-Saturday, Monday-Friday, ...) 
                        while j < i:
                            for tag in tags:
                                if tag['Key'] == 'Period-' + str(period[j]):
                                    numPeriod = tag['Value'].strip()       
                                    print(f'Period: {numPeriod}')
                                    day = numPeriod.split('-')
                                    # print(f'Days: {day}')
                
                            # Add instance in array to stop
                            for tag in tags:
                                if tag['Key'] == 'ScheduleStop-' + str(period[j]):
                                    
                                    # Checks if the period has a range of days
                                    if len(day) > 1:
                                        
                                        # Check if the current day is within the period
                                        if DAYS.index(current_day) in range(DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                            print(f'{current_day} is on Stop Period-{period[j]}')
                                            
                                            if tag['Value'] == current_time_local:
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the Stop time')

                                                if db_instance['DBInstanceStatus'] == 'available':
                                                    stop_instances.append(db_instance['DBInstanceIdentifier'])
                                                else:
                                                    print(f'The {db_instance["DBInstanceIdentifier"]} was not added to the stop list because its state is: {db_instance["DBInstanceStatus"]}.')
                                                    
                                        else:
                                            print(f'{current_day} is not on Stop Period-{period[j]}')
                                    else:

                                        # Checks if the period has a sigle day
                                        if current_day == day[0]:
                                            if tag['Value'] == current_time_local:
                                                    print(f'{db_instance["DBInstanceIdentifier"]} is on the Stop time')

                                                    if db_instance['DBInstanceStatus'] == 'available':
                                                        stop_instances.append(db_instance['DBInstanceIdentifier'])
                                                    else:
                                                        print(f'The {db_instance["DBInstanceIdentifier"]} was not added to the stop list because its state is: {db_instance["DBInstanceStatus"]}.')
                                                        
                                        else:
                                            print(f'{current_day} is not on Stop Period-{period[j]}')

                            # Add instance in array to start
                            for tag in tags:
                                if tag['Key'] == 'ScheduleStart-' + str(period[j]):
                                        
                                    if len(day) > 1:
                                        # Check if the current day is within the period
                                        if DAYS.index(current_day) in range(DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                            print(f'{current_day} is on Start Period-{period[j]}')
                                            
                                            if tag['Value'] == current_time_local:
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the Start time')

                                                if db_instance['DBInstanceStatus'] == 'stopped':
                                                    start_instances.append(db_instance['DBInstanceIdentifier'])
                                                else:
                                                    print(f'The {db_instance["DBInstanceIdentifier"]} was not added to the start list because its state is: {db_instance["DBInstanceStatus"]}.')
                                        else:        
                                            print(f'{current_day} is not on Start Period-{period[j]}')
                                    else:

                                        # Checks if the period has a sigle day
                                        if current_day == day[0]:
                                            if tag['Value'] == current_time_local:
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the Start time')
                                                if db_instance['DBInstanceStatus'] == 'stopped':
                                                    start_instances.append(db_instance['DBInstanceIdentifier'])
                                                else:
                                                    print(f'The {db_instance["DBInstanceIdentifier"]} was not added to the start list because its state is: {db_instance["DBInstanceStatus"]}')
                                        else:        
                                            print(f'{current_day} is not on Start Period-{period[j]}')
                            j = j+1
                
        # Stop all instances tagged to stop.
        if len(stop_instances) > 0:
            print(f'----------------------------------------')
            for stop_instance in stop_instances:
                if ALARMS_MANAGER == 'True':
                    manage_alarms(alarms, stop_instance, 'DBInstanceIdentifier', 'disable', cloudwatch)
                try:
                    action = rds.stop_db_instance(DBInstanceIdentifier=stop_instance)
                    print(f'Stopping instance: {stop_instance}')
                    print(action)
                except Exception as e:
                    print (f'[Cannot stop instance {stop_instance}] {e}')
        else:
            print(f'----------------------------------------')
            print(f'No instances to stop in {region}.')
            
        # Start instances tagged to start. 
        if len(start_instances) > 0:
            print(f'----------------------------------------')
            for start_instance in start_instances:
                if ALARMS_MANAGER == 'True':
                    manage_alarms(alarms, start_instance, 'DBInstanceIdentifier', 'enable', cloudwatch)
                try:
                    action = rds.start_db_instance(DBInstanceIdentifier=start_instance)
                    print(f'Starting instance: {start_instance}')
                    print(action)
                except Exception as e:
                    print (f'[Cannot start instance {start_instance}] {e}')
        else:
            print(f'----------------------------------------')
            print(f'No instances to start in {region}.')

    print(f'----------------------------------------')
    
    return 'Success!'