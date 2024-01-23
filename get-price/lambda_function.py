import boto3
import json
import csv
import io
import time
from unicodedata import normalize

# Define AWS Region
AWS_REGIONS = ['us-east-1', 'sa-east-1']

# Define AWS Pricing Rregion (us-east-1 or ap-south-1)
AWS_PRICING_REGION = 'us-east-1'

# Define reservation type (standard or convertible)
OFFERING_CLASS = 'standard'

# Enter your bucket name, e.g 'mybucket'
BUCKET = 'mybucket'

# KEY path, e.g.'myec2report'
KEY = 'myec2report'

# Get AWS Resources
S3_RESOURCE = boto3.client('s3')
SSM_RESOURCE = boto3.client('ssm')
PRICING_RESOURCE = boto3.client('pricing', region_name=AWS_PRICING_REGION)


############## GET LOCATION NAME #########################################

def get_location_name(AWS_REGION):

    # Get the name of the location for the region using AWS Systems Manager Parameter Store
    response_location = SSM_RESOURCE.get_parameter(Name='/aws/service/global-infrastructure/regions/'+AWS_REGION+'/longName')
    location_name = response_location['Parameter']['Value']
    location_name = normalize('NFKD', location_name).encode('ASCII','ignore').decode('ASCII')
    
    return location_name


############## GET INSTANCE PRICE #########################################

def get_price(region, typeEc2, operatingSystem, preInstalledSw):

    paginator = PRICING_RESOURCE.get_paginator('get_products')

    # Retrieve pricing information using pagination
    response_iterator = paginator.paginate(
        ServiceCode="AmazonEC2",
        Filters=[
            {
                'Type': 'TERM_MATCH',
                'Field': 'location',
                'Value': region
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'capacitystatus',
                'Value': 'Used'
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'tenancy',
                'Value': 'Shared'
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'instanceType',
                'Value': typeEc2
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'preInstalledSw',
                'Value': preInstalledSw
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'operatingSystem',
                'Value': operatingSystem
            },
            {
                'Type': 'TERM_MATCH',
                'Field': 'licenseModel',
                'Value': 'No License required'
            }
        ],
        PaginationConfig={
            'PageSize': 100
        }
    )

    # Initialize variables to store pricing values
    noUpfront1yr = 'not available'
    noUpfront3yr = 'not available'
    
    # Iterate over the response pages
    for response in response_iterator:
        
        # Extract price information from each price item
        for priceItem in response["PriceList"]:
            priceItemJson = json.loads(priceItem)

            # Extract pricing details for different terms (OnDemand and Reserved)
            for terms in priceItemJson['terms']:
                if terms == 'OnDemand':
                    for code in priceItemJson['terms'][terms].keys():
                        for rateCode in priceItemJson['terms'][terms][code]['priceDimensions']:
                            unit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['unit']
                            pricePerUnit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['pricePerUnit']['USD']
                            priceOnDemand = '$ ' + str(round(float(pricePerUnit)*730, 2))
                    
                elif terms == 'Reserved':
                    for code in priceItemJson['terms'][terms].keys():
                        for rateCode in priceItemJson['terms'][terms][code]['priceDimensions']:
                            offeringClass = priceItemJson['terms'][terms][code]['termAttributes']['OfferingClass']
                            purchaseOption = priceItemJson['terms'][terms][code]['termAttributes']['PurchaseOption']
                            unit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['unit']

                            # Check if the pricing details match the desired offering class
                            if offeringClass == OFFERING_CLASS:
                                if purchaseOption == 'All Upfront':
                                    if unit == 'Quantity':
                                        leaseContractLength = priceItemJson['terms'][terms][code]['termAttributes']['LeaseContractLength']
                                        pricePerUnit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['pricePerUnit']['USD']
                                           
                                        if leaseContractLength == '1yr':
                                            allUpfront1yr = '$ ' + str(round(float(pricePerUnit), 2))
                                        elif leaseContractLength == '3yr':
                                            allUpfront3yr = '$ ' + str(round(float(pricePerUnit), 2))
                                            
                                            
                                elif purchaseOption == 'No Upfront':
                                    if unit == 'Hrs':
                                        leaseContractLength = priceItemJson['terms'][terms][code]['termAttributes']['LeaseContractLength']
                                        pricePerUnit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['pricePerUnit']['USD']
                                        
                                        
                                        if leaseContractLength and leaseContractLength == '1yr':
                                            noUpfront1yr = '$ ' + str(round(float(pricePerUnit)*730, 2))
                                        
                                        if leaseContractLength and leaseContractLength == '3yr':
                                            noUpfront3yr = '$ ' + str(round(float(pricePerUnit)*730, 2))
                                            
                                elif purchaseOption == 'Partial Upfront':
                                    leaseContractLength = priceItemJson['terms'][terms][code]['termAttributes']['LeaseContractLength']
                                    pricePerUnit = priceItemJson['terms'][terms][code]['priceDimensions'][rateCode]['pricePerUnit']['USD']
                                    
                                    if unit == 'Hrs':
                                        priceHrsMonth = round(float(pricePerUnit)*730, 2)
                                        
                                        if leaseContractLength == '1yr':
                                            partHrsUpfront1yr = '$ ' + str(priceHrsMonth)
                                        elif leaseContractLength == '3yr':
                                            partHrsUpfront3yr = '$ ' + str(priceHrsMonth)
                                        
                                    elif unit == 'Quantity':
                                        priceUpfront = round(float(pricePerUnit), 2)
                                        
                                        if leaseContractLength == '1yr':
                                            partUpfront1yr = '$ ' + str(priceUpfront)
                                        elif leaseContractLength == '3yr':
                                            partUpfront3yr = '$ ' + str(priceUpfront)
                                            
    return priceOnDemand,noUpfront1yr,partUpfront1yr,partHrsUpfront1yr,allUpfront1yr,noUpfront3yr,partUpfront3yr,partHrsUpfront3yr,allUpfront3yr


