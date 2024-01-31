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

def manage_alarms(list_alarms, cluster_name, db_identifier, action, cloudwatch):
    
    for alarms in list_alarms:
        for dimensions in alarms['Dimensions']:

            if dimensions['Name'] == db_identifier and dimensions['Value'] == cluster_name:
        
                if action == 'disable':
                    cloudwatch.disable_alarm_actions(AlarmNames=[alarms['AlarmName']])
                    print(f'Alarm {alarms['AlarmName']} is disabled!')
                elif action == 'enable':
                    cloudwatch.enable_alarm_actions(AlarmNames=[alarms['AlarmName']])
                    print(f'Alarm {alarms['AlarmName']} is enabled!')

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

        # Deacribe all RDS instances
        all_db_clusters = rds.describe_db_clusters()
        
        # Set empty lists
        alarms = []
        
        stop_alarms_instances = []
        start_alarms_instances = []
        
        stop_clusters = []   
        start_clusters = []

        all_alarms = cloudwatch.describe_alarms()
        for metric_alarms in all_alarms['MetricAlarms']:
            alarms.append(metric_alarms)

        db_clusters = all_db_clusters['DBClusters']

        # Traverses all RDS instances
        for db_cluster in db_clusters:

            print(f"Instance: {db_cluster['DBClusterIdentifier']}")

            period = []
            i = 0
            j = 0
            scheduled = 'Inactive'
            
            # Get instances tags
            tags_response = rds.list_tags_for_resource(ResourceName=db_cluster['DBClusterArn'])
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
                            print(f'Days: {day}')
        
                    # Add instance in array to stop
                    for tag in tags:
                        if tag['Key'] == 'ScheduleStop-' + str(period[j]):
                            
                            # Checks if the period has a range of days
                            if len(day) > 1:
                                
                                # Check if the current day is within the period
                                if DAYS.index(current_day) in range(DAYS.index(day[0]), DAYS.index(day[1]) + 1):
                                    print(f'{current_day} is on Stop Period-{period[j]}')
                                    
                                    if tag['Value'] == current_time_local:
                                        print(f'{db_cluster["DBClusterIdentifier"]} is on the Stop time')

                                        if db_cluster['Status'] == 'available':
                                            
                                            # Add cluster to stop list
                                            stop_clusters.append(db_cluster['DBClusterIdentifier'])
                                            
                                            # Add instances to list of alarms manager
                                            if len(db_cluster['DBClusterMembers']) > 0:
                                                for db_instance in db_cluster['DBClusterMembers']:
                                                    print(f'DB_Instance: {db_instance['DBInstanceIdentifier']}')
                                                    stop_alarms_instances.append(db_instance['DBInstanceIdentifier'])
                                        else:
                                            print(f'{db_cluster["DBClusterIdentifier"]} state is: {db_cluster["Status"]}')
                                            
                                else:
                                    print(f'{current_day} is not on Stop Period-{period[j]}')
                            else:

                                # Checks if the period has a sigle day
                                if current_day == day[0]:
                                    if tag['Value'] == current_time_local:
                                            print(f'{db_cluster["DBClusterIdentifier"]} is on the Stop time')

                                            if db_cluster['Status'] == 'available':
                                                
                                                # Add cluster to stop list
                                                stop_clusters.append(db_cluster['DBClusterIdentifier'])
                                                
                                                # Add instances to list of alarms manager
                                                if len(db_cluster['DBClusterMembers']) > 0:
                                                    for db_instance in db_cluster['DBClusterMembers']:
                                                        print(f'DB_Instance: {db_instance['DBInstanceIdentifier']}')
                                                        stop_alarms_instances.append(db_instance['DBInstanceIdentifier'])
                                            else:
                                                print(f'{db_cluster["DBClusterIdentifier"]} state is: {db_cluster["Status"]}')
                                                
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
                                        print(f'{db_cluster["DBClusterIdentifier"]} is on the Start time')

                                        if db_cluster['Status'] == 'stopped':
                                            
                                            # Add cluster to start list
                                            start_clusters.append(db_cluster['DBClusterIdentifier'])
                                            
                                            # Add instances to list of alarms manager
                                            if len(db_cluster['DBClusterMembers']) > 0:
                                                for db_instance in db_cluster['DBClusterMembers']:
                                                    print(f'DB_Instance: {db_instance['DBInstanceIdentifier']}')
                                                    start_alarms_instances.append(db_instance['DBInstanceIdentifier'])
                                        else:
                                            print(f'{db_cluster["DBClusterIdentifier"]} state is: {db_cluster["Status"]}')
                                else:        
                                    print(f'{current_day} is not on Start Period-{period[j]}')
                            else:

                                # Checks if the period has a sigle day
                                if current_day == day[0]:
                                    if tag['Value'] == current_time_local:
                                        print(f'{db_cluster["DBClusterIdentifier"]} is on the Start time')
                                        if db_cluster['Status'] == 'stopped':
                                            
                                            # Add cluster to start list
                                            start_clusters.append(db_cluster['DBClusterIdentifier'])
                                            
                                            # Add instances to list of alarms manager
                                            if len(db_cluster['DBClusterMembers']) > 0:
                                                for db_instance in db_cluster['DBClusterMembers']:
                                                    print(f'DB_Instance: {db_instance['DBInstanceIdentifier']}')
                                                    start_alarms_instances.append(db_instance['DBInstanceIdentifier'])
                                        else:
                                            print(f'{db_cluster["DBClusterIdentifier"]} state is: {db_cluster["Status"]}')
                                else:        
                                    print(f'{current_day} is not on Start Period-{period[j]}')
                    j = j+1
                
        # Stop all instances tagged to stop.
        if len(stop_clusters) > 0:
            print(f'----------------------------------------')
            for stop_cluster in stop_clusters:
                                
                if len(stop_alarms_instances) > 0:
                    for stop_alarms_instance in stop_alarms_instances:
                        manage_alarms(alarms, stop_alarms_instance, 'DBInstanceIdentifier', 'disable', cloudwatch)
                try:
                    action = rds.stop_db_cluster(DBClusterIdentifier=stop_cluster)
                    print(f'Stopping instance: {stop_cluster}')
                except Exception as e:
                    print (f'[Cannot stop cluster {stop_cluster}] {e}')

                manage_alarms(alarms, stop_cluster, 'DBClusterIdentifier', 'disable', cloudwatch)
                    
        else:
            print(f'----------------------------------------')
            print("No instances to stop.")
            
        # Start instances tagged to start. 
        if len(start_clusters) > 0:
            print(f'----------------------------------------')
            for start_cluster in start_clusters:
                                
                if len(start_alarms_instances) > 0:
                    for start_alarms_instance in start_alarms_instances:
                        manage_alarms(alarms, start_alarms_instance, 'DBInstanceIdentifier', 'enable', cloudwatch)
                try:
                    action = rds.start_db_cluster(DBClusterIdentifier=start_cluster)
                    print(f'Starting instance: {start_cluster}')
                except Exception as e:
                    print (f'[Cannot start cluster {start_cluster}] {e}')

                manage_alarms(alarms, start_cluster, 'DBClusterIdentifier', 'enable', cloudwatch)
            
        else:
            print(f'----------------------------------------')
            print("No instances to start.")

    print(f'----------------------------------------')
    
    return 'Success!'