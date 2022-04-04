#!/bin/bash

set -e

AWS_DIR=${HOME}/.aws
SCRIPT_DIR=$(dirname $(readlink -f $0))
JEKYLL_SCRIPT=${SCRIPT_DIR}/jekyll.sh
#EXTRA_OPTS="--dryrun"

[ -d $AWS_DIR ] || mkdir $AWS_DIR

SITENAME=jordanpowers.link

pushd ${SCRIPT_DIR}/${SITENAME} 
echo "Building..."
${JEKYLL_SCRIPT} build
popd

SYNC_DIR=${SCRIPT_DIR}/${SITENAME}/_site 
echo "Syncing to s3..."
docker run -it --rm \
    --mount type=bind,src=${AWS_DIR},dst=/root/.aws \
    --mount type=bind,src=${SYNC_DIR},dst=/root/sync \
    amazon/aws-cli \
    s3 sync /root/sync s3://${SITENAME} --delete ${EXTRA_OPTS}


