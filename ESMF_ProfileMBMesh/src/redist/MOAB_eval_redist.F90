! Earth System Modeling Framework
! Copyright 2002-2022, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.

! #define profile_meshcreate
! #define profile_meshredist

! numNode = 16471    ! ll2deg.esmf.nc
! numNode = 66372481 ! ll0.03125deg.esmf.nc


program MOAB_eval_redist

  use ESMF
  implicit none
  logical :: correct
  integer :: localrc
  integer :: localPet, petCount
  type(ESMF_VM) :: vm
  character(ESMF_MAXPATHLEN) :: file
  integer :: numNode
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
  call ESMF_UtilGetArg(1, argvalue=file, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  if (index(trim(file), "ll2deg.esmf.nc") /= 0) then
    numNode = 16471
  elseif (index(trim(file), "ll1x2e3deg10e6node.esmf.nc") /= 0) then
    numNode = 4151521
  else
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  ! get pet info
  call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! Write out number of PETS
  if (localPet .eq. 0) then
     write(*,*)
     write(*,*) "NUMBER OF PROCS = ",petCount
     write(*,*) "GRID FILE = ",trim(file)
     write(*,*) "numNode = ", numNode
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
  call profile_mesh_redist(.false., file, numNode, rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN REDIST SUBROUTINE!"
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
  call profile_mesh_redist(.true., file, numNode, rc=localrc)
   if (localrc /=ESMF_SUCCESS) then
     write(*,*) "ERROR IN REDIST SUBROUTINE!"
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


 subroutine profile_mesh_redist(moab, file, numNode, rc)
  logical, intent(in) :: moab
  character(*), intent(in) :: file
  integer, intent(in) :: numNode
  integer, intent(out), optional :: rc

  integer :: localrc

  character(12) :: NM
  type(ESMF_VM) :: vm
  type(ESMF_Mesh) :: srcMesh, redistMesh
  type(ESMF_DistGrid) :: distgrid1, distgrid2

  integer :: i
  integer, allocatable :: asil(:)

  integer :: minI, maxI, nn

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


  nn = numNode/petCount
  
  minI = localPet*nn + 1
  maxI = (localPet+1)*nn
  if (localPet == petCount-1) maxI = numNode

  allocate(asil(maxI-minI+1))
  do i=1,maxI-minI+1
    asil(i) = minI + i - 1
  enddo

  distgrid1 = ESMF_DistGridCreate(arbSeqIndexList=asil, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! print *, localPet, "# distgrid1 minI = ", minval(asil), " maxI = ", maxval(asil)
  deallocate(asil)

  minI = (petCount - localPet - 1)*nn + 1
  maxI = (petCount - localPet)*nn
  if (localPet == 0) maxI = numNode

  allocate(asil(maxI-minI+1))
  do i=1,maxI-minI+1
    asil(i) = minI + i - 1
  enddo

  distgrid2 = ESMF_DistGridCreate(arbSeqIndexList=asil, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! print *, localPet, "# distgrid2 minI = ", minval(asil), " maxI = ", maxval(asil)
  deallocate(asil)

#ifdef profile_meshcreate
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_MeshCreate()")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_MeshCreate()")
#endif

  srcMesh=ESMF_MeshCreate(filename=file, fileformat=ESMF_FILEFORMAT_ESMFMESH, &
                          nodalDistgrid=distgrid1, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

#ifdef profile_meshcreate
  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_MeshCreate()")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_MeshCreate()")
#endif


#define profile_mesh_redist
#ifdef profile_mesh_redist
  call ESMF_TraceRegionEnter(trim(NM)//" ESMF_MeshCreate(Redist)")
  call ESMF_VMLogMemInfo("before "//trim(NM)//" ESMF_MeshCreate(Redist)")

  redistMesh = ESMF_MeshCreate(srcMesh, nodalDistgrid=distgrid2, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif


  call ESMF_VMLogMemInfo("after "//trim(NM)//" ESMF_MeshCreate(Redist)")
  call ESMF_TraceRegionExit(trim(NM)//" ESMF_MeshCreate(Redist)")
#endif


  ! Free the meshes
  call ESMF_MeshDestroy(srcMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_MeshDestroy(redistMesh, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  ! Free the distgrids
  call ESMF_DistGridDestroy(distgrid1, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

  call ESMF_DistGridDestroy(distgrid2, rc=localrc)
  if (localrc /=ESMF_SUCCESS) then
    rc=ESMF_FAILURE
    return
  endif

#endif
! ESMF_MOAB

end subroutine profile_mesh_redist

end program MOAB_eval_redist

