import boto3
import time
import csv
import io
import logging
from botocore.exceptions import ClientError
from datetime import datetime, timedelta

REGIONS = ['sa-east-1', 'us-east-1']
SNAPSHOT_DAYS = 1
BUCKET_NAME = 'mybucket'
CSV_FILE = 'myfile.csv'


def get_free_space(instance_id, ln, region):
    
    ssm = boto3.client('ssm', region_name=region)
    
    response = ssm.describe_instance_information(InstanceInformationFilterList=[{'key': 'InstanceIds', 'valueSet': [instance_id]}])
    
    if len(response['InstanceInformationList']) > 0:
        platform_type = response['InstanceInformationList'][0]['PlatformType']
    
        if platform_type == 'Windows':
            
            command = "Get-WmiObject win32_logicaldisk | Format-Table -HideTableHeaders DeviceId,@{n='Size';e={if($_.Size -gt 1TB) {'{0}TB' -f [math]::Round($_.Size/1TB,2)} elseif($_.Size -gt 1GB) {'{0}GB' -f [math]::Round($_.Size/1GB,2)} else {'{0}MB' -f [math]::Round($_.Size/1MB,2)}}},@{n='UsedSpace';e={if(($_.Size-$_.FreeSpace) -gt 1TB) {'{0}TB' -f [math]::Round(($_.Size-$_.FreeSpace)/1TB,2)} elseif(($_.Size-$_.FreeSpace) -gt 1GB) {'{0}GB' -f [math]::Round(($_.Size-$_.FreeSpace)/1GB,2)} else {'{0}MB' -f [math]::Round(($_.Size-$_.FreeSpace)/1MB,2)}}},@{n='FreeSpace';e={if($_.FreeSpace -gt 1TB) {'{0}TB' -f [math]::Round($_.FreeSpace/1TB,2)} elseif($_.FreeSpace -gt 1GB) {'{0}GB' -f [math]::Round($_.FreeSpace/1GB,2)} else {'{0}MB' -f [math]::Round($_.FreeSpace/1MB,2)}}}"
            document_name = "AWS-RunPowerShellScript"
        
        else:
            
            command = "df -h --output='source,size,used,avail' --exclude-type=tmpfs | grep -v '^devtmpfs' | awk 'NR>1 {gsub(/M/,\"MB\",$2);gsub(/G/,\"GB\",$2);gsub(/T/,\"TB\",$2);gsub(/M/,\"MB\",$3);gsub(/G/,\"GB\",$3);gsub(/T/,\"TB\",$3);gsub(/M/,\"MB\",$4);gsub(/G/,\"GB\",$4);gsub(/T/,\"TB\",$4); print $0}'"
            document_name = "AWS-RunShellScript"
       
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName=document_name,
            Parameters={'commands': [command]},
        )
        
        command_id = response['Command']['CommandId']
        output = ''
       
        while True:
            time.sleep(2)
            result = ssm.get_command_invocation(
                CommandId=command_id,
                InstanceId=instance_id,
            )
            if result['Status'] == 'InProgress':
                continue
            elif result['Status'] == 'Success':
                output += result['StandardOutputContent']
                break
            else:
                raise Exception(f"Command {command_id} failed with status {result['Status']}")
                
        output_lines = output.strip().split("\n")
        output_list = []
        for line in output_lines:
            cols = line.split()
            output_list.append([
                cols[0], # device
                cols[1], # size 
                cols[2], # used
                cols[3]  # avail
            ])
            
        if ln >= 0 and ln < len(output_list):
            device,size,used,avail = output_list[ln]
        else:
            device = size = used = avail = 'Unmounted Volume'
        
        return device,size,used,avail
    else:
        device = size = used = avail = 'SSM Not Available'
        
        return device,size,used,avail


def get_snapshot(volume_id, region):
    snapshot_date = []

    ec2 = boto3.client('ec2', region_name=region)
    
    try:
        snapshot = ec2.describe_snapshots(
            Filters=[
                {
                    'Name': 'volume-id',
                    'Values': [
                        volume_id,
                    ]
                },
            ],
        )
        
        if len(snapshot['Snapshots']) > 0:
            for snap in snapshot['Snapshots']:
               
                snapshot_date.append(snap['StartTime'])

            last_snapshot = sorted(snapshot_date, reverse=True)
            message = ''

            last_snapshot_date = datetime.strftime(last_snapshot[0], '%Y-%m-%d %H:%M:%S')
            
            if datetime.now()-last_snapshot[0].replace(tzinfo=None) > timedelta(days=SNAPSHOT_DAYS):
                message = '[ALERT] The last Snapshot of Volume-ID: ' + volume_id + ' was in ' + last_snapshot_date +'.'
                print(f'[ALERT] The last Snapshot of Volume-ID: {volume_id} was in {last_snapshot_date}.')
            
            return last_snapshot_date, message
        else:
            last_snapshot = 'Not Available'
            message = '[ALERT] The Volume-ID: ' + volume_id + ' does not have a Snapshot.'
            print(f'[ALERT] The Volume-ID: {volume_id} does not have a Snapshot.')

            return last_snapshot, message
        
    except ClientError as e:
        logging.error(e)

