!==============================================================================
! Earth System Modeling Framework
! Copyright 2002-2020, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

program ESMF_ReconcileStress

  ! modules
  use ESMF
  use Mediator,   only: medSS       => SetServices
  use Model,      only: modSS       => SetServices
  use Connector,  only: connectorSS => SetServices
  
  implicit none
  
  ! local variables
  integer               :: rc, urc, unit
  integer               :: i, petCount, localPet, modelCount, petListBounds(2)
  integer, allocatable  :: petList(:), mediatorPetList(:), connectorPetList(:)
  character(40)         :: configfile, label, outputFile
  type(ESMF_VM)         :: vm
  type(ESMF_Config)     :: config, configComp
  type(ESMF_GridComp)   :: mediatorgc
  type(ESMF_State)      :: medState
  type(ESMF_GridComp), allocatable :: modelList(:)
  type(ESMF_State),    allocatable :: stateList(:)
  type(ESMF_CplComp),  allocatable :: connectorList(:)
  real(ESMF_KIND_R8)    :: t0, t1, t2, t3
  
  
  ! start up
  call ESMF_Initialize(vm=vm, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_LogWrite("ESMF_ReconcileStress STARTING", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_VMGet(vm, petCount=petCount, localPet=localPet, rc=rc)
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
  write(configfile,"('stressP',I6.6,'.config')") petCount
  call ESMF_ConfigLoadFile(config, trim(configfile), rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_ConfigGetAttribute(config, label="outputFile:", &
    value=outputFile, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  if (localPet==0) then
    ! open outputFile
    call ESMF_UtilIOUnitGet(unit, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    open(unit, file=trim(outputFile), position="append")
  endif
  
  ! create the mediator
  configComp = ESMF_ConfigCreate(config, openlabel="<mediator:", &
    closelabel=":mediator>", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_ConfigGetAttribute(configComp, label="petListBounds:", &
    valueList=petListBounds, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call CreatePetList(mediatorPetList, petListBounds, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_LogWrite("Creating 'mediator' component.", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  mediatorgc = ESMF_GridCompCreate(name="mediator", config=configComp, &
    petList=mediatorPetList, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! create the models and connectors
  call ESMF_ConfigGetAttribute(config, label="modelCount:", value=modelCount, &
    rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  allocate(modelList(modelCount), connectorList(modelCount))
  do i=1, modelCount
    write(label,"('model-',I2.2)") i
    configComp = ESMF_ConfigCreate(config, openlabel="<"//trim(label)//":", &
      closelabel=":"//trim(label)//">", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_ConfigGetAttribute(configComp, label="petListBounds:", &
      valueList=petListBounds, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call CreatePetList(petList, petListBounds, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_LogWrite("Creating '"//trim(label)//"' component.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    modelList(i) = ESMF_GridCompCreate(name=trim(label), config=configComp, &
      petList=petList, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)

    call ESMF_LogWrite("Creating 'Connector-"//trim(label)//"' component.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call MergePetLists(connectorPetList, mediatorPetList, petList, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    connectorList(i) = ESMF_CplCompCreate(name="Connector-"//trim(label), &
      petList=connectorPetList, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
      
    deallocate(petList, connectorPetList)
  enddo
  
  ! call the mediator SetServices and create the mediator state
  call ESMF_LogWrite("Calling 'mediator' SetServices.", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_GridCompSetServices(mediatorgc, userRoutine=medSS, userRc=urc, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  medState = ESMF_StateCreate(name="medState", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! call each model SetServices, create each model State, and call connector SS
  allocate(stateList(modelCount))
  do i=1, modelCount
    write(label,"('model-',I2.2)") i
    call ESMF_LogWrite("Calling '"//trim(label)//"' SetServices.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_GridCompSetServices(modelList(i), userRoutine=modSS, userRc=urc, &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    stateList(i) = ESMF_StateCreate(name=trim(label)//"State", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_LogWrite("Calling 'Connector-"//trim(label)//"' SetServices.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_CplCompSetServices(connectorList(i), userRoutine=connectorSS, &
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
  
  ! Mediator initialize phase=1 
  call ESMF_LogWrite("Calling 'mediator' Init1.", ESMF_LOGMSG_INFO, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_GridCompInitialize(mediatorgc, phase=1, importState=medState, &
    userRc=urc, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! Loop over all the Connectors from models to mediator - calls Reconcile()
  call ESMF_VMBarrier(vm, rc=rc)
  call ESMF_VMLogMemInfo(prefix="before Reconcile", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_TraceRegionEnter("Reconcile", rc=rc)
  call ESMF_VMWTime(t0, rc=rc)
  do i=1, modelCount
#if 0
    write(label,"('model-',I2.2)") i
    call ESMF_LogWrite("Calling 'Connector-"//trim(label)//"' Init.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
#endif
    call ESMF_CplCompInitialize(connectorList(i), importState=stateList(i), &
      exportState=medState, userRc=urc, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo
  call ESMF_VMBarrier(vm, rc=rc)
  call ESMF_VMWTime(t1, rc=rc)
  call ESMF_TraceRegionExit("Reconcile", rc=rc)
  call ESMF_VMLogMemInfo(prefix="after Reconcile", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
#if 0
  ! Loop over all the Connectors from models to mediator - calls Re-Reconcile()
  call ESMF_VMBarrier(vm, rc=rc)
  call ESMF_VMLogMemInfo(prefix="before ReReconcile", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  call ESMF_TraceRegionEnter("ReReconcile", rc=rc)
  call ESMF_VMWTime(t2, rc=rc)
  do i=1, modelCount
#if 0
    write(label,"('model-',I2.2)") i
    call ESMF_LogWrite("Calling 'Connector-"//trim(label)//"' Init.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
#endif
    call ESMF_CplCompInitialize(connectorList(i), importState=stateList(i), &
      exportState=medState, userRc=urc, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=urc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo
  call ESMF_VMBarrier(vm, rc=rc)
  call ESMF_VMWTime(t3, rc=rc)
  call ESMF_TraceRegionExit("ReReconcile", rc=rc)
  call ESMF_VMLogMemInfo(prefix="after ReReconcile", rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)

  if (localPet==0) then
    write(unit,*) t1-t0, t3-t2
    close(unit)
  endif
#endif

  ! destroy the models and connectors
  do i=1, modelCount
    call ESMF_GridCompDestroy(modelList(i), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    call ESMF_CplCompDestroy(connectorList(i), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
  enddo

  ! destroy the mediator
  call ESMF_GridCompDestroy(mediatorgc, rc=rc)
  if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
    line=__LINE__, &
    file=__FILE__)) &
    call ESMF_Finalize(endflag=ESMF_END_ABORT)
  
  ! final wrap up
  call ESMF_LogWrite("ESMF_ReconcileStress FINISHED", ESMF_LOGMSG_INFO, rc=rc)
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
