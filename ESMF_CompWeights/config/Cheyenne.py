import os

RUNDIR="/glade/work/rokuingh/MBMeshCompWeightsResults"
SRCDIR="/glade/work/rokuingh/sandbox/esmf-extended-tests/ESMF_CompWeights/src"
CFGDIR="/glade/work/rokuingh/sandbox/esmf-extended-tests/ESMF_CompWeights/config"
RegridTestData="RegridTestData.py"

diff_tolerance = 1e-15

mpirun = "mpiexec_mpt"
modules = "source /etc/profile.d/modules.sh; module purge; module load ncarenv/1.3 intel/18.0.5 ncarcompilers/0.5.0 mpt/2.19 netcdf/4.7.1;"

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
