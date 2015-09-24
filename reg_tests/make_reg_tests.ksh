#!/bin/ksh --login

#-----------------------------------------------------------------------------
# This script compiles all regression tests.
# 
# PLEASE READ THE "README" FILE IN THIS DIRECTORY FOR DETAILS ON HOW
# TO RUN THIS SCRIPT.
#-----------------------------------------------------------------------------

set -x

#-----------------------------------------------------------------------------
# Read in compiler, compiler flags and link flags.
#-----------------------------------------------------------------------------

. ./config-setup/ifort.setup

#-----------------------------------------------------------------------------
# These regression tests depend on the NCEP BACIO, SP, W3NCO and G2 libraries.
# The path/name of these libraries are set thru environment variables.
# On Theia and WCOSS, these are set via modules.  On other machines,
# they must be set manually.
#-----------------------------------------------------------------------------

if [[ "$(hostname -f)" == tfe?? ]]; then # Theia
  module purge
  module use -a /scratch3/NCEPDEV/nwprod/lib/modulefiles
  module load intel
  module load bacio
  module load sp
  module load w3nco
  module load jasper
  module load z
  module load png
  module load g2
  G2_LIB8=/scratch4/NCEPDEV/da/noscrub/George.Gayno/g2_v2.5.0/libg2_v2.5.0_8.a
  G2_INC8=/scratch4/NCEPDEV/da/noscrub/George.Gayno/g2_v2.5.0/incmod/g2_v2.5.0_8
elif [[ "$(hostname -d)" == "ncep.noaa.gov" ]]; then  #WCOSS
  module purge
  module load ics
  module load bacio
  module load sp
  module load w3nco
  module load g2
  G2_LIB8=/global/noscrub/George.Gayno/g2_lib/v2.5.0/libg2_v2.5.0_8.a
  G2_INC8=/global/noscrub/George.Gayno/g2_lib/v2.5.0/incmod/g2_v2.5.0_8
  module load jasper
  module load png
  module load z
fi 

#-----------------------------------------------------------------------------
# Stop scripts if library environment variables are undefined.
#-----------------------------------------------------------------------------

BACIO_LIB4=${BACIO_LIB4:?}  # Single precision libraries
SP_LIB4=${SP_LIB4:?}
W3NCO_LIB4=${W3NCO_LIB4:?}
G2_LIB4=${G2_LIB4:?}
G2_INC4=${G2_INC4:?}

BACIO_LIB8=${BACIO_LIB8:?}  # Double precision libraries
SP_LIB8=${SP_LIB8:?}
W3NCO_LIB8=${W3NCO_LIB8:?}
G2_LIB8=${G2_LIB8:?}
G2_INC8=${G2_INC8:?}

SP_LIBd=${SP_LIBd:?}        # Mixed precision libraries
W3NCO_LIBd=${W3NCO_LIBd:?}
G2_LIBd=${G2_LIBd:?}
G2_INCd=${G2_INCd:?}

JASPER_LIB=${JASPER_LIB:?}
PNG_LIB=${PNG_LIB:?}
Z_LIB=${Z_LIB:?}

MAKE="gmake"

#-----------------------------------------------------------------------------
# Make regression test executables for all three precision versions of
# the 'control' and 'test IPLIB.
#-----------------------------------------------------------------------------

for WHICHIP in ctl test; do  # the 'control' or 'test' IPLIB

  for PRECISION in 4 8 d; do  # single ("4"), double ("8") or mixed ("d") precison IPLIB

    case $PRECISION in
      4) SP_LIB=$SP_LIB4
         BACIO_LIB=$BACIO_LIB4
         G2_LIB=$G2_LIB4
         G2_INC=$G2_INC4
         W3NCO_LIB=$W3NCO_LIB4 ;;
      8) SP_LIB=$SP_LIB8
         BACIO_LIB=$BACIO_LIB8
         G2_LIB=$G2_LIB8
         G2_INC=$G2_INC8
         W3NCO_LIB=$W3NCO_LIB8 ;;
      d) SP_LIB=$SP_LIBd
         BACIO_LIB=$BACIO_LIB4
         G2_LIB=$G2_LIBd
         G2_INC=$G2_INCd
         W3NCO_LIB=$W3NCO_LIBd ;;
    esac

    ./configure --prefix=${PWD} --enable-promote=${PRECISION} \
      FCFLAGS="${FCFLAGS} -I${G2_INC} -I${PWD}/lib/incmod_${WHICHIP}_${PRECISION}" \
      LIBS="${PWD}/lib/libip_${WHICHIP}_${PRECISION}.a ${G2_LIB} ${SP_LIB} \
            ${BACIO_LIB} ${W3NCO_LIB} ${JASPER_LIB} ${PNG_LIB} ${Z_LIB}"
    if [ $? -ne 0 ]; then
      set +x
      echo "$0: Error configuring for ${PRECISION}-byte ${WHICHIP} version build." >&2
      exit 2
    fi

    $MAKE clean
    $MAKE
    if [ $? -ne 0 ]; then
      set +x
      echo "$0: Error building for ${PRECISION}-byte ${WHICHIP} version build." >&2
      exit 3
    fi

    $MAKE install suffix="_${WHICHIP}_${PRECISION}"
    if [ $? -ne 0 ]; then
      set +x
      echo "$0: Error installing for ${PRECISION}-byte ${WHICHIP} version build." >&2
     exit 4
    fi

    mv config.log config_${WHICHIP}_${PRECISION}.log

  done  # library precision
done  # 'ctl' or 'test' IPLIB
