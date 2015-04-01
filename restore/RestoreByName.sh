#!/bin/sh
#
# This script is designed to restore an EBS or EBS-group using the 
# value in the snapshots' "Name" tag:
# * If the snapshots' "Name" tags are not set, this script will fail
# * If the name-value passed to the script is not an exact-match for 
#   any snapshots' "Name" tag, this script will fail
#
# Note: this script assumes that you are attaching an EBS to an
#       existing instance, either with the intention to recover 
#       individual files or to act as a full restore of a damaged 
#       or destroyed EBS. The full restore may be made available
#       on a new instance or on the instance that originally
#       generated the EBS snapshot.
#
# Dependencies:
# - Generic: See the top-level README_dependencies.md for script dependencies
# - Specific:
#   * All snapshots - or groups of snapshots - to be restored via this
#     script must have a unique "Name" tag (at least within the scope
#     of an Amazon region). Non-unique "Name" tags will result in
#     collisions during restores
#
# License:
# - This script released under the Apache 2.0 OSS License
#
######################################################################

# Starter Variables
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/commonVars.env

# Script-specific variables
SNAPNAME="${1:-UNDEF}"
INSTANCEAZ=`curl -s http://169.254.169.254/latest/placement/availability-zone/`

# Output log-data to multiple locations
function MultiLog() {
   echo "${1}"
   logger -p local0.info -t [NamedRestore] "${1}"
}

# Make sure a searchabel Name was passed
if [ "${SNAPNAME}" = "UNDEF" ]
then
   MultiLog "No snapshot Name provided for query. Aborting"
   exit 1
fi

# Get list of snspshots matching "Name"
SNAPLIST=`aws ec2 describe-snapshots --output=text --filter  \
   "Name=description,Values=*_${THISINSTID}-bkup*" --filters  \
   "Name=tag:Created By,Values=Automated Backup" --filters  \
   "Name=tag:Name,Values=${SNAPNAME}" --query  \
   "Snapshots[].SnapshotId"`

# Query template
# aws ec2 create-volume --snapshot-id snap-c1260c83 --volume-type \
#    standard --availability-zone us-west-2b