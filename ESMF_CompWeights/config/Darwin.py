import os

RUNDIR="/Users/oehmke/MBMeshCompWeightsResults"
SRCDIR="/Users/oehmke/sandbox/esmf-extended-tests/ESMF_CompWeights/src"
CFGDIR="/Users/oehmke/sandbox/esmf-extended-tests/ESMF_CompWeights/config"
RegridTestData="RegridTestData.py"

mpirun = "mpirun"
modules = ""

esmf_env = dict(ESMF_OS = "Darwin",
                ESMF_COMPILER = "gfortran",
                ESMF_COMM = "openmpi",
                ESMF_NETCDF = "split",
                ESMF_NETCDF_INCLUDE="/usr/local/include",
                ESMF_NETCDF_LIBPATH="/usr/local/lib",
                ESMF_BOPT="O",
                ESMF_OPTLEVEL=1,
                ESMF_ABI=64,
                ESMF_BUILD_NP=4)
