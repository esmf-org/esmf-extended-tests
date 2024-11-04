!==============================================================================
! Earth System Modeling Framework
! Copyright (c) 2002-2024, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

program ESMF_ReconcileStress

  ! modules
  use ESMF
  use Comp,   only: compSS       => SetServices
  
  implicit none
  
  ! local variables
  integer               :: rc, urc, unit
  integer               :: i, petCount, localPet, compCount, petListBounds(2)
  type(ESMF_GridComp), allocatable :: compList(:)  
  integer, allocatable  :: petList(:)
  character(ESMF_MAXSTR) :: configfile, label
  type(ESMF_VM)         :: vm
  type(ESMF_Config)     :: config, configComp
  type(ESMF_State)      :: state
  real(ESMF_KIND_R8)    :: begTime, endTime, totTime
  real(ESMF_KIND_R8)    :: localTime(1), maxTime(1)
  real(ESMF_KIND_R8)    :: minTimeAcrossTests
  real(ESMF_KIND_R8)    :: globalMaxTime
  real(ESMF_KIND_R8)    :: petListBoundsRel(2)
  integer               :: numArgs
  integer,parameter     :: badPet=-1
  integer,parameter     :: numTests=1
  integer :: t
  integer :: l
  
  ! start up
  call ESMF_Initialize(vm=vm, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_LogWrite("ESMF_NonNUOPCReconcile STARTING", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_VMGet(vm, petCount=petCount, localPet=localPet, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
#if 0
#ifdef ESMF_VERSION_STRING_GIT
  print *, "Version", ESMF_VERSION_STRING_GIT
#endif
#endif
  ! config
  config = ESMF_ConfigCreate(rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! Get number of args
  call ESMF_UtilGetArgC(count=numArgs, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! If a config name is provided, use that, otherwise use the old name
  if (numArgs == 1) then
     call ESMF_UtilGetArg(1, argvalue=configfile, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
  else
     if (localPet == 0) then
        write(*,*) "ERROR: Config file name must be supplied as an argument on the command line."
     endif
     if (ESMF_LogFoundError(rcToCheck=ESMF_RC_ARG_BAD, &
          msg="Application must be called with the name of the config file as the only argument on the command line.", &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
  endif
  
  ! Get the config file
  call ESMF_ConfigLoadFile(config, trim(configfile), rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! Get the number of components
  call ESMF_ConfigGetAttribute(config, label="compCount:", value=compCount, &
       rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  
  ! Create components
  allocate(compList(compCount))
  do i=1, compCount
     
     ! Get component bounds
     write(label,"('comp-',I2.2)") i
     configComp = ESMF_ConfigCreate(config, openlabel="<"//trim(label)//":", &
          closelabel=":"//trim(label)//">", rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)


     ! Get PetList from config file
     call GetCompPetList(configComp, petList, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     
     ! Debug output
     if (localPet==0) then
        write(*,*) "Comp ",i," PetListBounds=",petListBounds
     endif
     
     call ESMF_LogWrite("Creating '"//trim(label)//"' component.", &
          ESMF_LOGMSG_INFO, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     compList(i) = ESMF_GridCompCreate(name=trim(label), config=configComp, &
          petList=petList, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     
     ! Get rid of PetList
     deallocate(petList)

     ! Set services for compList
     call ESMF_GridCompSetServices(compList(i), userRoutine=compSS, userRc=urc, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo
  
    
  ! Loop doing a set of Reconcile tests to get an average
  minTimeAcrossTests=1.0E20 ! Set to large time
  do t=1,numTests
  
     ! Create State
     state = ESMF_StateCreate(name="State", rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)

     ! Loop over comps adding things to State
     do i=1, compCount
    
        ! Call initialize and add things to state
        call ESMF_GridCompInitialize(compList(i), phase=1, importState=state, &
             userRc=urc, rc=rc)
        if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
             line=__LINE__, &
             file=__FILE__)) &
             call ESMF_Finalize(endflag=ESMF_END_ABORT)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
             line=__LINE__, &
             file=__FILE__)) &
             call ESMF_Finalize(endflag=ESMF_END_ABORT)
     enddo
    
     ! Set up timing, mem measurement, etc.
     call ESMF_VMBarrier(vm, rc=rc)
     call ESMF_VMLogMemInfo(prefix="before Reconcile", rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     call ESMF_TraceRegionEnter("Reconcile", rc=rc)
     call ESMF_VMWTime(begtime, rc=rc)
     
     ! Reconcile State
     call ESMF_StateReconcile(state, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     
     ! End timing, mem measurement, etc.
     call ESMF_VMBarrier(vm, rc=rc)
     call ESMF_VMWTime(endTime, rc=rc)
     call ESMF_TraceRegionExit("Reconcile", rc=rc)
     call ESMF_VMLogMemInfo(prefix="after Reconcile", rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)

     ! Calc max time across PETs
     localTime(1)=endTime-begTime

     ! Calc Max
     call ESMF_VMReduce(vm, localTime, maxTime, 1, ESMF_REDUCE_MAX, 0, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)
     
     ! Calc globalAvgTime
     globalMaxTime=maxTime(1)
     
     ! Output time
!     if (localPet == 0) then
!        write(*,*) t," For case ",trim(configfile)," on ",petCount," procs, the reconcile time =",globalAvgTime
!     endif

     ! Find min time
     if (globalMaxTime < minTimeAcrossTests) minTimeAcrossTests=globalMaxTime

#if 0
     ! DON"T DO THIS UNTIL WE MOVE THE Comp creation into the loop
     ! Loop over comps destroying them
     do i=1, compCount
    
        ! Get rid component
        call ESMF_GridCompDestroy(compList(i), rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
             line=__LINE__, &
             file=__FILE__)) &
             call ESMF_Finalize(endflag=ESMF_END_ABORT)
     enddo
#endif
     
     ! Destroy the State
     call ESMF_StateDestroy(state, rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          call ESMF_Finalize(endflag=ESMF_END_ABORT)     
  enddo ! Over tests

  ! Output time
  if (localPet == 0) then
     write(*,*) "For case ",trim(configfile)," on ",petCount," procs, the min reconcile time =",minTimeAcrossTests
  endif
  
     ! destroy the models and connectors
  do i=1, compCount
    call ESMF_GridCompDestroy(compList(i), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo

  
  ! final wrap up
  call ESMF_LogWrite("ESMF_ReconcileNonNUOPC FINISHED", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  call ESMF_Finalize(rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
   
 !------------------------------------------------------------------------------
 contains
 !------------------------------------------------------------------------------


   
  subroutine CreatePetList(petList, petListBounds, rc)
    integer, allocatable  :: petList(:)
    integer, intent(in)   :: petListBounds(2)
    integer, intent(out)  :: rc
    
    integer :: petCount, i
    
    rc = ESMF_SUCCESS
    
    petCount = petListBounds(2) - petListBounds(1) + 1
    if (petCount<0) petCount = 0
    
    allocate(petList(petCount))
    
    do i=1, petCount
      petList(i) = petListBounds(1) + i - 1
    enddo
    
  end subroutine


  subroutine GetCompPetList(configComp, petList, rc)
    type(ESMF_Config)     :: configComp
    integer, allocatable  :: petList(:)
    integer, intent(out)  :: rc

    integer :: localrc
    real(ESMF_KIND_R8)    :: petListBoundsRel(2)
    integer,parameter     :: badPet=-1
    
     ! Try to get absolute bounds
     call ESMF_ConfigGetAttribute(configComp, label="petListBounds:", &
          valueList=petListBounds, default=badPet, rc=localrc)
     if (ESMF_LogFoundError(rcToCheck=localrc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__, rctoReturn=rc)) return
     
     ! If we didn't find the absolute bounds, use relative
     if (petListBounds(1) == badPet) then
        l=ESMF_ConfigGetLen(configComp, label="petListBoundsRel:", &
             rc=rc)
     !   write(*,*) "PL length=",l
        call ESMF_ConfigGetAttribute(configComp, label="petListBoundsRel:", &
             valueList=petListBoundsRel, rc=localrc)
        if (ESMF_LogFoundError(rcToCheck=localrc, msg=ESMF_LOGERR_PASSTHRU, &
             line=__LINE__, &
             file=__FILE__, rctoReturn=rc)) return
        
        ! Calculate absolute bounds using relative
        petListBounds(1)=INT(petListBoundsRel(1)*REAL(petCount-1))
        petListBounds(2)=INT(petListBoundsRel(2)*REAL(petCount-1))    
     endif
        
     call CreatePetList(petList, petListBounds, rc=localrc)
     if (ESMF_LogFoundError(rcToCheck=localrc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__, rctoReturn=rc)) return
    
    
    
    ! Return success
    rc = ESMF_SUCCESS    
  end subroutine

  
#if 0
  ! See if the JASON stuff makes this unnecessary
subroutine CheckState(state, config, isOk, rc)
  type(ESMF_Config)     :: config
  type(ESMF_State)      :: state
  logical               :: isOk
  integer, intent(out)  :: rc

  integer :: localrc
  integer ::c,compCount
  character(ESMF_MAXSTR) :: label
  type(ESMF_Config)      :: configComp
  
  ! Init
  isOk=.true.

  ! Get the number of components
  call ESMF_ConfigGetAttribute(config, label="compCount:", value=compCount, &
       rc=localrc)
  if (ESMF_LogFoundError(rcToCheck=localrc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__, rcToReturn=rc)) return

  
  ! Check components
  do c=1, compCount

     ! Get component config information
     write(label,"('comp-',I2.2)") i
     configComp = ESMF_ConfigCreate(config, &
          Openlabel="<"//Trim(label)//":", &
          closelabel=":"//trim(label)//">", rc=localrc)
     if (ESMF_LogFoundError(rcToCheck=localrc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__, rcToReturn=rc)) return


     

  enddo
  
  ! Return success
  rc = ESMF_SUCCESS
  
end subroutine CheckState  
#endif  

  
end program
