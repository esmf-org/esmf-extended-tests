! Earth System Modeling Framework
! Copyright 2002-2021, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.

! #define profile_grid2mesh
! #define profile_grid2meshcell

program MOAB_eval_g2m

  use ESMF
  implicit none
  logical :: correct
  integer :: localrc
  integer :: localPet, petCount
  type(ESMF_VM) :: vm
  character(ESMF_MAXPATHLEN) :: srcfile, dstfile
  integer :: numargs

   ! Init ESMF
  call ESMF_Initialize(rc=localrc, logappendflag=.false.)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Error check number of command line args
  call ESMF_UtilGetArgC(count=numargs, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  if (numargs .ne. 2) then
     write(*,*) "ERROR: MOAB_eval Should be run with 2 arguments"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  ! Get filenames
  call ESMF_UtilGetArg(1, argvalue=srcfile, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Get filenames
  call ESMF_UtilGetArg(2, argvalue=dstfile, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! get pet info
  call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Write out number of PETS
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "NUMBER OF PROCS = ",petCount
     write(*,*) "SRC FILE = ",trim(srcfile)
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
  call profile_mesh_g2m(.false., srcfile, rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN REGRID SUBROUTINE!"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  !!!!!!!!!!!!!!! Time MOAB Mesh !!!!!!!!!!!!
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "Running MBMesh ..."
  endif
  
  ! Turn on MOAB
  call ESMF_MeshSetMOAB(.true., rc=localrc)
  
  ! Regridding using MOAB Mesh
  call profile_mesh_g2m(.true., srcfile, rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN REGRID SUBROUTINE!"
     call ESMF_Finalize(endflag=ESMF_END_ABORT)
    endif
  
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "Success"
  endif

  ! Finalize ESMF
  call ESMF_Finalize(rc=localrc)
  if (localrc /=ESMF_SUCCESS) stop

  contains


 subroutine profile_mesh_g2m(moab, srcfile, rc)
  logical, intent(in) :: moab
  character(*), intent(in) :: srcfile
  integer, intent(out) :: rc

  integer :: localrc

  character(12) :: NM
  type(ESMF_VM) :: vm
  type(ESMF_Grid) :: srcGrid, srcGridCell
  type(ESMF_Mesh) :: dstMesh, dstMeshCell

  ! result code
  integer :: finalrc

    ! Init to success
  rc=ESMF_SUCCESS

  ! Don't do the test is MOAB isn't available
#ifdef ESMF_MOAB

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

  NM = "NativeMesh"
  if (moab) then
    NM = "MBMesh"
  endif

  srcGrid = ESMF_GridCreate(filename=srcfile, fileformat=ESMF_FILEFORMAT_SCRIP, rc=localrc)
  ! srcGridCell = ESMF_GridCreate(filename=srcfile, fileformat=ESMF_FILEFORMAT_SCRIP, addCornerStagger=.true., rc=localrc)

#define profile_grid2mesh
#ifdef profile_grid2mesh
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_Grid2Mesh()")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_Grid2Mesh()")

  dstMesh=ESMF_GridToMesh(srcGrid, staggerloc=ESMF_STAGGERLOC_CENTER, isSphere=1, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_Grid2Mesh()")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_Grid2Mesh()")
#endif

#ifdef profile_grid2meshcell
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_ESMF_Grid2MeshCell()")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_Grid2MeshCell()")

  ! dstMeshCell=ESMF_GridToMeshCell(srcGridCell, rc=localrc)
  ! if (localrc /=ESMF_SUCCESS) then
  !   rc=localrc
  !   return
  ! endif


  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_Grid2MeshCell()")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_Grid2MeshCell()")
#endif

  call ESMF_MeshDestroy(dstMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! call ESMF_MeshDestroy(dstMeshCell, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_GridDestroy(srcGrid, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! call ESMF_GridDestroy(srcGridCell, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif


#endif
! ESMF_MOAB

end subroutine profile_mesh_g2m

end program MOAB_eval_g2m

