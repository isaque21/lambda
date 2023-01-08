import boto3
import time
from datetime import datetime, timedelta

# Define EC2 resource connection
ec2 = boto3.resource('ec2')

DAYS = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
]

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
        print(instance)
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
        
    else:
        print ("No instances to shutdown.")
        
    # start instances tagged to start. 
    if len(startInstances) > 0:
        # perform the start
        start = ec2.instances.filter(InstanceIds=startInstances).start()
        print (start)
    else:
        print ("No instances to start.")