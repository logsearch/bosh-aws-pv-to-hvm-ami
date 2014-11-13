#!/bin/bash

# args: pv-ami-id stemcell-template-url stemcell-upload-s3-bucket stemcell-upload-s3-key

set -e

if [[ "" == "$4" ]]; then
    echo "Missing arguments - 4 expected"
    echo "$0 pv-ami-id stemcell-template-url stemcell-upload-s3-bucket stemcell-upload-s3-key"

    exit 1
fi



PV_AMI_ID="$1"
echo "==> PV_AMI_ID=$PV_AMI_ID"

STEMCELL_URL="$2"
echo "==> STEMCELL_URL=$STEMCELL_URL"

RESULT_S3_BUCKET="$3"
echo "==> RESULT_S3_KEY=$RESULT_S3_BUCKET"

RESULT_S3_KEY="$4"
echo "==> RESULT_S3_KEY=$RESULT_S3_KEY"

HVM_AMI_ID="ami-4b18e33c"
echo "==> HVM_AMI_ID=$HVM_AMI_ID"



echo "--> starting pv instance with $PV_AMI_ID..."

R1=$( aws ec2 run-instances --image-id "$PV_AMI_ID" --key-name "$AWS_KEYPAIR_NAME" --security-groups "default" --instance-type "m3.medium" )

PV_INSTANCE_ID=$( echo "$R1" | jq -r '.Instances[0].InstanceId' )
echo "==> PV_INSTANCE_ID=$PV_INSTANCE_ID"

PV_INSTANCE_AVAILABILITYZONE=$( echo "$R1" | jq -r '.Instances[0].Placement.AvailabilityZone' )
echo "==> PV_INSTANCE_AVAILABILITYZONE=$PV_INSTANCE_AVAILABILITYZONE"



echo "--> starting hvm instance with $HVM_AMI_ID..."

R2=$( aws ec2 run-instances --image-id "$HVM_AMI_ID" --key-name "$AWS_KEYPAIR_NAME" --security-groups "default" --instance-type "m3.medium" --placement AvailabilityZone=$PV_INSTANCE_AVAILABILITYZONE )

HVM_INSTANCE_ID=$( echo "$R2" | jq -r '.Instances[0].InstanceId' )
echo "==> HVM_INSTANCE_ID=$HVM_INSTANCE_ID"



PV_INSTANCE_STATE=null
PV_VOLUME_ID=null
PV_INSTANCE_DEVICE_NAME=null

