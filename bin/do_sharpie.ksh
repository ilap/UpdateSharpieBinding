#!/bin/ksh

if [ -z "${BASE_DIR}" ]; then
	echo "Environments are not set. Run 'source bin/ENV `pwd`', to set it up."
	exit;
fi

rm -rf ${API_DIR}
mkdir -p ${API_DIR}

extract_new_headers() {
    LSRC_DIR=`dirname $1`
    LFW=`basename $1`
    UMB_HDR=${LSRC_DIR}/${LFW}

#   ls -rtl $UMB_HDR
    sed -e "/import/s#^.* \"\(.*\)\"#${LSRC_DIR}/\1#" \
    $UMB_HDR  | grep "\.h$" | sort -u
}

extract_headers() {
    #set -x
    LSRC_DIR=`dirname $1`
    LFW=`basename $1`
    UMB_HDR=${LSRC_DIR}/${LFW}

#   ls -rtl $UMB_HDR
    sed -e "/import/s#^\([+-]\).* \"\(.*\)\"#\1\2#" \
        -e "/import/s#^[^+-].* \"\(.*\)\"#\1#" \
        $UMB_HDR  | grep "\.h$" | sort -u
}

#### MAIN #####

BCOMP_HDRS=`find ${CMP_DIR} -name \*\.h.diff`
NCOMP_HDRS=`cat ${CMP_DIR}/New_Header_Files 2>/dev/null`

# Process New Header files
for HDR in ${NCOMP_HDRS}
do
    CMP=`basename ${HDR} .h`
    NEWAPIH_DIR="${APIH_DIR}/${CMP}/"
    mkdir -p $NEWAPIH_DIR

    HPATH=`find -L ${SRC_DIR} -name ${HDR}`
    cp -pr `extract_new_headers "${HPATH}"` ${NEWAPIH_DIR}
done

# Process the existing headers
for HDR in ${BCOMP_HDRS}
do
    CMP=`basename ${HDR} .h.diff`
    #DEBUG echo "HDR: $HDR"

    HDR_DIR="${APIH_DIR}/${CMP}"
    DIFF_DIR="${APID_DIR}/${CMP}"

    mkdir -p $DIFF_DIR
    mkdir -p $HDR_DIR

    HDR_LIST=`extract_headers ${HDR}`

    for NH in ${HDR_LIST}
    do
        if echo "$NH" | grep "^+" >/dev/null 2>&1; then
            echo "New header added to \"${CMP}\": $NH"
            NNH=`echo ${NH} | sed -e 's@^+@@'`
            NHD=`find -L "${SRC_DIR}" -name "${NNH}`
            BB=`basename ${NNH} .h`
            mkdir -p ${HDR_DIR}_Added
            cp ${NHD} ${HDR_DIR}_Added/${BB}.h

        elif echo "$NH" | grep "^-" >/dev/null 2>&1; then
            echo "Removed from component $CMP: $NH"
        else
            echo "${CMP} has modified: $NH"
            OHD=`find -L "${FWS_DIR}" -name "${NH}`
            NHD=`find -L "${SRC_DIR}" -name "${NH}`
            if ! diff "${OHD}" "${NHD}" >/dev/null 2>&1; then
                diff -u "${OHD}" "${NHD}" > ${DIFF_DIR}/${NH}.diff
                cp ${NHD} ${HDR_DIR}/
            fi

        fi
    done
done

for HDR in ${APIH_DIR}/*
do
    echo "#####################:" $HDR
    BN=`basename $HDR`
    NP=`echo $BN | sed -e 's@_.*@@'`

    INC=""
    for H in ${SRC_DIR}/*.framework/Headers/
    do
        INC="${INC} -I${H}" 
    done

    sharpie  -tlm-do-not-submit bind -v -p ${BN}_ -n ${NP} -o Sharpie -sdk iphoneos10.3 ${HDR}/* -c ${INC} -arch armv7
done

