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

def manage_alarms(instanceId, action, cloudwatch):
    
    # List metrics through the pagination interface
    paginator = cloudwatch.get_paginator('list_metrics')
    # print(f'Instance: {instanceId}')
    
    for metrics in paginator.paginate(Dimensions=[{'Name': 'InstanceId','Value': instanceId}]):
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

    print(f'----------------------------------------')

    # Get current time (UTC-3) in format H:M
    current_time = datetime.now()-timedelta(hours=3)
    current_time_local = current_time.strftime("%H:%M")
    print(f'Current time: {current_time_local}')
    
    # Get current day in format 'Saturday'
    current_day = current_time.strftime("%A")
    print(f'Current day: {current_day}')
    	
    # Find all the instances that are tagged with Scheduled:Active
    filters = [{
            'Name': 'tag:Scheduled',
            'Values': ['Active']
        }
    ]

    # Iterate over each region
    for region in AWS_REGIONS:

        stopInstances = []   
        startInstances = []

        # Define EC2 client connection
        ec2 = boto3.client('ec2', region_name=region)

        # Define CloudWatch client connection
        cloudwatch = boto3.client('cloudwatch', region_name=region)

        # Search all the instances which contains scheduled filter 
        reservations = ec2.describe_instances(Filters=filters)

        # Check if there are reservations
        if len(reservations['Reservations']) > 0:
            
            # Locate all instances that are tagged to start or stop.
            for instances in reservations['Reservations']:
                
                for instance in instances['Instances']:

                    instance_id = instance['InstanceId']
                    instance_tags = instance['Tags']
                   
                    print(f'----------------------------------------')
                    print(f'Checking instance: {instance_id}')
                    
                    period = []
                    i = 0
                    j = 0
                    scheduled = 'Inactive'
    
                    for tag in instance_tags:
                        if 'Scheduled' in tag['Key']:
                            scheduled = tag['Value'].strip()
                    
                    print(f'Scheduled: {scheduled}')
    
                    if scheduled == 'Active':
                    
                        # Get all Period tag keys (e.g. Period-1, Period-2, ...)
                        for tag in instance_tags:
                            if 'Period' in tag['Key']:
                                tag_key = tag['Key'].strip()
                                period.append(tag_key.split('-')[1])
                                i = i+1
                        
                        # Get all Period tag values (e.g. Sunday-Saturday, Monday-Friday, ...)
                        while j < i:
                            for tag in instance_tags:
                                if tag['Key'].strip() == 'Period-' + str(period[j]):
                                    numPeriod = tag['Value'].strip()       
                                    print(f'Period-{period[j]}: {numPeriod}')
                                    day = numPeriod.split('-')
                                    # print(f'Days: {day}')
                
                            # Add instance in array to stop
                            for tag in instance_tags:
                                if tag['Key'].strip() == 'ScheduleStop-' + str(period[j]):
    
                                    # Checks if the period has a range of days
                                    if len(day) > 1:
    
                                        # Check if the current day is within the period
                                            if DAYS.index(current_day) in range(DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                                print(f'{current_day} is on Stop Period-{period[j]}')
                                                
                                                if tag['Value'].strip() == current_time_local:
                                                    print(f'{instance_id} is on the Stop time')
                                                    stopInstances.append(instance_id)
                                                    
                                            else:
                                                print(f'{current_day} is not on Stop Period-{period[j]}')
                                    else:
    
                                        # Checks if the period has a sigle day
                                        if current_day == day[0]:
                                            print(f'{current_day} is on Stop Period-{period[j]}')
                                            if tag['Value'].strip() == current_time_local:
                                                print(f'{instance_id} is on the Stop time')
                                                stopInstances.append(instance_id)
                    
                            # Add instance in array to start
                            for tag in instance_tags:
                                if tag['Key'].strip() == 'ScheduleStart-' + str(period[j]):
    
                                    # Checks if the period has a range of days  
                                    if len(day) > 1:
    
                                        # Check if the current day is within the period  
                                        if DAYS.index(current_day) in range(DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                            print(f'{current_day} is on Start Period-{period[j]}')
                                            
                                            if tag['Value'].strip() == current_time_local:
                                                print(f'{instance_id} is on the Start time')
                                                startInstances.append(instance_id)
                                                    
                                        else:
                                            print(f'{current_day} is not on Start Period-{period[j]}')
                                    else:
    
                                        # Checks if the period has a sigle day
                                        if current_day == day[0]:
                                            print(f'{current_day} is on Start Period-{period[j]}')
                                            if tag['Value'].strip() == current_time_local:
                                                print(f'{instance_id} is on the Start time')
                                                startInstances.append(instance_id)
                            j = j+1
            
        # shut down all instances tagged to stop. 
        if len(stopInstances) > 0:
            print(f'----------------------------------------')
            try:
                # perform the shutdown
                stop = ec2.stop_instances(InstanceIds=stopInstances)
                print(stop)
            except Exception as e:
                print(f'[Cannot start instance!] {e}')
            
            if ALARMS_MANAGER:
                for inst in stopInstances:
                    manage_alarms(inst, 'disable', cloudwatch)
        else:
            print(f'----------------------------------------')
            print(f'No instances to shutdown in {region}.')
            
        # start instances tagged to start. 
        if len(startInstances) > 0:
            print(f'----------------------------------------')
            try:
                # perform the start
                start = ec2.start_instances(InstanceIds=startInstances)
                print(start)
 
            except Exception as e:
                print(f'[Cannot start instance!] {e}')

            if ALARMS_MANAGER:
                for inst in startInstances:
                    manage_alarms(inst, 'enable', cloudwatch)
        else:
            print(f'----------------------------------------')
            print(f'No instances to start in {region}.')
    
    print(f'----------------------------------------')
    
    return 'Success!'