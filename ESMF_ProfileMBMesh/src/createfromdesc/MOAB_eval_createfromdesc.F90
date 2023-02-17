! Earth System Modeling Framework
! Copyright 2002-2022, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.

! #define profile_meshcreate

program MOAB_eval_create

  use ESMF
  implicit none
  logical :: correct
  integer :: localrc
  integer :: localPet, petCount
  type(ESMF_VM) :: vm
  integer :: numargs
  character(ESMF_MAXPATHLEN) :: deg_res_str
  real(ESMF_KIND_R8) :: deg_res
  integer :: num_x, num_y
  integer :: pdim, sdim
  type(ESMF_CoordSys_Flag) :: coordSys
  integer :: nodeCount
  integer, pointer :: nodeIds(:),nodeOwners(:)
  real(ESMF_KIND_R8), pointer :: nodeCoords(:)
  integer :: elemCount, elemConnCount
  integer, pointer :: elemIds(:),elemTypes(:),elemConn(:)
  real(ESMF_KIND_R8), pointer :: elemCoords(:)



   ! Init ESMF
  call ESMF_Initialize(rc=localrc, logappendflag=.false.)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Error check number of command line args
  call ESMF_UtilGetArgC(count=numargs, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  if (numargs .ne. 1) then
     write(*,*) "ERROR: MOAB_eval_create-from-desc Should be run with 1 arguments"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  ! Get deg_res string
  call ESMF_UtilGetArg(1, argvalue=deg_res_str, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Translate to integer
  read(deg_res_str,*) deg_res

  ! get pet info
  call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)


  !!!!! Generate Mesh description
  call generate_mesh_desc(deg_res, &
       pdim, sdim, coordSys, &
       nodeIds, nodeOwners, nodeCoords, &
       elemIds, elemTypes, elemConn, elemCoords, &
       num_x, num_y, &
       rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN Mesh desc SUBROUTINE!"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  ! Write out some grid info
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "NUMBER OF PROCS = ",petCount
     write(*,*) "GRID Resolution (degrees)= ",deg_res
     write(*,*) "GRID DIMS = ",num_x,num_y
     write(*,*) "GRID TOTAL SIZE = ",num_x*num_y
  endif
 
  !!!!!!!!!!!!!!! Time NativeMesh !!!!!!!!!!!!
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "Running NativeMesh ..."
  endif
  
  ! Make sure  MOAB is off
  call ESMF_MeshSetMOAB(.false., rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! Regridding using ESMF native Mesh
  call profile_mesh_create_from_desc(.false., &
       pdim, sdim, coordSys, &
       nodeIds, nodeOwners, nodeCoords, &
       elemIds, elemTypes, elemConn, elemCoords, &
       rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN PROFILE SUBROUTINE!"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  !!!!!!!!!!!!!!! Time MOAB Mesh !!!!!!!!!!!!
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "Running MBMesh ..."
  endif
  
  ! Turn on MOAB
  call ESMF_MeshSetMOAB(.true., rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! Regridding using MOAB Mesh
  call profile_mesh_create_from_desc(.true., &
       pdim, sdim, coordSys, &
       nodeIds, nodeOwners, nodeCoords, &
       elemIds, elemTypes, elemConn, elemCoords, &
       rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
      write(*,*) "ERROR IN PROFILE SUBROUTINE!"
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
   endif
   
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "Success"
  endif

  ! Get rid of memory
  deallocate(nodeIds)
  deallocate(nodeCoords)
  deallocate(nodeOwners)
  deallocate(elemIds)
  deallocate(elemTypes)
  deallocate(elemConn)
  deallocate(elemCoords)

  ! Finalize ESMF
  call ESMF_Finalize(rc=localrc)
  if (localrc /=ESMF_SUCCESS) stop

  contains

! Create description information for a mesh
! Right now does a uniform latxlon grid of res_deg (approximately) 
subroutine generate_mesh_desc(res_deg, &
     pdim, sdim, coordSys, &
     nodeIds, nodeOwners, nodeCoords, &
     elemIds, elemTypes, elemConn, elemCoords, &
     num_x, num_y, &
     rc)
 
  REAL(ESMF_KIND_R8), intent(in) :: res_deg
  integer :: pdim, sdim
  type(ESMF_CoordSys_Flag) :: coordSys
  integer :: nodeCount
  integer, pointer :: nodeIds(:),nodeOwners(:)
  real(ESMF_KIND_R8), pointer :: nodeCoords(:)
  integer :: elemCount, elemConnCount
  integer, pointer :: elemIds(:),elemTypes(:),elemConn(:)
  real(ESMF_KIND_R8), pointer :: elemCoords(:)
  integer :: num_x, num_y
  integer :: rc

  integer :: localrc
  type(ESMF_Grid) :: grid
  type(ESMF_Mesh) :: mesh
  integer :: petCount, localPet
  type(ESMF_VM) :: vm
  integer :: des_tot, des_in_x, des_in_y
  integer :: n,sqrt_des_tot


  ! get pet info
  call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc .ne. ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc .ne. ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! Calc number of DEs per side
  des_tot=petCount
  
  ! For debugging
  !write(*,*) "Des per side=",des_tot," Total des=",6*des_tot

  ! Calc number of DEs to divide sides into
  des_in_x=-1
  des_in_y=-1
  sqrt_des_tot=INT(sqrt(REAL(des_tot)))
  do n=sqrt_des_tot,1,-1
     
     ! Calc possible factors
     des_in_x=n
     des_in_y=des_tot/n

     ! If factors are correct, then leave
     if (des_in_x*des_in_y .eq. des_tot) then
        exit
     endif
  enddo

  ! Error check output
  if ((des_in_x .eq. -1) .or. (des_in_y .eq. -1)) then
     write(*,*) "ERROR: factorization failed!"
     rc=ESMF_FAILURE
     return     
  endif

  ! For debugging
 !  write(*,*) "des_tot= ",des_tot," des_in_x=",des_in_x," des_in_y=",des_in_y

  ! Calculate size of grid in each dim
  num_x=INT(360.0/res_deg)
  num_y=INT(180.0/res_deg)


  ! Create a Grid
  grid=ESMF_GridCreate1PeriDimUfrm( &
       maxIndex=(/num_x,num_y/), &
       minCornerCoord=(/0.0_ESMF_KIND_R8,-90.0_ESMF_KIND_R8/), &
       maxCornerCoord=(/360.0_ESMF_KIND_R8,90.0_ESMF_KIND_R8/), &
       regDecomp=(/des_in_x,des_in_y/), &
       staggerLocList=(/ESMF_STAGGERLOC_CENTER, ESMF_STAGGERLOC_CORNER/), &
       coordSys=ESMF_COORDSYS_SPH_DEG, &
       rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif


  ! Create a Mesh from Grid
  mesh=ESMF_MeshCreate(grid, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif

  ! Get rid of Grid
  call ESMF_GridDestroy(grid, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif

 ! Get general info about mesh
  call ESMF_MeshGet(mesh, & 
       parametricDim=pdim, spatialDim=sdim, coordSys=coordSys, &
       nodeCount=nodeCount, &
       elementCount=elemCount, elementConnCount=elemConnCount, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif

  ! Allocate space for arrays          
  allocate(nodeIds(nodeCount))
  allocate(nodeCoords(sdim*nodeCount))
  allocate(nodeOwners(nodeCount))
  allocate(elemIds(elemCount))
  allocate(elemTypes(elemCount))
  allocate(elemConn(elemConnCount))
  allocate(elemCoords(sdim*elemCount))

  ! Get Information
  call ESMF_MeshGet(mesh, &
        nodeIds=nodeIds, &
        nodeCoords=nodeCoords, &
        nodeOwners=nodeOwners, &
        elementIds=elemIds, &
        elementTypes=elemTypes, &
        elementConn=elemConn, &
        elementCoords=elemCoords, &
        rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif


  ! Get rid of Mesh
  call ESMF_MeshDestroy(mesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
     rc=ESMF_FAILURE
     return
  endif

end subroutine generate_mesh_desc


 subroutine profile_mesh_create_from_desc(moab, &
      pdim, sdim, coordSys, &
      nodeIds, nodeOwners, nodeCoords, &
      elemIds, elemTypes, elemConn, elemCoords, &
      rc)
  logical, intent(in) :: moab
  integer :: pdim, sdim
  type(ESMF_CoordSys_Flag) :: coordSys
  integer :: nodeCount
  integer, pointer :: nodeIds(:),nodeOwners(:)
  real(ESMF_KIND_R8), pointer :: nodeCoords(:)
  integer :: elemCount, elemConnCount
  integer, pointer :: elemIds(:),elemTypes(:),elemConn(:)
  real(ESMF_KIND_R8), pointer :: elemCoords(:)
  integer, intent(out) :: rc

  integer :: localrc
  character(12) :: NM
  type(ESMF_VM) :: vm
  type(ESMF_Mesh) :: srcMesh
  
  ! result code
  integer :: finalrc

    ! Init to success
  rc=ESMF_SUCCESS

  ! Don't do the test is MOAB isn't available
#ifdef ESMF_MOAB


  ! Set mesh type string
  NM = "NativeMesh"
  if (moab) then
     NM = "MBMesh"
  endif


#define profile_meshcreate
#ifdef profile_meshcreate
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_MeshCreate()")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_MeshCreate()")
#endif

  ! Create mesh
  srcMesh=ESMF_MeshCreate(parametricDim=pdim,spatialDim=sdim, &
       coordSys=coordSys, &
       nodeIds=nodeIds, nodeCoords=nodeCoords, &
       nodeOwners=nodeOwners, &
       elementIds=elemIds,&
       elementTypes=elemTypes, elementConn=elemConn, &
       elementCoords=elemCoords, &
       rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

! Write mesh for debugging
! call ESMF_MeshWrite(srcMesh, "mesh"//trim(NM))

#ifdef profile_meshcreate
  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_MeshCreate()")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_MeshCreate()")
#endif


  ! Free the meshes
  call ESMF_MeshDestroy(srcMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! Don't do the test is MOAB isn't available
#endif


end subroutine profile_mesh_create_from_desc

end program MOAB_eval_create

