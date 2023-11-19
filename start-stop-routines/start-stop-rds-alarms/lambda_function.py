import boto3
import time
from datetime import datetime, timedelta

# Define RDS client connection
rds = boto3.client('rds')
cloudwatch = boto3.client('cloudwatch')

DAYS = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
]

def manage_alarms(db_identifier, action):
    
    # List metrics through the pagination interface
    paginator = cloudwatch.get_paginator('list_metrics')
    
    for metrics in paginator.paginate(Dimensions=[{'Name': 'DBInstanceIdentifier','Value': db_identifier}]):
        for metric in metrics['Metrics']:
            # print(f'Metric: {metric}')
            
            alarms = cloudwatch.describe_alarms_for_metric(
            MetricName = metric['MetricName'],
            Namespace = metric['Namespace'],
            Dimensions = metric['Dimensions']
            )
            
            if alarms['MetricAlarms']:
                for alarm in alarms['MetricAlarms']:
                    alarmName = alarm['AlarmName']
                    
                    # print(f'Alarm: {alarmName}')
                
                    if action == 'disable':
                        cloudwatch.disable_alarm_actions(AlarmNames=[alarmName])
                        print(f'Alarm {alarmName} is disabled!')
                    elif action == 'enable':
                        cloudwatch.enable_alarm_actions(AlarmNames=[alarmName])
                        print(f'Alarm {alarmName} is enabled!')


def lambda_handler(event, context):

    # Get actual local time
    current_time = datetime.now() - timedelta(hours=3)
    current_time_local = current_time.strftime("%H:%M")
    current_day = current_time.strftime("%A")
    print(f'Current time: {current_time_local}')
    print(f'Current day: {current_day}')
    
    # Deacribe all RDS instances
    response = rds.describe_db_instances()
    db_instances = response['DBInstances']
    
    # Set empty arrays
    stop_instances = []   
    start_instances = []
    v_read_replica=[]

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

                print(f"Instance: {db_instance['DBInstanceIdentifier']}")

                period = []
                i = 0
                j = 0
                scheduled = 'Inactive'
                
                # Get instances tags
                tags_response = rds.list_tags_for_resource(ResourceName=db_instance['DBInstanceArn'])
                tags = tags_response['TagList']
                
                for tag in tags:
                    if 'Scheduled' in tag['Key']:
                        scheduled = tag['Value']
                
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
                                numPeriod = tag['Value']       
                                print(f'Period: {numPeriod}')
                                day = numPeriod.split('-')
                                print(f'Days: {day}')
            
                        # Add instance in array to stop
                        for tag in tags:
                            if tag['Key'] == 'ScheduleStop-' + str(period[j]):
                                
                                # Checks if the period has a range of days
                                if len(day) > 1:
                                    
                                    # Check if the current day is within the period
                                    if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                        print(f'{current_day} is on Stop period-{period[j]}')
                                        
                                        if tag['Value'] == current_time_local:
                                            print(f'{db_instance["DBInstanceIdentifier"]} is on the Stop time')

                                            if db_instance['DBInstanceStatus'] == 'available':
                                                stop_instances.append(db_instance['DBInstanceIdentifier'])
                                            else:
                                                print(f'{db_instance["DBInstanceIdentifier"]} state is: {db_instance["DBInstanceStatus"]}')
                                                
                                    else:
                                        print(f'{current_day} is not on Stop period-{period[j]}')
                                else:

                                    # Checks if the period has a sigle day
                                    if current_day == day[0]:
                                        if tag['Value'] == current_time_local:
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the Stop time')

                                                if db_instance['DBInstanceStatus'] == 'available':
                                                    stop_instances.append(db_instance['DBInstanceIdentifier'])
                                                else:
                                                    print(f'{db_instance["DBInstanceIdentifier"]} state is: {db_instance["DBInstanceStatus"]}')
                                                    
                                    else:
                                        print(f'{current_day} is not on Stop period-{period[j]}')

                        # Add instance in array to start
                        for tag in tags:
                            if tag['Key'] == 'ScheduleStart-' + str(period[j]):
                                    
                                if len(day) > 1:
                                    # Check if the current day is within the period
                                    if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                        print(f'{current_day} is on Start period-{period[j]}')
                                        
                                        if tag['Value'] == current_time_local:
                                            print(f'{db_instance["DBInstanceIdentifier"]} is on the Start time')

                                            if db_instance['DBInstanceStatus'] == 'stopped':
                                                start_instances.append(db_instance['DBInstanceIdentifier'])
                                            else:
                                                print(f'{db_instance["DBInstanceIdentifier"]} state is: {db_instance["DBInstanceStatus"]}')
                                    else:        
                                        print(f'{current_day} is not on Start period-{period[j]}')
                                else:

                                    # Checks if the period has a sigle day
                                    if current_day == day[0]:
                                        if tag['Value'] == current_time_local:
                                            print(f'{db_instance["DBInstanceIdentifier"]} is on the Start time')
                                            if db_instance['DBInstanceStatus'] == 'stopped':
                                                start_instances.append(db_instance['DBInstanceIdentifier'])
                                            else:
                                                print(f'{db_instance["DBInstanceIdentifier"]} state is: {db_instance["DBInstanceStatus"]}')
                                    else:        
                                        print(f'{current_day} is not on Start period-{period[j]}')
                        j = j+1
            
    # Stop all instances tagged to stop.
    if len(stop_instances) > 0:
        for stop_instance in stop_instances:
            response = rds.stop_db_instance(DBInstanceIdentifier=stop_instance)
            print(f'Stopping instance: {stop_instance}')

            manage_alarms(stop_instance, 'disable')
    else:
        print("No instances to stop.")
        
    # Start instances tagged to start. 
    if len(start_instances) > 0:
        for start_instance in start_instances:
            response = rds.start_db_instance(DBInstanceIdentifier=start_instance)
            print(f'Starting instance: {start_instance}')

            manage_alarms(start_instance, 'enable')
    else:
        print("No instances to start.")