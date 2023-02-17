!==============================================================================
! Earth System Modeling Framework
! Copyright (c) 2002-2022, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

module Model
  use ESMF
  implicit none
  
  private
 
  public SetServices
  
  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  subroutine SetServices(model, rc)
    type(ESMF_GridComp)   :: model
    integer, intent(out)  :: rc
    
    rc = ESMF_SUCCESS
    
#if 0
    call ESMF_GridCompSetEntryPoint(model, ESMF_METHOD_INITIALIZE, &
      phase=1, userRoutine=Init1, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
#endif

  end subroutine

  !-----------------------------------------------------------------------------
  
end module
