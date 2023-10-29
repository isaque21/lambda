import boto3
import csv
import io
from datetime import datetime, timedelta, timezone


# Define AWS Region
AWS_REGIONS = ['us-east-1', 'sa-east-1']

# Enter your bucket name, e.g 'my_bucket'
BUCKET = 'your_bucket_name'

# Enter your file name, e.g 'my_report'
FILE = 'my_report'

# KEY path, e.g.'myec2report'
KEY = f"{FILE}-{datetime.now().month}-{datetime.now().year}"

# Get AWS Resources
S3_RESOURCE = boto3.client('s3')

# Obtenha a data e hora atual
end_timestamp = datetime.now()

# Calcule o deslocamento de tempo para UTC-3
utc_offset = timedelta(hours=-3)

# Ajuste a data e hora atual para UTC-3
end_timestamp = end_timestamp.astimezone(timezone.utc)
start_timestamp = datetime(end_timestamp.year, end_timestamp.month, 1, tzinfo=timezone.utc)

end_time = end_timestamp.strftime("%Y-%m-%d %H:%M:%S")
start_time = start_timestamp.strftime("%Y-%m-%d %H:%M:%S")

def convert_minutes_to_hours(minutes):
    horas = round((minutes / 60), 2)
    horas_inteiras = int(horas)
    minutos_exatos = int((horas - horas_inteiras) * 60)

    return f"{horas_inteiras}:{minutos_exatos}"

    
def get_availability_time(instance_id, start_time, end_time, region):

    # Criação do cliente do CloudWatch
    cw = boto3.client('cloudwatch', region_name=region)
    
    response = cw.get_metric_statistics(
    Namespace='AWS/EC2',
    MetricName='StatusCheckFailed',
    Dimensions=[
        {
            'Name': 'InstanceId',
            'Value': instance_id
        },
    ],
    StartTime=start_time,
    EndTime=end_time,
    Period=3600,
    Statistics=[
        'Average',
    ],
    Unit='Count'
    )
    
    print(f"get_metric_statistics {response}")
    
    uptime_minutes_value = 0
    downtime_minutes_value = 0
    
    if len(response['Datapoints']) > 0:
        for datapoint in response['Datapoints']:
            if datapoint['Average'] > 0.0 and datapoint['Average'] < 1.0:
                downtime_minutes_value += datapoint['Average'] * 60
            elif datapoint['Average'] == 1.0:
                
                downtime_minutes_value += 60
            else:
                uptime_minutes_value += 60
            

    total_time = uptime_minutes_value + downtime_minutes_value

    if total_time != 0:
        percentage = (uptime_minutes_value / total_time) * 100
    else:
        percentage = 0

    if percentage != 100.0 and percentage != 0.0:
        percentageResult = round(percentage,2)
    else:
        percentageResult = round(percentage)

    
    print(f"Instance ID {instance_id} | Uptime {convert_minutes_to_hours(uptime_minutes_value)} | Downtime {convert_minutes_to_hours(downtime_minutes_value)} | Percentage: {percentageResult}% | Hours used: {convert_minutes_to_hours(total_time)}")
    
    return convert_minutes_to_hours(uptime_minutes_value),convert_minutes_to_hours(downtime_minutes_value),percentageResult,convert_minutes_to_hours(total_time)

def send_to_bucket(data):
    
    headers = ['account', 'region', 'instance_name', 'instance_id', 'plataform', 'type', 'uptime_hours', 'downtime_hours', 'percentage', 'hours_used', 'start_date', 'end_date']
    row = data

    csv_buffer = io.StringIO()
    writer = csv.writer(csv_buffer, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

    # Write headers to the CSV file
    writer.writerow(headers)

    # Write each row of data to the CSV file
    for row in data:
        writer.writerow(row)

    # Get the CSV content as bytes encoded in UTF-8
    csv_bytes = csv_buffer.getvalue().encode('utf-8')

    # Upload the CSV file to the S3 bucket with a unique key based on the timestamp and offering class
    S3_RESOURCE.put_object(Body=csv_bytes, Bucket=BUCKET, Key=f"data/{KEY}.csv")

def lambda_handler(event, context):
    
    data = []

    # Iterate over each region
    for region in AWS_REGIONS:

        # Create an EC2 client for the region
        ec2 = boto3.client('ec2', region_name=region)

        # Recupera informações de todas as instâncias
        # Get Instances attributes
        instances = ec2.describe_instances()

        # Check if there are reservations
        if len(instances['Reservations']) > 0:

            # Iterate over each reservation
            for instance in instances['Reservations']:

                ec2Owner = instance['OwnerId']
                
                # Iterate over each EC2 instance in the reservation
                for ec2_instance in instance['Instances']:
                    
                    ec2Az = ec2_instance['Placement']['AvailabilityZone']
                    
                    ec2Name = '-'
                    if 'Tags' in ec2_instance:
                        for tag in ec2_instance['Tags']:
                            if tag['Key'] == 'Name':
                                ec2Name = tag['Value']
    
                    ec2Id = ec2_instance['InstanceId']      
                    ec2Platform = ec2_instance['PlatformDetails']
                    ec2Type = ec2_instance['InstanceType']
                
                    
                    # Recupera a duração dos períodos
                    uptime_hour,downtime_hour,percentage,hours_used = get_availability_time(ec2Id, start_time, end_time, region)  # Substitua esta linha com o código que calcula a duração
                
                    # Add informations to array data
                    listArr = [ec2Owner,ec2Az,ec2Name,ec2Id,ec2Platform,ec2Type,uptime_hour,downtime_hour,percentage,hours_used,start_time,end_time]
                    data.append(listArr) 

    # send csv files to S3
    send_to_bucket(data)
    
    print("Report criado com sucesso!")
