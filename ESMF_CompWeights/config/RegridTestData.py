
# Input data for MBMeshCompWeights
# Read using pandas.read_csv(<FILE>, sep=":", skipinitialspace=True, comment="#")

SourceGrid:DestinationGrid:RegridMethod:Options:RelativeError:AreaError:ConservationError

# ne30np4_esmf.nc : fv1.9x2.5_050503.nc : bilinear : -p all --src_type ESMF --src_loc center : 10E-05 : 10E-04 : 10E-16


# global grids with pole options
ll2.5deg_grid.nc : T42_grid.nc      : bilinear : -p none    : 10E-04 : 10E-03 : 10E-16
T42_grid.nc      : ll2.5deg_grid.nc : bilinear : -p 4       : 10E-04 : 10E-03 : 10E-16

# global to global with file type arguments
ll1deg_grid.nc : ll2.5deg_grid.nc : bilinear : -t SCRIP         : 10E-05 : 10E-04 : 10E-16
ll1deg_grid.nc : ll2.5deg_grid.nc : conserve : --dst_type SCRIP : 10E-04 : 10E-04 : 10E-13
# 
# # destination regional
# T42_grid.nc : wr50a_090614.nc : bilinear : --dst_regional : 10E-04 : 10E-04 : 10E-16
# T42_grid.nc : wr50a_090614.nc : conserve : --dst_regional : 10E-03 : 10E-02 : 10E-14
# 
# # source regional
# wr50a_090614.nc : T42_grid.nc : bilinear : --src_regional -i : 10E-06 : 10E-05 : 10E-16
# wr50a_090614.nc : T42_grid.nc : conserve : --src_regional -i : 10E-04 : 10E-04 : 10E-14
# 
# # destination regional with destination masking
# T42_grid.nc : ar9v4_100920.nc : bilinear : --dst_regional : 10E-04 : 10E-04 : 10E-16
# T42_grid.nc : ar9v4_100920.nc : conserve : --dst_regional : 10E-03 : 10E-02 : 10E-13
# 
# # source regional with source masking
# ar9v4_100920.nc : T42_grid.nc : bilinear : --src_regional -i : 10E-07 : 10E-07 : 10E-16
# ar9v4_100920.nc : T42_grid.nc : conserve : --src_regional -i : 10E-04 : 10E-03 : 10E-14
# 
# # regional to regional with destination masking
# wr50a_090614.nc : ar9v4_100920.nc : bilinear : -r -i --64bit_offset : 10E-06 : 10E-05 : 10E-16
# wr50a_090614.nc : ar9v4_100920.nc : conserve : -r -i : 10E-04 : 10E-03 : 10E-14
# 
# # regional to regional with source masking
# ar9v4_100920.nc : wr50a_090614.nc : bilinear : -r -i --64bit_offset : 10E-07 : 10E-07 : 10E-16
# ar9v4_100920.nc : wr50a_090614.nc : conserve : -i -r : 10E-06 : 10E-04 : 10E-13
# 
# # Nearest source to destination
# wr50a_090614.nc : wr50a_090614.nc : neareststod : --src_regional --dst_regional : 10E-16 : 10E-16 : 10E-16
# T42_grid.nc : T42_grid.nc : neareststod : -i : 10E-16 : 10E-16 : 10E-16
# mpas_uniform_10242.nc     : mpas_uniform_10242.nc : neareststod : --src_type ESMF --dst_type ESMF --src_loc corner --dst_loc corner : 10E-16 : 10E-16 : 10E-15
# 
# # Nearest destination to source
# wr50a_090614.nc : wr50a_090614.nc : nearestdtos : --src_regional --dst_regional : 10E-16 : 10E-16 : 10E-16
# T42_grid.nc : T42_grid.nc : nearestdtos : -i : 10E-16 : 10E-16 : 10E-16
# mpas_uniform_10242.nc     : mpas_uniform_10242.nc : nearestdtos : --src_type ESMF --dst_type ESMF --src_loc corner --dst_loc corner : 10E-16 : 10E-16 : 10E-15
# 
# # GridSpec
# GRIDSPEC_ACCESS1.nc : SCRIP_1x1.nc : bilinear : -p none -i --src_type GRIDSPEC --src_missingvalue so : 10E-06 : 10E-05 : 10E-16
# GRIDSPEC_ACCESS1.nc : SCRIP_1x1.nc : conserve : --src_type GRIDSPEC -i --src_missingvalue so : 10E-05 : 10E-04 : 10E-13
# so_Omon_GISS-E2.nc : SCRIP_1x1.nc : bilinear : --src_type GRIDSPEC : 10E-09 : 10E-08 : 10E-16
# so_Omon_GISS-E2.nc : SCRIP_1x1.nc : conserve : --src_type GRIDSPEC : 10E-09 : 10E-07 : 10E-13
# GRIDSPEC_ACCESS1.nc : so_Omon_GISS-E2.nc : bilinear : -t GRIDSPEC --src_missingvalue so --dst_missingvalue so -i : 10E-05 : 10E-02 : 10E-16
# GRIDSPEC_ACCESS1.nc : so_Omon_GISS-E2.nc : conserve : -t GRIDSPEC --src_missingvalue so --dst_missingvalue so -i : 10E-05 : 10E-04 : 10E-13
# 
# # global to cubed sphere with pole all
# fv1.9x2.5_050503.nc : ne30np4-t2.nc : bilinear : -p all  : 10E-04 : 10E-03 : 10E-16
# # hang
# # fv1.9x2.5_050503.nc : ne30np4-t2.nc : conserve : -p none : 10E-03 : 10E-02 : 10E-13
# 
# # regional to cubed sphere, conservative with masking
# wr50a_090614.nc : ne30np4-t2.nc : bilinear : --src_regional -i : 10E-06 : 10E-05 : 10E-16
# #hang
# # ar9v4_100920.nc : ne30np4-t2.nc : conserve : --src_regional -i : 10E-04 : 10E-03 : 10E-14



