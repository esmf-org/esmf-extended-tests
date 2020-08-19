import os

RUNDIR="/glade/work/rokuingh/MBMeshCompWeightsResults"
SRCDIR="/glade/work/rokuingh/sandbox/extended-tests/ESMF_CompWeights"
RegridTestData="RegridTestData.py"

esmf_env = dict(ESMF_OS = "Linux",
                ESMF_COMPILER = "intel",
                ESMF_COMM = "mpt",
                ESMF_NETCDF = "split",
                ESMF_NETCDF_INCLUDE="/glade/u/apps/ch/opt/netcdf/4.7.1/intel/18.0.5/include",
                ESMF_NETCDF_LIBPATH="/glade/u/apps/ch/opt/netcdf/4.7.1/intel/18.0.5/lib",
                ESMF_BOPT="O",
                ESMF_OPTLEVEL=2,
                ESMF_ABI=64,
                ESMF_BUILD_NP=36)
