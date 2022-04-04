#!/bin/bash

AWS_DIR=${HOME}/.aws

[ -d $AWS_DIR ] || mkdir $AWS_DIR

docker run -it --rm \
    --mount type=bind,src=${AWS_DIR},dst=/root/.aws \
    amazon/aws-cli $@
