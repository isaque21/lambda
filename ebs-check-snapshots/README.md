# Check volumes snapshot

This function allows you to check your routine snapshots of your account volumes.

If it finds any volume that does not have a snapshot or the last snapshot is older than X days, an alert will be issued in the function logs.

# Prerequisites

You will need an IAM role in your Lambda to allow the listing of the account's volumes and snapshots. You can see an example [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebsapi-permissions.html).

# Instructions

Define how many days it takes to issue the alert. For example:

`DAYS = 3`

The logs will display two types of output:

`[ALERT] The Volume-ID: vol-a1b2c3d4e5f6g7 does not have a Snapshot.`

`[ALERT] The last Snapshot of Volume-ID: vol-a1b2c3d4e5f6g7 was in 2022-09-23 01:33:04.596000+00:00.`

If you want to exclude some volume from scanning, just add the following tag `snapshot:false` to the volume and the following message will appear in the logs:

`[WARNING] Volume-ID: vol-a1b2c3d4e5f6g7 excluded from snapshot routine.`