import boto3
from datetime import datetime, timedelta

ec2 = boto3.resource('ec2')
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

def manage_alarms(instanceId, action):
    
    # List metrics through the pagination interface
    paginator = cloudwatch.get_paginator('list_metrics')
    print(f'Instance: {instanceId}')
    
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

    # Search all the instances which contains scheduled filter 
    instances = ec2.instances.filter(Filters=filters)

    stopInstances = []   
    startInstances = []
    

    # Locate all instances that are tagged to start or stop.
    for instance in instances:
        print(instance.id)
        
        period = []
        i = 0
        j = 0
        for tag in instance.tags:

            if 'Period' in tag['Key']:
                period.append(tag['Key'].split('-')[1])

                i = i+1
        
        while j < i:
            
            for tag in instance.tags:
                
                # Get Period tag value
                if tag['Key'] == 'Period-' + str(period[j]):
                    numPeriod = tag['Value']       
                    print(f'Period: {numPeriod}')
                    day = numPeriod.split('-')
                    print(f'Days: {day}')
   

            for tag in instance.tags:
                
                # Add instance in array to stop
                if tag['Key'] == 'ScheduleStop-' + str(period[j]):
                    
                    if len(day) > 1:
                        # Check if the current day is within the period
                        try:
                            if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                print(f'{current_day} is on Stop period-{period[j]}')
                                
                                if tag['Value'] == current_time_local:
                                    print(f'{instance.id} is on the time')
                                    stopInstances.append(instance.id)
                                    
                        except ValueError:
                            print(f'{current_day} is not on Stop period-{period[j]}')
                    else:
                        if current_day == day[0]:
                            if tag['Value'] == current_time_local:
                                print(f'{instance.id} is on the time')
                                stopInstances.append(instance.id)
    
            for tag in instance.tags:
                
                # Add instance in array to start
                if tag['Key'] == 'ScheduleStart-' + str(period[j]):
                        
                    if len(day) > 1:
                        # Check if the current day is within the period
                        try:
                            if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                print(f'{current_day} is on Start period-{period[j]}')
                                
                                if tag['Value'] == current_time_local:
                                    print(f'{instance.id} is on the time')
                                    startInstances.append(instance.id)
                                    
                        except ValueError:
                            print(f'{current_day} is not on Start period-{period[j]}')
                    else:
                        if current_day == day[0]:
                            if tag['Value'] == current_time_local:
                                print(f'{instance.id} is on the time')
                                startInstances.append(instance.id)
            j = j+1
            
    # shut down all instances tagged to stop. 
    if len(stopInstances) > 0:
        # perform the shutdown
        stop = ec2.instances.filter(InstanceIds=stopInstances).stop()
        print (stop)
        
        for inst in stopInstances:
            manage_alarms(inst, 'disable')
        
    else:
        print ("No instances to shutdown.")
        
    # start instances tagged to start. 
    if len(startInstances) > 0:
        # perform the start
        start = ec2.instances.filter(InstanceIds=startInstances).start()
        print (start)
        
        for inst in startInstances:
            manage_alarms(inst, 'enable')
    else:
        print ("No instances to start.")