import sys
import datetime
import boto3
import json

#Lambda expects this...
def lambda_handler(event, context):
    # Make our connections to the service
    ec2client = boto3.client('ec2')

    expire_days = int(event['ExpireDays'])
    search_key = str(event['SearchKey'])

    # Set value-match for search_key
    if str(event['SearchVal']):
        search_val = str(event['SearchVal'])
    else:
        search_val = '*'

    ## Supplementation validation of command options
    # Enforce passing of a search_key value
    if search_key == '':
        print("A tag-name must be specified for search")
        sys.exit(1)

    # Do some time-deltas
    today = datetime.date.today()
    datefilter = today - datetime.timedelta(days=expire_days)
    print('Searching for snapshots older than deletion threshold-date ['
          +
          datefilter.strftime("%Y-%m-%d")
          +
          ']... '
    )

    try:
        # Narrow the list of candidate-snapshots by tag-name
        snapshots = ec2client.describe_snapshots(
            Filters=[
                {
                    'Name': 'tag:' + search_key,
                    'Values': [
                        '*' + search_val + '*'
                    ]
                }
            ]
            )

        # Boto3 doesn't let you '<= DATE' filter: gotta iterate
        for snapshot in snapshots['Snapshots']:
            snap_created = snapshot['StartTime']
            snap_id = snapshot['SnapshotId']

            if snap_created.strftime('%Y%m%d') <= datefilter.strftime("%Y%m%d"):
                print(
                    'Snapshot %s created %s is %s days old or older: DELETING... ' %
                    (snap_id, snap_created.strftime('%Y-%m-%d'), expire_days),
                    end=''
                )

                # Try to nuke the snap...
                delstruct = ec2client.delete_snapshot(SnapshotId=snap_id)

                # Print the request-status
                if delstruct['ResponseMetadata']['HTTPStatusCode'] == 200:
                    print('Delete succeded')
                else:
                    print('Delete failed')
                sys.exit(1)

            else:
                print(
                    'Snapshot %s created %s is not %s days old or older: keeping' %
                    (snap_id, snap_created.strftime('%Y-%m-%d'), expire_days)
                )

    except:
        print('One or more tasks failed')
