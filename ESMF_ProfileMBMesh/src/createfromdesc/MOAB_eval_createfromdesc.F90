! Earth System Modeling Framework
! Copyright 2002-2020, University Corporation for Atmospheric Research,
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
  character(ESMF_MAXPATHLEN) :: sizeStr
  integer :: numargs,size

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

  ! Get size string
  call ESMF_UtilGetArg(1, argvalue=sizeStr, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Translate to integer
  read(sizeStr,'(i6)') size

  ! get pet info
  call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Write out number of PETS
  if (localPet .eq. 0) then
     write(*,*)
!     write(*,*) "NUMBER OF PROCS = ",petCount
!     write(*,*) "GRID SIZE = ",size
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
  call profile_mesh_create_from_desc(.false., size, rc=localrc)
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
  call profile_mesh_create_from_desc(.true., size, rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN PROFILE SUBROUTINE!"
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


 subroutine profile_mesh_create_from_desc(moab, size, rc)
  logical, intent(in) :: moab
  integer, intent(in) :: size
  integer, intent(out), optional :: rc

  integer :: localrc

  character(12) :: NM
  type(ESMF_VM) :: vm
  type(ESMF_Mesh) :: srcMesh
  integer :: des_per_side, nx, ny
  integer :: n,sqrt_des_per_side
  
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

  ! Calc number of DEs per side
  des_per_side=petCount/6
  
  ! if it's not evenly divided then have more des than pets
  if (des_per_side*6 .ne. petCount) then
     des_per_side=des_per_side+1
  endif

  ! For debugging
  !write(*,*) "Des per side=",des_per_side," Total des=",6*des_per_side

  ! Calc number of DEs to divide sides into
  nx=-1
  ny=-1
  sqrt_des_per_side=INT(sqrt(REAL(des_per_side)))
  do n=sqrt_des_per_side,1,-1
     
     ! Calc possible factors
     nx=n
     ny=des_per_side/n

     ! If factors are correct, then leave
     if (nx*ny .eq. des_per_side) then
        exit
     endif
  enddo

  ! Error check output
  if ((nx .eq. -1) .or. (ny .eq. -1)) then
     write(*,*) "ERROR: factorization failed!"
     rc=ESMF_FAILURE
     return     
  endif

  ! For debugging
  !write(*,*) "des_per_side= ",des_per_side," nx=",nx," ny=",ny

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

  ! Create cubed sphere mesh 
  srcMesh=ESMF_MeshCreateCubedSphere(tileSize=size, nx=nx, ny=ny, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif
#endif

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



end subroutine profile_mesh_create_from_desc

end program MOAB_eval_create

