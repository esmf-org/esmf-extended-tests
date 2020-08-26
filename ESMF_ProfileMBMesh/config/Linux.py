import os

RUNDIR="/home/ryan/MBMeshPerformanceResults"
ROOTDIR="/home/ryan/Dropbox/sandbox/profiling/ESMF_ProfileMBMesh"
SRCDIR=os.path.join(ROOTDIR, "src")
CFGDIR=os.path.join(ROOTDIR, "config")

procs=(1, 2, 4, 8)

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

testcase_args = dict(
    create = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1deg.esmf.nc"),
                  GRID2 = os.path.join(ROOTDIR,"data", "ll1deg.esmf.nc")),
    dual = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll4deg.esmf.nc"),
                GRID2 = os.path.join(ROOTDIR,"data", "ll4deg.esmf.nc")),
    GRID2mesh = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll1deg.scrip.nc"),
                     GRID2 = os.path.join(ROOTDIR,"data", "ll1deg.scrip.nc")),
    redist = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc"),
                  GRID2 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc")),
    regridbilinear = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc"),
                          GRID2 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc")),
    regridconservative = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc"),
                              GRID2 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc")),
    rendezvous = dict(GRID1 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc"),
                      GRID2 = os.path.join(ROOTDIR,"data", "ll2deg.esmf.nc"))
)
