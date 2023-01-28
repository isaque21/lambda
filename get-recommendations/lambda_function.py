import boto3
import json
import csv
import time
import logging
from unicodedata import normalize
from botocore.exceptions import ClientError

# Define AWS Region
AWS_REGION = "us-east-1"

# Define AWS Pricing Rregion (us-east-1 or ap-south-1)
AWS_PRICING_REGION = 'us-east-1'

# Define reservation type (standard or convertible)
OFFERING_CLASS = 'standard'

# Enter your bucket name, e.g 'mybucket'
BUCKET = 'ec2-princing-reports'

# KEY path, e.g.'myec2report'
KEY = 'ec2_recommendations'

# Download s3 csv file to lambda tmp folder
LOCAL_FILE = '/tmp/report_tmp.csv'

# Get AWS Resources
S3_RESOURCE = boto3.client('s3')
EC2_RESOURCE = boto3.client('ec2', region_name=AWS_REGION)
SSM_RESOURCE = boto3.client('ssm', region_name=AWS_REGION)
COMPUTE_OPTIMIZER = boto3.client('compute-optimizer', region_name=AWS_REGION)
PRICING_RESOURCE = boto3.client('pricing', region_name=AWS_PRICING_REGION)

# Get location name
response = SSM_RESOURCE.get_parameter(Name='/aws/service/global-infrastructure/regions/'+AWS_REGION+'/longName')
location = response['Parameter']['Value']
location = normalize('NFKD', location).encode('ASCII','ignore').decode('ASCII')

lists = []

############## GET THE INSTANCE PRICE TYPES #########################################
def get_price(region, typeEc2, operatingSystem, preInstalledSw):

    paginator = PRICING_RESOURCE.get_paginator('get_products')

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

    
    noUpfront1yr = 'not available'
    noUpfront3yr = 'not available'
    
    for response in response_iterator:
        
        for priceItem in response["PriceList"]:
            priceItemJson = json.loads(priceItem)

            instanceType = priceItemJson['product']['attributes']['instanceType']
            vcpu = priceItemJson['product']['attributes']['vcpu']
            memory = priceItemJson['product']['attributes']['memory']

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
                                            
    return instanceType,memory,vcpu,priceOnDemand,noUpfront1yr,partUpfront1yr,partHrsUpfront1yr,allUpfront1yr,noUpfront3yr,partUpfront3yr,partHrsUpfront3yr,allUpfront3yr

############## GET RECOMENDATIONS ####################################

def get_recommendations(arn, account, instance_id, platform):
    
    response = COMPUTE_OPTIMIZER.get_ec2_instance_recommendations(
            instanceArns=[
                arn,
            ],
            accountIds=[
                account,
            ]
        )
        
    fiding = 'not available'
    oldType = 'not available'
    oldVcpuUtilization = 'not available'
    oldMemoryUtilization = 'not available'
    futureType = 'not available'
    futureVcpuUtilization = 'not available'
    futureMemoryUtilization = 'not available'
    
        
    if response['instanceRecommendations']:
        
        fiding = response['instanceRecommendations'][0]['finding']
        oldType = response['instanceRecommendations'][0]['currentInstanceType']
        
        for oldMetric in response['instanceRecommendations'][0]['utilizationMetrics']:
            if oldMetric['name'] == 'CPU' and oldMetric['statistic'] == 'MAXIMUM':
                oldVcpuUtilization = str(round(oldMetric['value'], 2)) + ' %'
            elif oldMetric['name'] == 'Memory' and oldMetric['statistic'] == 'MAXIMUM':
                oldMemoryUtilization = str(round(oldMetric['value'], 2)) + ' %'
        
        futureType = response['instanceRecommendations'][0]['recommendationOptions'][0]['instanceType']
        
        for metric in response['instanceRecommendations'][0]['recommendationOptions'][0]['projectedUtilizationMetrics']:
            if metric['name'] == 'CPU':
                futureVcpuUtilization = str(round(metric['value'], 2)) + ' %'
            elif metric['name'] == 'MEMORY':
                futureMemoryUtilization = str(round(metric['value'], 2)) + ' %'

    recommendations = [instance_id,platform,oldType,oldMemoryUtilization,oldVcpuUtilization,fiding,futureType,futureMemoryUtilization,futureVcpuUtilization]
    
    return recommendations

