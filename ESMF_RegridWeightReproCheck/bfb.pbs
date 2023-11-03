#!/bin/bash
#PBS -N bfbrun
#PBS -A P93300606
#PBS -l walltime=04:00:00
#PBS -q main
#PBS -j oe
#PBS -m abe
#PBS -M oehmke@ucar.edu
#PBS -l select=1:ncpus=4:mpiprocs=4

# Oct 2021
# This script will output a file with the BFB changes between the 
# results of ESMF_RegridWeightGenCheck between BASE_TAG and COMP_TAG
# This scrip needs to be run after bob_pre_bfb and in the same directory 
export BASE_TAG=8.5.0
export COMP_TAG=8.6.0

# Setup modules with which to build ESMF
module purge
module load ncarenv/23.06 craype/2.7.20 cmake/3.26.3
module load intel/2023.0.0 ncarcompilers/1.0.0 cray-mpich/8.1.25
module load hdf5/1.12.2 netcdf/4.9.2

# module for comparison program
module load nccmp/1.9.0.1

# Set ESMF compiler variables
export ESMF_COMPILER=intel
export ESMF_COMM=mpi
export BOPT=O
export ESMF_OPTLEVEL=2
export ESMF_NETCDF=nc-config
export ESMF_PIO=internal
export ESMF_CXXCOMPILEOPTS="-fp-model precise"
export ESMF_F90COMPILEOPTS="-fp-model precise"

# Set working directory
export BFBDIR=${PWD}

# Set up directory for base
export BASE_DIR=${BFBDIR}/${BASE_TAG}
cd ${BASE_DIR}

# Build and install base
export ESMF_DIR=${BASE_DIR}/esmf
cd ${ESMF_DIR}

make -j4 > make.out 2>&1

export ESMF_INSTALL_PREFIX=${BASE_DIR}/esmfinstall
export ESMF_INSTALL_LIBDIR=${ESMF_INSTALL_PREFIX}/lib

make install


# Set up directory for comp
export COMP_DIR=${BFBDIR}/${COMP_TAG}
cd ${COMP_DIR}

# Build and install comp
export ESMF_DIR=${COMP_DIR}/esmf
cd ${ESMF_DIR}

make -j4 > make.out 2>&1

export ESMF_INSTALL_PREFIX=${COMP_DIR}/esmfinstall
export ESMF_INSTALL_LIBDIR=${ESMF_INSTALL_PREFIX}/lib

make install


# Setup to run
export ESMF_MPIRUN=mpiexec
export ESMF_NUM_PROCS=4


# run RWG with BASE_TAG
cd ${BFBDIR}/esmf-extended-tests/ESMF_RegridWeightGenCheck
export ESMFMKFILE=${BASE_DIR}/esmfinstall/lib/esmf.mk
make clean
make run

mkdir ${BASE_DIR}/ncfiles
cp *.nc ${BASE_DIR}/ncfiles


# run RWG with COMP_TAG
cd ${BFBDIR}/esmf-extended-tests/ESMF_RegridWeightGenCheck
export ESMFMKFILE=${COMP_DIR}/esmfinstall/lib/esmf.mk
make clean
make run

mkdir ${COMP_DIR}/ncfiles
cp *.nc ${COMP_DIR}/ncfiles


# run nccmp
cd ${BFBDIR}
./bfb_comp ${BASE_DIR}/ncfiles ${COMP_DIR}/ncfiles > Derecho_intel_2023.0.0_mpi_O_from_${BASE_TAG}_to_${COMP_TAG}.txt 2>&1 
