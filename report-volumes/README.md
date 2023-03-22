# Check volumes snapshot

This is a Lambda function that uses boto3 to retrieve information about volumes in use, check the last snapshot date of the volume, and check the free space on the volume.
We will then save the data to a CSV file and upload it to an S3 bucket for further analysis.

For each volume, she gets information such as the type of volume, whether it is encrypted, the volume creation time, the current state of the volume, the Availability Zone, and so on.

With this example, you can easily adapt the code for your own use cases and monitoring needs.


# Prerequisites

You will need an IAM role in your Lambda to allow the listing of the account's volumes and snapshots. You can see an example [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebsapi-permissions.html).

# Instructions

Define how many days it takes to issue the alert. For example:

`DAYS = 3`

`REGIONS = ['sa-east-1', 'us-east-1']`

`BUCKET_NAME = 'mybucket'`

`CSV_FILE = 'myfile.csv'`