############## CREATE CSV FILE IN S3 BUCKET #############################

def send_to_bucket(data):
    
    headers = ['Account', 'Region', 'Instance_Name', 'Instance_ID', 'Plataform', 'State', 'Type', 'Memory', 'vCPU', 'OnDemand_Monthly', 'No_Upfront_Monthly_1yr', 'Partial_Upfront_Initial_1yr', 'Partial_Upfront_Monthly_1yr', 'All_Upfront_1yr', 'No_Upfront_Monthly_3yr', 'Partial_Upfront_Initial_3yr', 'Partial_Upfront_Monthly_3yr', 'All_Upfront_3yr']
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

    # get current timestamp
    ts = time.time_ns()

    # Upload the CSV file to the S3 bucket with a unique key based on the timestamp and offering class
    S3_RESOURCE.put_object(Body=csv_bytes, Bucket=BUCKET, Key=f'{KEY}_{OFFERING_CLASS}_{ts}.csv')


############## handle_function #######################################

def lambda_handler(event, context):

    data = []

    # Iterate over each region
    for region in AWS_REGIONS:

        # Create an EC2 client for the region
        ec2 = boto3.client('ec2', region_name=region)

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
                    ec2State = ec2_instance['State']['Name']
                    ec2Type = ec2_instance['InstanceType']
                
                    # Describe the instance types to get additional information
                    types = ec2.describe_instance_types(
                        InstanceTypes=[
                            ec2Type,
                        ]
                    )
                    
                    # Retrieve memory and vCPU information from the instance types
                    for typeEc2 in types['InstanceTypes']:
                        ec2Memory = typeEc2['MemoryInfo']['SizeInMiB']
                        ec2Vcpu = typeEc2['VCpuInfo']['DefaultVCpus']
                        
                    # Convert memory to GiB and round it to 3 decimal places    
                    ec2Memory = str(round(ec2Memory/1024, 3)) + ' GiB'

                    # Map the pre-installed software to a simplified representation    
                    if 'SQL Server Standard' in ec2Platform:
                        preInstalledSw = 'SQL Std'
                    elif 'SQL Server Enterprise' in ec2Platform:
                        preInstalledSw = 'SQL Ent'
                    elif 'SQL Server Web' in ec2Platform:
                        preInstalledSw = 'SQL Web'
                    else:
                        preInstalledSw = 'NA'
    
                    # Map the platform to a simplified representation
                    if ec2Platform == 'Red Hat Enterprise Linux':
                        platform = 'RHEL'
                    elif ec2Platform == 'Linux/UNIX':
                        platform = 'Linux'
                    elif ec2Platform == 'SUSE Linux':
                        platform = 'SUSE'
                    elif 'Windows' in ec2Platform:
                        platform = 'Windows'
                    else:
                        platform = ec2Platform
                    
                    # Get region location name
                    location = get_location_name(region)

                    # Get price for current instance type
                    priceOnDemand, noUpfront1yr, partUpfront1yr, partHrsUpfront1yr, allUpfront1yr, noUpfront3yr, partUpfront3yr, partHrsUpfront3yr, allUpfront3yr = get_price(location, ec2Type, platform, preInstalledSw)

                    # Add informations to array data
                    listArr = [ec2Owner,ec2Az,ec2Name,ec2Id,ec2Platform,ec2State,ec2Type,ec2Memory,ec2Vcpu,priceOnDemand,noUpfront1yr,partUpfront1yr,partHrsUpfront1yr,allUpfront1yr,noUpfront3yr,partUpfront3yr,partHrsUpfront3yr,allUpfront3yr]
                    data.append(listArr) 

    # send csv files to S3
    send_to_bucket(data)
    
    return{
        'message':'success'
    }