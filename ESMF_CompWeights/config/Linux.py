import os

RUNDIR="/home/ryan/MBMeshCompWeightsResults"
SRCDIR="/home/ryan/Dropbox/sandbox/esmf-extended-tests/ESMF_CompWeights/src"
CFGDIR="/home/ryan/Dropbox/sandbox/esmf-extended-tests/ESMF_CompWeights/config"
RegridTestData="RegridTestData.py"

diff_tolerance = 1e-15

mpirun = "mpirun"
modules = ""

esmf_env = dict(ESMF_OS = "Linux",
                ESMF_COMPILER = "gfortran",
                ESMF_COMM = "openmpi",
                ESMF_NETCDF = "split",
                ESMF_NETCDF_INCLUDE="/usr/local/include",
                ESMF_NETCDF_LIBPATH="/usr/local/lib",
                ESMF_BOPT="O",
                ESMF_OPTLEVEL=2,
                ESMF_ABI=64,
                ESMF_BUILD_NP=6)
