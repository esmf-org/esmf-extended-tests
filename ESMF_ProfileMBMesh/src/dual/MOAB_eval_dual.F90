! Earth System Modeling Framework
! Copyright (c) 2002-2023, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.

! #define profile_regridstore

program MOAB_eval_dual

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
     write(*,*) "DST FILE = ",trim(dstfile)
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
  call profile_mesh_dual(.false., srcfile, dstfile, rc=localrc)
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
  call profile_mesh_dual(.true., srcfile, dstfile, rc=localrc)
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


 subroutine profile_mesh_dual(moab, srcfile, dstfile, rc)
  logical, intent(in) :: moab
  character(*), intent(in) :: srcfile
  character(*), intent(in) :: dstfile
  integer, intent(out) :: rc

  integer :: localrc

  character(12) :: NM
  type(ESMF_VM) :: vm
  type(ESMF_ArraySpec) :: as
  type(ESMF_Mesh) :: srcMesh, dstMesh
  type(ESMF_Field) :: srcField, dstField
  type(ESMF_RouteHandle) :: rh

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


  srcMesh=ESMF_MeshCreate(filename=srcfile, fileformat=ESMF_FILEFORMAT_ESMFMESH, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

  dstMesh=ESMF_MeshCreate(filename=dstfile, fileformat=ESMF_FILEFORMAT_ESMFMESH, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

  call ESMF_ArraySpecSet(as, 1, ESMF_TYPEKIND_R8, rc=rc)

  srcField=ESMF_FieldCreate(srcMesh, as, meshloc=ESMF_MESHLOC_ELEMENT, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

  dstField=ESMF_FieldCreate(dstMesh, as, meshloc=ESMF_MESHLOC_ELEMENT, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

#define profile_regridstore
#ifdef profile_regridstore
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_FieldRegridStore()")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_FieldRegridStore()")
#endif

  call ESMF_FieldRegridStore(srcField, dstField=dstField, routehandle=rh, &
                             regridmethod=ESMF_REGRIDMETHOD_BILINEAR, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

#ifdef profile_regridstore
  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_FieldRegridStore()")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_FieldRegridStore()")
#endif

  call ESMF_FieldRegridRelease(rh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=localrc
    return
  endif

  call ESMF_FieldDestroy(srcField, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_FieldDestroy(dstField, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_MeshDestroy(srcMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_MeshDestroy(dstMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

#endif
! ESMF_MOAB

end subroutine profile_mesh_dual

end program MOAB_eval_dual

