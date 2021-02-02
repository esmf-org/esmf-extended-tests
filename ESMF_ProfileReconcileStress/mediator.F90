!==============================================================================
! Earth System Modeling Framework
! Copyright 2002-2021, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

module Mediator
  use ESMF
  use NUOPC
  implicit none
  
  private
 
  type(ESMF_Container)  :: fieldListContainer
  type FieldList
    type(ESMF_Field), pointer :: fieldList(:)
  end type
  type FieldListWrap
    type(FieldList), pointer :: wrap
  end type
  
  type(ESMF_Container)  :: gridContainer
  type GridWrap
    type(ESMF_Grid), pointer :: wrap
  end type

  type(ESMF_Container)  :: meshContainer
  type MeshWrap
    type(ESMF_Mesh), pointer :: wrap
  end type

  public SetServices
  
  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  subroutine SetServices(mediator, rc)
    type(ESMF_GridComp)   :: mediator
    integer, intent(out)  :: rc
    
    rc = ESMF_SUCCESS
    
    call ESMF_GridCompSetEntryPoint(mediator, ESMF_METHOD_INITIALIZE, &
      phase=1, userRoutine=Init1, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
  end subroutine
  
  !-----------------------------------------------------------------------------

  subroutine Init1(mediator, importState, exportState, clock, rc)
    type(ESMF_GridComp)   :: mediator
    type(ESMF_State)      :: importState, exportState
    type(ESMF_Clock)      :: clock
    integer, intent(out)  :: rc
    
    type(ESMF_Config)           :: config
    
    rc = ESMF_SUCCESS

    call ESMF_GridCompGet(mediator, config=config, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    ! set up the auxiliary lookup containers
    fieldListContainer = ESMF_ContainerCreate(rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    gridContainer = ESMF_ContainerCreate(rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    meshContainer = ESMF_ContainerCreate(rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! ingest the Config file, and populate the importState
    call AddStateMembers(importState, config, label="stateMembers:", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

  end subroutine
  
  !-----------------------------------------------------------------------------
 
  recursive subroutine AddStateMembers(state, config, label, rc)
    type(ESMF_State)      :: state
    type(ESMF_Config)     :: config
    character(*)          :: label
    integer, intent(out)  :: rc
 
    integer                     :: count, i
    character(40), allocatable  :: stateMembers(:)
    character(ESMF_MAXSTR), pointer :: tokenList(:)

    rc = ESMF_SUCCESS

    ! read state members
    count = ESMF_ConfigGetLen(config, label=trim(label), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    allocate(stateMembers(count))
    call ESMF_ConfigGetAttribute(config, label=trim(label), &
      valueList=stateMembers, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! loop over state members, tokenize, and populate importState
    do i=1, count
      nullify(tokenList)
      call NUOPC_ChopString(stateMembers(i), chopChar="-", &
        chopStringList=tokenList, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      if (size(tokenList)/=2) then
        call ESMF_LogSetError(ESMF_RC_ARG_BAD, &
          msg="Format problem in stateMember", &
          line=__LINE__, file=__FILE__, rcToReturn=rc)
        return  ! bail out
      endif
      if (trim(tokenList(1))=="fields") then
        call AddFields(state, config, stateMembers(i), rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
      else if (trim(tokenList(1))=="nest") then
        call AddNest(state, config, stateMembers(i), rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
      else
        call ESMF_LogSetError(ESMF_RC_ARG_BAD, &
          msg="stateMember is neither 'fields' nor 'nest'", &
          line=__LINE__, file=__FILE__, rcToReturn=rc)
        return  ! bail out
      endif
      if (associated(tokenList)) deallocate(tokenList)
    enddo
  
  end subroutine
 
  !-----------------------------------------------------------------------------

  recursive subroutine AddNest(state, config, label, rc)
    type(ESMF_State), intent(inout) :: state
    type(ESMF_Config),intent(in)    :: config
    character(*),     intent(in)    :: label
    integer,          intent(out)   :: rc
    
    type(ESMF_State)            :: nestedState
    
    rc = ESMF_SUCCESS
    
    ! create the nestedState
    nestedState = ESMF_StateCreate(name=trim(label), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    ! add the nestedState to the state
    call ESMF_StateAdd(state, (/nestedState/), rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call ESMF_LogWrite("Add nest '"//trim(label)//"' to state.", &
      ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      call ESMF_Finalize(endflag=ESMF_END_ABORT)
    
    ! recursively populate the state
    call AddStateMembers(nestedState, config, label=trim(label)//":", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
  end subroutine

  !-----------------------------------------------------------------------------
 
  recursive subroutine AddFields(state, config, label, rc)
    type(ESMF_State), intent(inout) :: state
    type(ESMF_Config),intent(in)    :: config
    character(*),     intent(in)    :: label
    integer,          intent(out)   :: rc
    
    type(ESMF_Config) :: configFields
    integer           :: count, i
    character(40)     :: tkS, geomS, fieldName
    character(ESMF_MAXSTR), pointer :: tokenList(:)
    type(ESMF_Grid)   :: grid
    type(ESMF_Mesh)   :: mesh
    type(ESMF_TypeKind_Flag) :: tk
    type(ESMF_Logical)  :: isPres
    type(FieldListWrap) :: flW
    
    rc = ESMF_SUCCESS
    
    ! check if the fieldList by this label already exists
    call c_ESMC_ContainerGetIsPresent(fieldListContainer, trim(label), &
      isPres, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    if (isPres==ESMF_TRUE) then
      ! query the fieldList from the container, and add it to the state
      call ESMF_LogWrite("Query fieldList '"//trim(label)//"' from lookup.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      call ESMF_ContainerGetUDT(fieldListContainer, trim(label), flW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    else
      ! must create a new fieldList and add to the state
      call ESMF_LogWrite("Create fieldList '"//trim(label)//"' from scratch.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      allocate(flW%wrap)
      configFields = ESMF_ConfigCreate(config, openlabel="<"//trim(label)//":", &
        closelabel=":"//trim(label)//">", rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      
      call ESMF_ConfigGetAttribute(configFields, label="count:", &
        value=count, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      call ESMF_ConfigGetAttribute(configFields, label="typekind:", &
        value=tkS, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      call ESMF_ConfigGetAttribute(configFields, label="geom:", &
        value=geomS, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      if (trim(tkS)=="I4") then
        tk = ESMF_TYPEKIND_I4
      else if (trim(tkS)=="I8") then
        tk = ESMF_TYPEKIND_I8
      else if (trim(tkS)=="R4") then
        tk = ESMF_TYPEKIND_R4
      else if (trim(tkS)=="R8") then
        tk = ESMF_TYPEKIND_R8
      else
        call ESMF_LogSetError(ESMF_RC_ARG_BAD, &
          msg="Specified typekind not supported", &
          line=__LINE__, file=__FILE__, rcToReturn=rc)
        return  ! bail out
      endif
      
      nullify(tokenList)
      call NUOPC_ChopString(trim(geomS), chopChar="-", &
        chopStringList=tokenList, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      if (size(tokenList)/=2) then
        call ESMF_LogSetError(ESMF_RC_ARG_BAD, &
          msg="Format problem in geom string", &
          line=__LINE__, file=__FILE__, rcToReturn=rc)
        return  ! bail out
      endif
      if (trim(tokenList(1))=="grid") then
        grid = CreateGrid(trim(geomS), rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
        allocate(flW%wrap%fieldList(count))
        do i=1, count
          write(fieldName,"(A,'-',I4.4)") trim(label),i
          flW%wrap%fieldList(i) = ESMF_FieldCreate(grid, typekind=tk, &
            name=trim(fieldName), rc=rc)
          if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out
        enddo
      else if (trim(tokenList(1))=="mesh") then
        mesh = CreateMesh(trim(geomS), rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
        allocate(flW%wrap%fieldList(count))
        do i=1, count
          write(fieldName,"(A,'-',I4.4)") trim(label),i
          flW%wrap%fieldList(i) = ESMF_FieldCreate(mesh, typekind=tk, &
            name=trim(fieldName), rc=rc)
          if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
            line=__LINE__, &
            file=__FILE__)) &
            return  ! bail out
        enddo
      else
        call ESMF_LogSetError(ESMF_RC_ARG_BAD, &
          msg="geom string is neither 'grid' nor 'mesh'", &
          line=__LINE__, file=__FILE__, rcToReturn=rc)
        return  ! bail out
      endif
      ! add the fieldList to the fieldList container for later lookup
      call ESMF_ContainerAddUDT(fieldListContainer, trim(label), flW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      ! clean-up
      if (associated(tokenList)) deallocate(tokenList)
    endif
    ! add the fieldList to the state
    call ESMF_StateAdd(state, flW%wrap%fieldList, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
  end subroutine

  !-----------------------------------------------------------------------------
  
  function CreateGrid(gridName, rc)
    type(ESMF_Grid)           :: CreateGrid
    character(*), intent(in)  :: gridName
    integer,      intent(out) :: rc
    
    type(ESMF_Logical)  :: isPres
    type(GridWrap)      :: gW

    rc = ESMF_SUCCESS

    ! check if the grid by this name already exists
    call c_ESMC_ContainerGetIsPresent(gridContainer, trim(gridName), &
      isPres, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    if (isPres==ESMF_TRUE) then
      ! query the grid from the container
      call ESMF_LogWrite("Query grid '"//trim(gridName)//"' from lookup.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      call ESMF_ContainerGetUDT(gridContainer, trim(gridName), gW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    else
      ! must create a new fieldList and add to the state
      call ESMF_LogWrite("Create grid '"//trim(gridName)//"' from scratch.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      allocate(gW%wrap)

      gW%wrap = ESMF_GridCreateNoPeriDimUfrm(maxIndex=(/100, 100/), &
        minCornerCoord=(/0._ESMF_KIND_R8,  -90._ESMF_KIND_R8/), &
        maxCornerCoord=(/360._ESMF_KIND_R8, 90._ESMF_KIND_R8/), &
        staggerLocList=(/ESMF_STAGGERLOC_CENTER, ESMF_STAGGERLOC_CORNER/), &
        name=gridName, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
        
      ! add the grid to the grid container for later lookup
      call ESMF_ContainerAddUDT(gridContainer, trim(gridName), gW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    endif
    
    ! return the grid
    CreateGrid = gW%wrap

  end function
  
  !-----------------------------------------------------------------------------
  
  function CreateMesh(meshName, rc)
    type(ESMF_Mesh)           :: CreateMesh
    character(*), intent(in)  :: meshName
    integer,      intent(out) :: rc
    
    type(ESMF_Logical)  :: isPres
    type(MeshWrap)      :: mW

    rc = ESMF_SUCCESS

    ! check if the mesh by this name already exists
    call c_ESMC_ContainerGetIsPresent(meshContainer, trim(meshName), &
      isPres, rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    
    if (isPres==ESMF_TRUE) then
      ! query the mesh from the container
      call ESMF_LogWrite("Query mesh '"//trim(meshName)//"' from lookup.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      call ESMF_ContainerGetUDT(meshContainer, trim(meshName), mW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    else
      ! must create a new fieldList and add to the state
      call ESMF_LogWrite("Create mesh '"//trim(meshName)//"' from scratch.", &
        ESMF_LOGMSG_INFO, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        call ESMF_Finalize(endflag=ESMF_END_ABORT)
      allocate(mW%wrap)
      mW%wrap = ESMF_MeshCreateCubedSphere(tileSize=50, &
        nx=10, ny=10, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

      ! add the mesh to the mesh container for later lookup
      call ESMF_ContainerAddUDT(meshContainer, trim(meshName), mW, rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    endif
    
    ! return the mesh
    CreateMesh = mW%wrap

  end function
  
  !-----------------------------------------------------------------------------
  
end module