# FVCOM_grid2d.nc:  unstructured grid in UGRID format
# FVCOM_grid2d_20120314.nc : scrip_regional_1140x690.nc : conserve : --src_type UGRID -r --src_meshname fvcom_mesh -i : 10E-04 : 10E-03 : 10E-15
# scrip_regional_1140x690.nc : FVCOM_grid2d_20120314.nc : conserve : --dst_type UGRID -r --dst_meshname fvcom_mesh : 10E-05 : 10E-04 : 10E-15
# FVCOM_grid2d_20130228.nc : scrip_regional_1140x690.nc : conserve : --src_type UGRID -r --src_meshname fvcom_mesh -i : 10E-04 : 10E-03 : 10E-15
## hang longer than 1 min
## scrip_regional_1140x690.nc : FVCOM_grid2d_20130228.nc : conserve : --dst_type UGRID -r --dst_meshname fvcom_mesh : 10E-05 : 10E-04 : 10E-15

# # UGRID
# FVCOM_grid2d.nc : scrip_regional_1140x690.nc : conserve : --src_type UGRID -r --src_meshname fvcom_mesh -i : 10E-04 : 10E-03 : 10E-15
# FVCOM_grid2d.nc : scrip_regional_1140x690.nc : bilinear : --src_type UGRID -r --src_meshname fvcom_mesh -i --src_loc corner : 10E-07 : 10E-06 : 10E-16
# scrip_regional_1140x690.nc : FVCOM_grid2d.nc : conserve : --dst_type UGRID -r --dst_meshname fvcom_mesh : 10E-05 : 10E-04 : 10E-15
# scrip_regional_1140x690.nc : FVCOM_grid2d.nc : bilinear : --dst_type UGRID -r --dst_meshname fvcom_mesh --dst_loc corner: 10E-08 : 10E-07 : 10E-16
# 
# # Noconservative regridding using cell center
# FVCOM_grid2d.nc : scrip_regional_1140x690.nc : bilinear : --src_type UGRID -r --src_meshname fvcom_mesh -i --src_loc center : 10E-07 : 10E-06 : 10E-16
# scrip_regional_1140x690.nc : FVCOM_grid2d.nc : bilinear : --dst_type UGRID -r --dst_meshname fvcom_mesh --dst_loc center: 10E-08 : 10E-07 : 10E-16
# # timeout mb only
# #ne30np4_esmf.nc : fv1.9x2.5_050503.nc : bilinear : -p all --src_type ESMF --src_loc center : 10E-05 : 10E-04 : 10E-16
# fv1.9x2.5_050503.nc : ne30np4_esmf.nc : bilinear : -p all --dst_type ESMF --dst_loc center : 10E-04 : 10E-03 : 10E-16
# # timeout mb only
# #ne30np4dual_esmf.nc : fv1.9x2.5_050503.nc : bilinear : -p all --src_type ESMF --src_loc corner : 10E-05 : 10E-04 : 10E-16
# fv1.9x2.5_050503.nc : ne30np4dual_esmf.nc : bilinear : -p all --dst_type ESMF --dst_loc corner : 10E-04 : 10E-03 : 10E-16

# # norm type
# # timeout mb only
# mpas_uniform_10242.nc  : ne60np4_pentagons_100408.nc : conserve : --src_type ESMF --norm_type dstarea : 10E-03 : 10E-02 : 10E-13
# # timeout mb only
# ne60np4_pentagons_100408.nc : mpas_uniform_10242.nc  : conserve : --src_type ESMF --norm_type fracarea : 10E-03 : 10E-02 : 10E-13
# # timeout mb only
# mpas_uniform_10242.nc  : T42_grid.nc : conserve : --src_type ESMF --norm_type fracarea : 10E-03 : 10E-02 : 10E-13
# # timeout mb only
# T42_grid.nc : mpas_uniform_10242.nc  : conserve : --dst_type ESMF --norm_type fracarea : 10E-03 : 10E-02 : 10E-13
