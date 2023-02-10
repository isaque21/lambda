import boto3
import logging
from botocore.exceptions import ClientError
from datetime import datetime, timedelta

# enter the number of days to compare the snapshot date
DAYS = 3

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    
    volumes = ec2.describe_volumes()
    
    # get all volumes
    for vol in volumes['Volumes']:
        
        snapshotDate = []
        
        volumeId = vol['VolumeId']

        # checks if volume has snapshot routine delete tag (snapshot:false)       
        if 'Tags' in vol:
            for tags in vol['Tags']:
                if 'snapshot' in tags['Key']:
                    if 'false' in tags['Value']:
                        print(f'[WARNING] Volume-ID: {volumeId} excluded from snapshot routine.')
        try:
            # get all disk snapshots
            snapshot = ec2.describe_snapshots(
                Filters=[
                    {
                        'Name': 'volume-id',
                        'Values': [
                            volumeId,
                        ]
                    },
                ],
            )
            
            # checks if the disk has any snapshots
            if len(snapshot['Snapshots']) > 0:
                for snap in snapshot['Snapshots']:
                   
                    # get the snapshot date and add it to the array
                    snapshotDate.append(snap['StartTime'])

                # sort the array by most recent date
                lastSnapshot = sorted(snapshotDate, reverse=True)

                # checks if the last snapshot is older than DAYS
                if datetime.now()-lastSnapshot[0].replace(tzinfo=None) > timedelta(days=DAYS):
                    print(f'[ALERT] The last Snapshot of Volume-ID: {volumeId} was in {lastSnapshot[0]}.')
            else:
                print(f'[ALERT] The Volume-ID: {volumeId} does not have a Snapshot.')
        except ClientError as e:
            logging.error(e)
                
    return "success"