############## CREATE BUCKET S3 #########################################
def send_to_bucket(localFile, listValues, keyFile):
    # Create BUCKET
    try:
        S3_RESOURCE.download_file(BUCKET, f'{keyFile}.csv', localFile)
        for values in listValues:
            # write the data into '/tmp' folder
            with open(localFile,'r') as infile:
                reader = list(csv.reader(infile))
                reader = reader[::-1] # the date is ascending order in file
                reader.insert(0,values)
            
            with open(localFile, 'w', newline='') as outfile:
                writer = csv.writer(outfile)
                for line in reversed(reader): # reverse order
                    writer.writerow(line)
    
        # get current timestamp
        ts = time.time_ns()
        
        # upload file from tmp to s3 KEY
        S3_RESOURCE.upload_file(localFile, BUCKET, f'{keyFile}_{OFFERING_CLASS}_{ts}.csv')
    except ClientError as e:
        logging.error(e)
        return False
    return True


############## handle_function #######################################

def lambda_handler(event, context):

    # Get Instances attributes
    instances = EC2_RESOURCE.describe_instances()

    for instance in instances['Reservations']:

        ec2Owner = instance['OwnerId']
        ec2Az = instance['Instances'][0]['Placement']['AvailabilityZone']
        
        ec2Name = '-'
        if 'Tags' in instance['Instances'][0]:
            for tag in instance['Instances'][0]['Tags']:
                if tag['Key'] == 'Name':
                    ec2Name = tag['Value']

        ec2Id = instance['Instances'][0]['InstanceId']      
        ec2Platform = instance['Instances'][0]['PlatformDetails']
        ec2Type = instance['Instances'][0]['InstanceType']
    
        types = EC2_RESOURCE.describe_instance_types(
            InstanceTypes=[
                ec2Type,
            ]
        )
        
        for typeEc2 in types['InstanceTypes']:
            ec2Memory = typeEc2['MemoryInfo']['SizeInMiB']
            ec2Vcpu = typeEc2['VCpuInfo']['DefaultVCpus']
        
        ec2Memory = str(round(ec2Memory/1024, 3)) + ' GiB'
            
        if 'SQL Server Standard' in ec2Platform:
            preInstalledSw = 'SQL Std'
        elif 'SQL Server Enterprise' in ec2Platform:
            preInstalledSw = 'SQL Ent'
        elif 'SQL Server Web' in ec2Platform:
            preInstalledSw = 'SQL Web'
        else:
            preInstalledSw = 'NA'

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

        # get recomendations
        ec2Arn = 'arn:aws:ec2:'+AWS_REGION+':'+instance['OwnerId']+':instance/'+instance['Instances'][0]['InstanceId']
        instanceIdFuture, platformFuture, oldType, oldMemoryUtilization, oldVcpuUtilization, fiding, typeFuture, memoryUtilizationFuture, vcpuUtilizationFuture = get_recommendations(ec2Arn, ec2Owner, ec2Id, platform)
        
        # get price for recommendations
        if typeFuture == 'not available':
            typeNew=memNew=vcpuNew=priceOnDemandNew=noUpfront1yrNew=partUpfront1yrNew=partHrsUpfront1yrNew=allUpfront1yrNew=noUpfront3yrNew=partUpfront3yrNew=partHrsUpfront3yrNew=allUpfront3yrNew='not available'
       
        else:
            typeNew, memNew, vcpuNew, priceOnDemandNew, noUpfront1yrNew, partUpfront1yrNew, partHrsUpfront1yrNew, allUpfront1yrNew, noUpfront3yrNew, partUpfront3yrNew, partHrsUpfront3yrNew, allUpfront3yrNew = get_price(location, typeFuture, platformFuture, preInstalledSw)
       
        listArrRec = [ec2Owner,ec2Az,ec2Name,instanceIdFuture,platformFuture,oldType,ec2Memory,oldMemoryUtilization,ec2Vcpu,oldVcpuUtilization,fiding,typeNew,memNew,memoryUtilizationFuture,vcpuNew,vcpuUtilizationFuture,priceOnDemandNew,noUpfront1yrNew,partUpfront1yrNew,partHrsUpfront1yrNew,allUpfront1yrNew,noUpfront3yrNew,partUpfront3yrNew,partHrsUpfront3yrNew,allUpfront3yrNew]
        lists.append(listArrRec)

    # send csv files to S3
    send_to_bucket(LOCAL_FILE, lists, KEY)
    
    return{
        'message':'success'
    }