def save_to_s3(data, region):
    
    s3 = boto3.client('s3', region_name=region)

    headers = ['Account ID', 'Instance ID', 'Volume ID', 'Device', 'Size', 'Used', 'Avail', 'AZ', 'Volume Type', 'Volume Iops', 'Encrypted', 'Create Time', 'State', 'Snapshot Date', 'Message']
    row = data
    
    csv_buffer = io.StringIO()
    writer = csv.writer(csv_buffer, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

    writer.writerow(headers)

    for row in data:
        writer.writerow(row)

    csv_bytes = csv_buffer.getvalue().encode('utf-8')

    s3.put_object(Body=csv_bytes, Bucket=BUCKET_NAME, Key=CSV_FILE)

def lambda_handler(event, context):
    data = []
    
    for region in REGIONS:
        
        ec2 = boto3.client('ec2', region_name=region)

        ec2_response = ec2.describe_instances()
        
        if len(ec2_response['Reservations']) > 0:
        
            for reservation in ec2_response['Reservations']:
                account_id = context.invoked_function_arn.split(':')[4]
                
                for instance in reservation['Instances']:
                    instance_id = instance['InstanceId']
                    
                    line = 0
                    
                    for volume in instance['BlockDeviceMappings']:
                        volume_id = volume['Ebs']['VolumeId']
                        volume_response = ec2.describe_volumes(VolumeIds=[volume_id])['Volumes'][0]
                        volume_type = volume_response.get('VolumeType', 'N/A')
                        volume_encrypted = volume_response.get('Encrypted', 'N/A')
                        volume_create_time = volume_response['CreateTime'].strftime('%Y-%m-%d %H:%M:%S')
                        volume_state = volume_response['State']
                        volume_availability_zone = volume_response['AvailabilityZone']
                        volume_size = str(volume_response['Size']) + 'GB'
                        volume_iops = volume_response['Iops']
        
                        device,size,used,avail = get_free_space(instance['InstanceId'], line, region)    
                        print(f'Account ID: {account_id}, Instance ID: {instance_id}, Volume ID: {volume_id}, Device: {device}, Size: {volume_size}GB, Used: {used}, Avail: {avail}, Availability Zone: {volume_availability_zone}, Volume Type: {volume_type}, Volume Iops: {volume_iops}, Encrypted: {volume_encrypted}, Create Time: {volume_create_time}, State: {volume_state}')
                               
                        line += 1
                
                        volume_snapshot_date,volume_snapshot_message = get_snapshot(volume_id, region)
                        values = [account_id, instance_id, volume_id, device, volume_size, used, avail, volume_availability_zone, volume_type, volume_iops, volume_encrypted, volume_create_time, volume_state, volume_snapshot_date, volume_snapshot_message]
                        data.append(values)        
            
   
        available_response = ec2.describe_volumes(
            Filters=[
                {
                    'Name': 'status',
                    'Values': [
                        'available'
                    ]
                },
            ]
        )
        
        for available_volumes in available_response['Volumes']:
    
            account_id = context.invoked_function_arn.split(':')[4]
            volume_id = available_volumes['VolumeId']
            volume_type = available_volumes['VolumeType']
            volume_encrypted = available_volumes['Encrypted']
            volume_create_time = available_volumes['CreateTime'].strftime('%Y-%m-%d %H:%M:%S')
            volume_state = available_volumes['State']
            volume_availability_zone = available_volumes['AvailabilityZone']
            volume_size = str(available_volumes['Size']) + 'GB'
            volume_iops = available_volumes['Iops']
            
        
            no_data = 'Not Available'
            print(f'Account ID: {account_id}, Instance ID: {no_data}, Volume ID: {volume_id}, Device: {no_data}, Size: {volume_size}GB, Used: {no_data}, Avail: {no_data}, Availability Zone: {volume_availability_zone}, Volume Type: {volume_type}, Volume Iops: {volume_iops}, Encrypted: {volume_encrypted}, Create Time: {volume_create_time}, State: {volume_state}')
            
            volume_snapshot_date,volume_snapshot_message = get_snapshot(volume_id, region)        
            values = [account_id, no_data, volume_id, no_data, volume_size, no_data, no_data, volume_availability_zone, volume_type, volume_iops, volume_encrypted, volume_create_time, volume_state, volume_snapshot_date, volume_snapshot_message]
            data.append(values)
        save_to_s3(data, region)
    
    return {
        'statusCode': 200,
    }
