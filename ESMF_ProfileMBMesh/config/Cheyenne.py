import os

RUNDIR="/glade/work/rokuingh/MBMeshPerformanceResults"
ROOTDIR="/glade/work/rokuingh/sandbox/profiling/ESMF_ProfileMBMesh"
SRCDIR=os.path.join(ROOTDIR, "src")
CFGDIR=os.path.join(ROOTDIR, "config")

procs=(36, 72, 144, 288, 576, 1152, 2304, 4608)

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

testcase_args = dict(
    create = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e4deg10e7node.esmf.nc"),
                  GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e4deg10e7node.esmf.nc")),
    dual = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e0deg10e4node.esmf.nc"),
                GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e0deg10e4node.esmf.nc")),
    grid2mesh = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e4deg10e7node.scrip.nc"),
                     GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e4deg10e7node.scrip.nc")),
    redist = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc"),
                  GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc")),
    regridbilinear = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc"),
                          GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc")),
    regridconservative = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc"),
                              GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc")),
    rendezvous = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc"),
                      GRID2 = os.path.join(ROOTDIR,"data", "ll1x2e3deg10e6node.esmf.nc"))
)