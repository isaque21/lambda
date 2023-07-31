import boto3
import time
from datetime import datetime, timedelta

# Define RDS client connection
rds = boto3.client('rds')

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

    current_time = datetime.now() - timedelta(hours=3)
    current_time_local = current_time.strftime("%H:%M")
    print(f'Current time: {current_time_local}')
    
    current_day = current_time.strftime("%A")
    print(f'Current day: {current_day}')
    	
    response = rds.describe_db_instances()
    db_instances = response['DBInstances']
    

    stop_instances = []   
    start_instances = []
    v_read_replica=[]

    for r_instance in db_instances:
        readReplica = r_instance['ReadReplicaDBInstanceIdentifiers']
        v_read_replica.extend(readReplica)

    for db_instance in db_instances:
        #The if condition below filters aurora clusters from single instance databases as boto3 commands defer to stop the aurora clusters.
        if db_instance['Engine'] not in ['aurora-mysql','aurora-postgresql']:
            #The if condition below filters Read replicas.
            if db_instance['DBInstanceIdentifier'] not in v_read_replica and len(db_instance['ReadReplicaDBInstanceIdentifiers']) == 0:

                print(f"Instance: {db_instance['DBInstanceIdentifier']}")

                period = []
                i = 0
                j = 0
                tags_response = rds.list_tags_for_resource(ResourceName=db_instance['DBInstanceArn'])
                
                tags = tags_response['TagList']

                for tag in tags:
                    
                    # Get Period tag value
                    if tag['Key'] == 'Scheduled':
                        scheduled = tag['Value']
                
                print(f'Scheduled: {scheduled}')
                
                if scheduled == 'Active':
                    
                    for tag in tags:
                                
                        if 'Period' in tag['Key']:
                            period.append(tag['Key'].split('-')[1])
                            i = i+1
                    
                    while j < i:
                        
                        for tag in tags:
                            
                            # Get Period tag value
                            if tag['Key'] == 'Period-' + str(period[j]):
                                numPeriod = tag['Value']       
                                print(f'Period: {numPeriod}')
                                day = numPeriod.split('-')
                                print(f'Days: {day}')
            
    
                        for tag in tags:
                            
                            # Add instance in array to stop
                            if tag['Key'] == 'ScheduleStop-' + str(period[j]):
                                
                                if len(day) > 1:
                                    # Check if the current day is within the period
                                    try:
                                        if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                            print(f'{current_day} is on Stop period-{period[j]}')
                                            
                                            if tag['Value'] == current_time_local and db_instance['DBInstanceStatus'] == 'available':
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the time')
                                                stop_instances.append(db_instance['DBInstanceIdentifier'])
                                                
                                    except ValueError:
                                        print(f'{current_day} is not on Stop period-{period[j]}')
                                else:
                                    if current_day == day[0]:
                                        if tag['Value'] == current_time_local and db_instance['DBInstanceStatus'] == 'available':
                                            print(f'{db_instance["DBInstanceIdentifier"]} is on the time')
                                            stop_instances.append(db_instance['DBInstanceIdentifier'])
                
                        for tag in tags:
                            
                            # Add instance in array to start
                            if tag['Key'] == 'ScheduleStart-' + str(period[j]):
                                    
                                if len(day) > 1:
                                    # Check if the current day is within the period
                                    try:
                                        if DAYS.index(current_day, DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                            print(f'{current_day} is on Start period-{period[j]}')
                                            
                                            if tag['Value'] == current_time_local and db_instance['DBInstanceStatus'] == 'stopped':
                                                print(f'{db_instance["DBInstanceIdentifier"]} is on the time')
                                                start_instances.append(db_instance['DBInstanceIdentifier'])
                                                
                                    except ValueError:
                                        print(f'{current_day} is not on Start period-{period[j]}')
                                else:
                                    if current_day == day[0]:
                                        if tag['Value'] == current_time_local and db_instance['DBInstanceStatus'] == 'stopped':
                                            print(f'{db_instance["DBInstanceIdentifier"]} is on the time')
                                            start_instances.append(db_instance['DBInstanceIdentifier'])
                
                        j = j+1
            
    # Stop all instances tagged to stop.
    if len(stop_instances) > 0:
        for stop_instance in stop_instances:
            response = rds.stop_db_instance(DBInstanceIdentifier=stop_instance)
            print(f'Stopping instance: {stop_instance}')
    else:
        print("No instances to stop.")
        
    # Start instances tagged to start. 
    if len(start_instances) > 0:
        for start_instance in start_instances:
            response = rds.start_db_instance(DBInstanceIdentifier=start_instance)
            print(f'Starting instance: {start_instance}')
    else:
        print("No instances to start.")
