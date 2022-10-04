#!/bin/bash
set -e

HOSTED_ZONE_ID="<YOUR HOSTED ZONE ID HERE>"
NAME="<YOUR.DOMAIN.HERE>."
TYPE="A"
TTL=60

SCRIPT_DIR=$(dirname $(realpath $0))
AWS=aws

cd ${SCRIPT_DIR}

echo -n "$(date) "

#get current IP address
IP=$(curl -s http://checkip.amazonaws.com/)

#validate IP address (makes sure Route 53 doesn't get updated with a malformed payload)
if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        exit 1
fi

#get current
${AWS} route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID | \
jq -r '.ResourceRecordSets[] | select (.Name == "'"$NAME"'") | select (.Type == "'"$TYPE"'") | .ResourceRecords[0].Value' > ./current_route53_value

#check if IP is different from Route 53
if grep -Fxq "$IP" ./current_route53_value; then
        echo "IP Has Not Changed, Exiting"
        exit 1
fi


echo "IP Changed, Updating Records"

#prepare route 53 payload
cat > ./route53_changes.json << EOF
    {
      "Comment":"Updated From DDNS Shell Script",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$NAME",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

#update records
${AWS} route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file://./route53_changes.json > /dev/null

rm ./route53_changes.json
