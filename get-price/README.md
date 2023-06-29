# Instance Reservation Pricing Report

This script uses the AWS Pricing API to populate a CSV file with On-Demand and Reservations pricing with different payment modalities (no upfront, partially upfront, and fully upfront) for 1 and 3 years. You can also choose between standard and convertible booking types to best suit your needs.

# Instructions

You can follow the step by step in [this post](https://dev.to/isaque21/gerando-relatorio-de-precos-de-reservas-de-instancias-via-lambda-4mjn).

## AWS resource region

Choose the region where your instances are. If you have instances in more than one region, you will need to change the region and run the function again, generating a report for each region.

```
# Define AWS Regions
AWS_REGIONS = ['us-east-1', 'sa-east-1']

```

## Pricing API Endpoint Region

AWS Pricing API provides two endpoints with two different regions. Here we will use the Virginia region, but you can work with another one if you prefer.

```
# Define AWS Pricing Rregion (us-east-1 or ap-south-1)
AWS_PRICING_REGION = 'us-east-1'
```

## Type of reservations that will be used in the report

You can work with standard or convertible type of reservations. To understand the difference between the two, see [this link](https://aws.amazon.com/pt/ec2/pricing/reserved-instances/).

```
# Define reservation type (standard or convertible)
OFFERING_CLASS = 'standard'
```

## Bucket name where report CSV files will be stored

Change this option and enter the name of the bucket you created. Since the bucket is globally unique, you'll have to change it anyway.

```
# Enter your BUCKET name, e.g 'mybucket'
BUCKET = 'mybucket'
```

## Name of the empty CSV file that will be populated by the script

If you saved the template CSV file under a different name, enter it here.

```
# KEY path, e.g.'myec2report'
KEY = 'myec2report'
```

## IMPORTANT!!!

ALWAYS validate the generated report values with the [AWS Pricing Calculator](https://calculator.aws/#/) values. I cannot guarantee that there will be no divergence, although even if it is very difficult.