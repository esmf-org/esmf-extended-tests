!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! $Id$
!
! Earth System Modeling Framework
! Copyright (c) 2002-2022, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!!-------------------------------------------------------------------------------------

program DiffWeights
! !USES:
#ifdef ESMF_NETCDF
  use netcdf
#endif
  use ESMF

  use ESMF_FactorReadMod

  implicit none

  !--------------------------------------------------------------------------
  ! DECLARATIONS
  !--------------------------------------------------------------------------
  integer :: nPet, status, ind
  type(ESMF_VM) :: vm
  logical :: success

  real(ESMF_KIND_R8), allocatable :: factorList1(:), factorList2(:)
  integer(ESMF_KIND_I4), allocatable :: factorIndexList1(:,:), factorIndexList2(:,:)

  character(ESMF_MAXSTR) :: weightfile1, weightfile2, tol_string
  integer :: i, j
  real(ESMF_KIND_R8) :: tol


#ifdef ESMF_NETCDF
  !------------------------------------------------------------------------
  ! Initialize ESMF
  !
  call ESMF_Initialize (defaultlogfilename="DiffWeights.Log", rc=status)
  if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  !------------------------------------------------------------------------
  ! get global vm information
  !
  call ESMF_VMGetGlobal(vm, rc=status)
  if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  ! set up local pet info
  call ESMF_VMGet(vm, petCount=nPet, rc=status)
  if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  if (nPet > 1) then
    print *, "DiffWeights can only be run on a single processor"
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  !------------------------------------------------------------------------
  ! Parse keyword based arguments
  call ESMF_UtilGetArgIndex('-w1', argindex=ind)
  if (ind == -1) then
    print *, 'No weight file was specified'
  else
    call ESMF_UtilGetArg(ind+1, argvalue=weightfile1)
  endif

  call ESMF_UtilGetArgIndex('-w2', argindex=ind)
  if (ind == -1) then
    print *, 'No second weight file was specified'
  else
    call ESMF_UtilGetArg(ind+1, argvalue=weightfile2)
  endif

  call ESMF_UtilGetArgIndex('-tol', argindex=ind)
  if (ind == -1) then
    print *, 'No tolerance was specified, using 1e-14'
    tol = 10e-14
  else
    call ESMF_UtilGetArg(ind+1, argvalue=tol_string)
    tol = ESMF_UtilString2Real(tol_string, rc=status)
    if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif

  ! Read factors from weights file
  call ESMF_FactorRead(weightfile1, factorList1, factorIndexList1, rc=status)
  if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  call ESMF_FactorRead(weightfile2, factorList2, factorIndexList2, rc=status)
  if (status /= ESMF_SUCCESS) call ESMF_Finalize(endflag=ESMF_END_ABORT)

  success = .true.
  do i = 1, size(factorList1, dim=1)
    if (abs(factorList1(i) - factorList2(i)) > tol) then
      print *, "factorList(", i, ") difference greater than ", tol, "!"
      success = .false.
    endif
#if 0
    do j = 1, size(factorIndexList1, dim=2)
      if (abs(factorIndexList1(i,j) - factorIndexList2(i,j)) > tol) then
        print *, "factorIndexList(", i, ",", j, ") difference = ", &
                 abs(factorIndexList1(i,j) - factorIndexList2(i,j))
        success = .false.
      endif
    enddo
#endif
  enddo

  deallocate(factorList1, factorIndexList1)
  deallocate(factorList2, factorIndexList2)

  if (success) then
    print *, "SUCCESS"
  else
    print *, "FAIL"
  endif

  call ESMF_Finalize()

#else
  call ESMF_LogSetError(rcToCheck=ESMF_RC_LIB_NOT_PRESENT, &
    msg="- ESMF_NETCDF not defined when lib was compiled", &
    ESMF_CONTEXT, rcToReturn=rc)
  return
#endif

end program
