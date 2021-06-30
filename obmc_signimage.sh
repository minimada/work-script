#!/bin/bash

# Sign images for OpemBMC image update
# 

Usage(){
    echo `basename $0` "[image folder]"
    exit 1
}

# get key from bin folder or pwd
find_key(){
    priv_key="$(pwd)/${1}"
    if [ -f "${priv_key}" ];then
        return
    fi
    priv_key="${HOME}/bin/${1}"
    if [ -f "${priv_key}" ];then
        return
    fi
    echo "Cannot find private key ${1}!!"
    exit 1
}

sign_image(){
if [ "$1" == "MANIFEST" -o "$1" == "publickey" ];then
    key="${SYSTEM_KEY}"
else
    key="${OEM_KEY}"
fi
openssl dgst -sha256 -sign "${key}" -out "${1}.sig" "${1}"
}

# ref: meta-phosphor/classes/image_types_phosphor.bbclass
# ref: phosphor-bmc-code-mgmt/image-verify.cpp
# Note. system level verify: publickey and MANIFEST

# === const vars ===
PRIVATE_KEY=OpenBMC.priv # system level key
OEM_KEY=OpenBMC.priv


# === check env ===
if [ "$1" == "-h" -o "$1" == "--help" -o ! -d "$1" ];then
    Usage
fi

find_key ${PRIVATE_KEY}
SYSTEM_KEY="${priv_key}"
find_key ${OEM_KEY}
OEM_KEY="${priv_key}"

# === main script ===
cd $1
rm ./*.sig
images=`ls`
signature_files=""
for image in $images
do
    sign_image $image
    signature_files="${signature_files} ${image}.sig"
done

# generate image-full.sig
if [ -n "$signature_files" ]; then
	sort_signature_files=`echo "$signature_files" | tr ' ' '\n' | sort | tr '\n' ' '`
	cat $sort_signature_files > image-full
	openssl dgst -sha256 -sign ${OEM_KEY} -out image-full.sig image-full
	signature_files="${signature_files} image-full.sig"
	rm -rf image-full
fi

echo "Start tar files..."
tar -cvf ../$(basename $1).tar *
echo "Sign image finished"
