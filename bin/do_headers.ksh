#!/bin/ksh

if [ -z "${BASE_DIR}" ]; then
	echo "Environments are not set. Run 'source bin/ENV `pwd`', to set it up."
	exit;
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
mkdir -p "${CMP_DIR}"


if [ -n "${BASE_VER}" -o \( "${BASE_VER}" == "${NEW_VER}" \) ];
then
    echo "The $BASE_VER is invalid or same /w the latest ${NEW_VER}"
fi

# All combined Frameworks
set -A FWS `ls -1 ${FWS_DIR}/ ${SRC_DIR}/ | grep -v : |  sort -u | sed -e 's@.framework@@g'`
MAIN_FW=MaterialComponents
# On bash FWS=(FWS MaterialComponents MDFTextAccessibility MotionAnimator MotionInterchange MotionTransitioning)

extract_umbrella() {
      LSRC_DIR=$1
      LFW=$2
      UMB_HDR=${LSRC_DIR}/${LFW}.framework/Headers/${LFW}-umbrella.h

       #ls -rtl $UMB_HDR
       sed -e '/import/s/^.* "\(.*\)"/\1/' \
        $UMB_HDR  | grep "^M[a-z].*\.h$" | sort -u
}

#### MAIN
for FW in ${FWS[@]} # MaterialComponents
do

    if [ ! -d "${FWS_DIR}/${FW}.framework" ]; then
        echo "${FWS_DIR}/${FW}.framework"
        echo "@@@@@ WARNING: @@@@@ Framework removed from NEW: ${FW}"
        continue
    elif [ ! -d "${SRC_DIR}/${FW}.framework" ]; then
        echo "@@@@@ WARNING: @@@@@ Framework removed form SRC: ${FW}"
        continue
    fi
    # First analyse tehbaseline
    BHDR_LIST=`extract_umbrella "${FWS_DIR}" "${FW}`
    BCNT=`echo "${BHDR_LIST}" | tee /tmp/B_TMP.out | wc -l`

    NHDR_LIST=`extract_umbrella "${SRC_DIR}" "${FW}`
    NCNT=`echo "${NHDR_LIST}" | tee /tmp/N_TMP.out | wc -l`

    NEW_FILES=`diff  /tmp/B_TMP.out /tmp/N_TMP.out | grep '>' | sed -e 's@^[<>].@@'`
    REM_FILES=`diff  /tmp/B_TMP.out /tmp/N_TMP.out | grep '<' | sed -e 's@^[<>].@@'`

    echo
    echo "#####################################"
    echo "##### Processing ${FW} "
    echo "#####################################"
    echo -e "${FW} Nr. of files: ${BVER}:$BCNT <------> ${NEW_VER}:$NCNT"
    echo
    if [ "${NEW_FILES}" != "${REM_FILES}" ]; then

        echo
        # echo -e "New Hdr : ${FW} conaint \"$BCNT\" files"
        # echo
        if [ -n "${NEW_FILES}" ]; then
            echo "$NEW_FILES" >> "${CMP_DIR}/New_Header_Files"
            echo -e "# New files added to ${FW}:\n$NEW_FILES"
            echo "-----"
            echo
        fi

        if [ -n "${REM_FILES}" ]; then
            echo "$REM_FILES" >> "${CMP_DIR}/Removed_Header_Files"
            echo -e "# Removed files from ${FW}:\n$REM_FILES"
            echo "-----"
            echo
        fi
    fi

    # scanning through the base
    BDIR="${FWS_DIR}/${FW}.framework/Headers/"
    NDIR="${SRC_DIR}/${FW}.framework/Headers/"

    mkdir -p ${CMP_DIR}/${FW}
    for F in `cat /tmp/B_TMP.out`
    do
        if   grep -w "^${F}$" "${CMP_DIR}/Removed_Header_Files" >/dev/null 2>&1
        then
            #echo "FOUND: $F"
            # skip the cksum of the removed one.
            continue
        fi

        if ! diff -u "${BDIR}/${F}" "${NDIR}/${F}" >/dev/null 2>&1
        then
            echo "# Generating diffs for ${FW}/${F}"
            diff -u "${BDIR}/${F}" "${NDIR}/${F}" > ${CMP_DIR}/${FW}/${F}.diff
        fi
        #if [ "$F" == ""]
    done
done