until [[ "running" == "$PV_INSTANCE_STATE" ]]; do
    echo "--> waiting for pv $PV_INSTANCE_ID to be running"

    sleep 5

    R3=$( aws ec2 describe-instances --instance-ids "$PV_INSTANCE_ID" )
    PV_INSTANCE_STATE=$( echo "$R3" | jq -r '.Reservations[0].Instances[0].State.Name' )
    PV_VOLUME_ID=$( echo "$R3" | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' )
    PV_INSTANCE_DEVICE_NAME=$( echo "$R3" | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[0].DeviceName' )
done

echo "==> PV_VOLUME_ID=$PV_VOLUME_ID"
echo "==> PV_INSTANCE_DEVICE_NAME=$PV_INSTANCE_DEVICE_NAME"



echo "--> stopping pv $PV_INSTANCE_ID..."

R4=$( aws ec2 stop-instances --instance-ids "$PV_INSTANCE_ID" )

until [[ "stopped" == "$PV_INSTANCE_STATE" ]]; do
    echo "--> waiting for pv $PV_INSTANCE_ID to be stopped"

    sleep 5

    R5=$( aws ec2 describe-instances --instance-ids "$PV_INSTANCE_ID" )
    PV_INSTANCE_STATE=$( echo "$R5" | jq -r '.Reservations[0].Instances[0].State.Name' )
done



HVM_INSTANCE_STATE=null
HVM_VOLUME_ID=null
HVM_INSTANCE_DEVICE_NAME=null

until [[ "running" == "$HVM_INSTANCE_STATE" ]]; do
    echo "--> waiting for hvm $HVM_INSTANCE_ID to be running"

    sleep 5

    R6=$( aws ec2 describe-instances --instance-ids "$HVM_INSTANCE_ID" )
    HVM_INSTANCE_STATE=$( echo "$R6" | jq -r '.Reservations[0].Instances[0].State.Name' )
    HVM_VOLUME_ID=$( echo "$R6" | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' )
    HVM_INSTANCE_DEVICE_NAME=$( echo "$R6" | jq -r '.Reservations[0].Instances[0].BlockDeviceMappings[0].DeviceName' )
done

echo "==> HVM_VOLUME_ID=$HVM_VOLUME_ID"
echo "==> HVM_INSTANCE_DEVICE_NAME=$HVM_INSTANCE_DEVICE_NAME"



echo "--> stopping hvm $HVM_INSTANCE_ID..."

R7=$( aws ec2 stop-instances --instance-ids "$HVM_INSTANCE_ID" )

until [[ "stopped" == "$HVM_INSTANCE_STATE" ]]; do
    echo "--> waiting for hvm $HVM_INSTANCE_ID to be stopped"

    sleep 5

    R8=$( aws ec2 describe-instances --instance-ids "$HVM_INSTANCE_ID" )
    HVM_INSTANCE_STATE=$( echo "$R8" | jq -r '.Reservations[0].Instances[0].State.Name' )
done



echo "--> detaching $PV_VOLUME_ID from pv $PV_INSTANCE_ID..."

R9=$( aws ec2 detach-volume --volume-id "$PV_VOLUME_ID" )

until [[ "available" == "$PV_VOLUME_STATE" ]]; do
    echo "--> waiting for $PV_VOLUME_ID to be available"

    sleep 5

    R10=$( aws ec2 describe-volumes --volume-ids "$PV_VOLUME_ID" )
    PV_VOLUME_STATE=$( echo "$R10" | jq -r '.Volumes[0].State' )
done



echo "--> detaching $HVM_VOLUME_ID from hvm $HVM_INSTANCE_ID..."

R11=$( aws ec2 detach-volume --volume-id "$HVM_VOLUME_ID" )

until [[ "available" == "$HVM_VOLUME_STATE" ]]; do
    echo "--> waiting for $HVM_VOLUME_ID to be available"

    sleep 5

    R12=$( aws ec2 describe-volumes --volume-ids "$HVM_VOLUME_ID" )
    HVM_VOLUME_STATE=$( echo "$R12" | jq -r '.Volumes[0].State' )
done



echo "--> attaching $PV_VOLUME_ID to hvm $HVM_INSTANCE_ID..."

R13=$( aws ec2 attach-volume --volume-id "$PV_VOLUME_ID" --instance-id "$HVM_INSTANCE_ID" --device "$HVM_INSTANCE_DEVICE_NAME" )

until [[ "in-use" == "$PV_VOLUME_STATE" ]]; do
    echo "--> waiting for $PV_VOLUME_ID to be in-use"

    sleep 5

    R14=$( aws ec2 describe-volumes --volume-ids "$PV_VOLUME_ID" )
    PV_VOLUME_STATE=$( echo "$R14" | jq -r '.Volumes[0].State' )
done



echo "--> creating image from hvm $HVM_INSTANCE_ID..."

R15=$( aws ec2 create-image --instance-id "$HVM_INSTANCE_ID" --name "hvm of $PV_AMI_ID (`date -u +%Y%m%dT%H%M%SZ`)" --block-device-mappings "[{\"DeviceName\": \"/dev/sdb\",\"VirtualName\":\"ephemeral0\"}]" )

RESULT_AMI_ID=$( echo "$R15" | jq -r '.ImageId' )
echo "==> RESULT_AMI_ID=$RESULT_AMI_ID"

until [[ "available" == "$RESULT_IMAGE_STATE" ]]; do
    echo "--> waiting for $RESULT_AMI_ID to be available"

    sleep 5

    R16=$( aws ec2 describe-images --image-ids "$RESULT_AMI_ID" )
    RESULT_IMAGE_STATE=$( echo "$R16" | jq -r '.Images[0].State' )
done



echo "--> terminating pv $PV_INSTANCE_ID..."

R17=$( aws ec2 terminate-instances --instance-ids "$PV_INSTANCE_ID" )



echo "--> terminating hvm $HVM_INSTANCE_ID..."

R18=$( aws ec2 terminate-instances --instance-ids "$HVM_INSTANCE_ID" )



echo "--> deleting $PV_VOLUME_ID..."

R19=$( aws ec2 delete-volume --volume-id "$PV_VOLUME_ID" )



echo "--> deleting $HVM_VOLUME_ID..."

R19=$( aws ec2 delete-volume --volume-id "$HVM_VOLUME_ID" )



echo "--> downloading $STEMCELL_URL..."

mkdir stemcell
cd stemcell
wget -qO- "$STEMCELL_URL" | tar -xzf-



echo "--> patching stemcell..."

sed -i '' -E "s/us-east-1: .*/$AWS_DEFAULT_REGION: $RESULT_AMI_ID/" stemcell.MF
sed -i '' -E "s/name: (.*)/name: \1-hvm/" stemcell.MF
tar -czf ../stemcell.tgz *
cd ../



echo "--> uploading stemcell artifact to s3..."

RESULT_URL="https://$RESULT_S3_BUCKET.s3.amazonaws.com/$RESULT_S3_KEY"

aws s3api put-object --bucket "$RESULT_S3_BUCKET" --key "$RESULT_S3_KEY" --acl public-read --body stemcell.tgz

echo "==> RESULT_URL=$RESULT_URL"



echo "--> cleaning up stemcell patches..."

rm stemcell.tgz
rm -fr stemcell/



echo "--> uploading stemcell to bosh..."
echo "    bosh upload stemcell $RESULT_URL"
bosh upload stemcell "$RESULT_URL"