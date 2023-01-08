import boto3
import json

CW = boto3.client('cloudwatch')
INSTANCE_ID = 'i-00112233445566778'
ACTION = 'enable'

def lambda_handler(event, context):

    # List metrics through the pagination interface
    paginator = CW.get_paginator('list_metrics')
    print(f'Instance: {INSTANCE_ID}')
    
    for metrics in paginator.paginate(Dimensions=[{'Name': 'InstanceId','Value': INSTANCE_ID}]):
        for metric in metrics['Metrics']:
            # print(f'Metric: {metric}')
            
            alarms = CW.describe_alarms_for_metric(
            MetricName = metric['MetricName'],
            Namespace = metric['Namespace'],
            Dimensions = metric['Dimensions']
            )
            
            if alarms['MetricAlarms']:
                for alarm in alarms['MetricAlarms']:
                    alarmName = alarm['AlarmName']
                    
                    # print(f'Alarm: {alarmName}')
                
                    if ACTION == 'disable':
                        CW.disable_alarm_actions(AlarmNames=[alarmName])
                        print(f'Alarm {alarmName} is disabled!')
                    elif ACTION == 'enable':
                        CW.enable_alarm_actions(AlarmNames=[alarmName])
                        print(f'Alarm {alarmName} is enabled!')
    return {
        'statusCode': 200,
        'body': 'Success!'
    }
