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
  character(40)         :: configfile, label
  type(ESMF_VM)         :: vm
  type(ESMF_Config)     :: config, configComp
  type(ESMF_State)      :: state
  real(ESMF_KIND_R8)    :: begTime, endTime
  real(ESMF_KIND_R8)    :: petListBoundsRel(2)
  integer               :: numArgs
  integer,parameter     :: badPet=-1
  
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


  ! Create State
  state = ESMF_StateCreate(name="State", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
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

  ! Debug
  if (localPet==0) then
     write(*,*) "compCount=",compCount
  endif

  
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

    ! Try to get absolute bounds
    call ESMF_ConfigGetAttribute(configComp, label="petListBounds:", &
         valueList=petListBounds, default=badPet, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
         line=__LINE__, &
         file=__FILE__)) &
         call ESMF_Finalize(endflag=ESMF_END_ABORT)
    
    ! If we didn't find the absolute bounds, use relative
    if (petListBounds(1) == badPet) then
       call ESMF_ConfigGetAttribute(configComp, label="petListBoundsRel:", &
            valueList=petListBoundsRel, rc=rc)
       if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            call ESMF_Finalize(endflag=ESMF_END_ABORT)
       
       ! Calculate absolute bounds using relative
       petListBounds(1)=INT(petListBoundsRel(1)*REAL(petCount-1))
       petListBounds(2)=INT(petListBoundsRel(2)*REAL(petCount-1))    
    endif

    call CreatePetList(petList, petListBounds, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)

    ! Debug output
    if (localPet==0) then
       write(*,*) "Model ",i," PetListBounds=",petListBounds
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

  ! Output time
  if (localPet == 0) then
     write(*,*) "Reconcile time=",endTime-begTime
  endif
  

  ! destroy the models and connectors
  do i=1, compCount
    call ESMF_GridCompDestroy(compList(i), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo

  ! Destroy the State
  call ESMF_StateDestroy(state, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
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
  
  !-----------------------------------------------------------------------------

  subroutine MergePetLists(outPetList, inPetList1, inPetList2, rc)
    integer, allocatable  :: outPetList(:)
    integer, intent(in)   :: inPetList1(:)
    integer, intent(in)   :: inPetList2(:)
    integer, intent(out)  :: rc
    
    integer, allocatable :: tempPetList(:)
    integer :: i, j, jj, size1, size2
    logical :: duplicate
    
    rc = ESMF_SUCCESS
    
    size1 = size(inPetList1)
    size2 = size(inPetList2)
    
    allocate(tempPetList(size1+size2))  ! definitely large enough
    
    if (size1 >= size2) then
      tempPetList(1:size1) = inPetList1(1:size1)
      jj = size1
      do i=1, size2
        duplicate = .false.
        do j=1, jj
          if (inPetList2(i)==tempPetList(j)) then
            duplicate = .true.
            exit
          endif
        enddo
        if (.not.duplicate) then
          jj = jj + 1
          tempPetList(jj) = inPetList2(i)
        endif
      enddo
    else
      tempPetList(1:size2) = inPetList2(1:size2)
      jj = size2
      do i=1, size1
        duplicate = .false.
        do j=1, jj
          if (inPetList1(i)==tempPetList(j)) then
            duplicate = .true.
            exit
          endif
        enddo
        if (.not.duplicate) then
          jj = jj + 1
          tempPetList(jj) = inPetList1(i)
        endif
      enddo
    endif
    
    allocate(outPetList(jj))
    outPetList(1:jj) = tempPetList(1:jj)
    
  end subroutine

end program
