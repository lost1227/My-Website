#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: ${0} Client_Name"
    exit 1
fi

PKI_DIR=~/openvpn-ca/pki
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf

if [ ! -f ${PKI_DIR}/issued/${1}.crt ]; then
    echo ${1}.crt not found, generating new certificate
    pushd ${PKI_DIR}/..

    ./easyrsa gen-req ${1} nopass
    ./easyrsa sign-req client ${1}

    popd
fi

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${PKI_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${PKI_DIR}/issued/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${PKI_DIR}/private/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${PKI_DIR}/../ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}.ovpn
