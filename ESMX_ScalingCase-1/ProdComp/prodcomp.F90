!==============================================================================
! Earth System Modeling Framework
! Copyright (c) 2002-2024, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!==============================================================================

module ProdComp

  !-----------------------------------------------------------------------------
  ! ProdComp - Producer Component
  !-----------------------------------------------------------------------------

  use ESMF
  use NUOPC
  use NUOPC_Model, &
    modelSS      => SetServices

  implicit none

  private

  public SetVM, SetServices

  !-----------------------------------------------------------------------------
  contains
  !-----------------------------------------------------------------------------

  subroutine SetServices(model, rc)
    type(ESMF_GridComp)  :: model
    integer, intent(out) :: rc

    ! local variables
    type(ESMF_HConfig)        :: hconfig, hconfigNode
    character(80)             :: compLabel
    character(:), allocatable :: badKey
    logical                   :: isFlag

    rc = ESMF_SUCCESS

    ! derive from NUOPC_Model
    call NUOPC_CompDerive(model, modelSS, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! specialize model
    call NUOPC_CompSpecialize(model, specLabel=label_Advertise, &
      specRoutine=Advertise, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompSpecialize(model, specLabel=label_RealizeProvided, &
      specRoutine=Realize, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call NUOPC_CompSpecialize(model, specLabel=label_Advance, &
      specRoutine=Advance, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! validate hconfig
    call ESMF_GridCompGet(model, name=compLabel, hconfigIsPresent=isFlag, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    if (isFlag) then
      ! access ESMX YAML format info through hconfig
      call ESMF_GridCompGet(model, hconfig=hconfig, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      ! access this component instance hconfig node
      hconfigNode = ESMF_HConfigCreateAt(hconfig, keyString=compLabel, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      ! component responsibility to validate ESMX handled options here, and
      ! potentially locally handled options
      isFlag = ESMF_HConfigValidateMapKeys(hconfigNode, &
        vocabulary=["model          ", &  ! ESMX handled option
                    "petList        ", &  ! ESMX handled option
                    "ompNumThreads  ", &  ! ESMX handled option
                    "gridCount      ", &  ! handled by component
                    "localGridSizes ", &  ! handled by component
                    "fieldsPerGrid  ", &  ! handled by component
                    "meshCount      ", &  ! handled by component
                    "localMeshSize  ", &  ! handled by component
                    "fieldsPerMesh  ", &  ! handled by component
                    "attributes     "  &  ! ESMX handled option
                   ], badKey=badKey, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      if (.not.isFlag) then
        call ESMF_LogSetError(ESMF_RC_ARG_WRONG, &
          msg="An invalid key was found in config under "//trim(compLabel)// &
            " (maybe a typo?): "//badKey, &
          line=__LINE__, &
          file=__FILE__, rcToReturn=rc)
        return
      endif
    endif

  end subroutine

  !-----------------------------------------------------------------------------

  subroutine Advertise(model, rc)
    type(ESMF_GridComp)  :: model
    integer, intent(out) :: rc

    ! local variables
    type(ESMF_State)        :: importState, exportState
    integer                 :: verbosity, profiling, diagnostic
    type(ESMF_HConfig)      :: hconfig, hconfigNode
    character(80)           :: compLabel
    integer                 :: gridCount, meshCount, fieldCount
    integer                 :: i, fld, gem
    integer                 :: fieldsPerGrid, fieldsPerMesh
    character(40), allocatable  :: fieldList(:)

    rc = ESMF_SUCCESS

    ! query the component for info
    call NUOPC_CompGet(model, name=compLabel, verbosity=verbosity, &
      profiling=profiling, diagnostic=diagnostic, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! query for importState and exportState
    call NUOPC_ModelGet(model, importState=importState, &
      exportState=exportState, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! access ESMX YAML format info through hconfig
    call ESMF_GridCompGet(model, hconfig=hconfig, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    ! access this component instance hconfig node
    hconfigNode = ESMF_HConfigCreateAt(hconfig, keyString=compLabel, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    ! access settings...
    gridCount = ESMF_HConfigAsI4(hconfigNode, keyString="gridCount", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    fieldsPerGrid = ESMF_HConfigAsI4(hconfigNode, keyString="fieldsPerGrid", &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    meshCount = ESMF_HConfigAsI4(hconfigNode, keyString="meshCount", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    fieldsPerMesh = ESMF_HConfigAsI4(hconfigNode, keyString="fieldsPerMesh", &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! determine fieldCount
    fieldCount = gridCount*fieldsPerGrid + meshCount*fieldsPerMesh

    ! construct fieldList of standard names
    allocate(fieldList(fieldCount))
    fld = 1
    do gem=1, gridCount
      do i=1, fieldsPerGrid
        write(fieldList(fld), '("fld-",I4.4,"-g",I3.3,"f",I3.3)') fld, gem, i
        fld = fld+1
      enddo
    enddo
    do gem=1, meshCount
      do i=1, fieldsPerMesh
        write(fieldList(fld), '("fld-",I4.4,"-m",I3.3,"f",I3.3)') fld, gem, i
        fld = fld+1
      enddo
    enddo

    ! Turn on NUOPC Field Dictionary auto add
    call NUOPC_FieldDictionarySetAutoAdd(.true., rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! exportable fields
    call NUOPC_Advertise(exportState, StandardNames=fieldList, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! Turn off NUOPC Field Dictionary auto add again, no more advertising
    call NUOPC_FieldDictionarySetAutoAdd(.false., rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! clean-up
    deallocate(fieldList)

  end subroutine

  !-----------------------------------------------------------------------------

  subroutine Realize(model, rc)
    type(ESMF_GridComp)  :: model
    integer, intent(out) :: rc

    ! local variables
    type(ESMF_State)        :: importState, exportState
    integer                 :: verbosity, profiling, diagnostic
    type(ESMF_HConfig)      :: hconfig, hconfigNode
    character(80)           :: compLabel
    integer                 :: gridCount, meshCount, fieldCount
    integer                 :: i, fld, gem
    integer                 :: fieldsPerGrid, fieldsPerMesh
    integer, allocatable    :: localGridSizes(:), globalGridSizes(:)
    integer                 :: localMeshSize
    character(40)           :: fieldName, gridName, meshName
    integer                 :: petCount
    type(ESMF_Field)        :: field
    type(ESMF_Grid)         :: grid
    type(ESMF_Mesh)         :: mesh

    rc = ESMF_SUCCESS

    ! query the component for info
    call NUOPC_CompGet(model, name=compLabel, verbosity=verbosity, &
      profiling=profiling, diagnostic=diagnostic, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! query for importState and exportState
    call NUOPC_ModelGet(model, importState=importState, &
      exportState=exportState, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! access ESMX YAML format info through hconfig
    call ESMF_GridCompGet(model, hconfig=hconfig, petCount=petCount, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    ! access this component instance hconfig node
    hconfigNode = ESMF_HConfigCreateAt(hconfig, keyString=compLabel, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    ! access settings...
    gridCount = ESMF_HConfigAsI4(hconfigNode, keyString="gridCount", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    fieldsPerGrid = ESMF_HConfigAsI4(hconfigNode, keyString="fieldsPerGrid", &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    meshCount = ESMF_HConfigAsI4(hconfigNode, keyString="meshCount", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    fieldsPerMesh = ESMF_HConfigAsI4(hconfigNode, keyString="fieldsPerMesh", &
      rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! access local grid size information
    localGridSizes = ESMF_HConfigAsI4Seq(hconfigNode, &
      keyString="localGridSizes", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    ! set up global grid size (decomposition along first dim)
    globalGridSizes = localGridSizes
    globalGridSizes(1) = globalGridSizes(1) * petCount

    ! access local mesh size information
    localMeshSize = ESMF_HConfigAsI4(hconfigNode, &
      keyString="localMeshSize", rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! construct fields and realize
    fld = 1
    do gem=1, gridCount
      ! create grid
      write(gridName, '("g",I3.3)') gem
      grid = ESMF_GridCreateNoPeriDimUfrm(name=gridName, &
        maxIndex=globalGridSizes, &
        minCornerCoord=(/0._ESMF_KIND_R8, 0._ESMF_KIND_R8/), &
        maxCornerCoord=(/100._ESMF_KIND_R8, 200._ESMF_KIND_R8/), &
        coordSys=ESMF_COORDSYS_CART, &
        staggerLocList=(/ESMF_STAGGERLOC_CENTER, ESMF_STAGGERLOC_CORNER/), &
        rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      do i=1, fieldsPerGrid
        write(fieldName, '("fld-",I4.4,"-g",I3.3,"f",I3.3)') fld, gem, i
        call NUOPC_Realize(exportState, grid=grid, fieldName=fieldName, rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
        fld = fld+1
      enddo
    enddo
    do gem=1, meshCount
      ! create mash
      write(meshName, '("m",I3.3)') gem
      mesh = ESMF_MeshCreate(name=meshName, grid=grid, rc=rc) !todo: not use grid
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
      do i=1, fieldsPerMesh
        write(fieldName, '("fld-",I4.4,"-m",I3.3,"f",I3.3)') fld, gem, i
        call NUOPC_Realize(exportState, mesh=mesh, fieldName=fieldName, rc=rc)
        if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
          line=__LINE__, &
          file=__FILE__)) &
          return  ! bail out
        fld = fld+1
      enddo
    enddo

  end subroutine

  !-----------------------------------------------------------------------------

  subroutine Advance(model, rc)
    type(ESMF_GridComp)  :: model
    integer, intent(out) :: rc

    ! local variables
    type(ESMF_Clock)        :: clock
    type(ESMF_State)        :: importState, exportState
    character(len=160)      :: name
    type(ESMF_Time)         :: currTime
    type(ESMF_TimeInterval) :: timeStep
    type(ESMF_VM)           :: vm
    integer                 :: currentSsiPe
    character(len=160)      :: msgString

    rc = ESMF_SUCCESS

    ! query the component for info
    call NUOPC_CompGet(model, name=name, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! query for clock, importState and exportState
    call NUOPC_ModelGet(model, modelClock=clock, &
      importState=importState, exportState=exportState, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! Query for VM
    call ESMF_GridCompGet(model, vm=vm, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_VMLog(vm, prefix=trim(name)//" Advance(): ", &
      logMsgFlag=ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! HERE THE MODEL ADVANCES: currTime -> currTime + timeStep

    call ESMF_ClockPrint(clock, options="currTime", &
      preString="------>Advancing "//trim(name)//" from: ", &
      unit=msgString, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call ESMF_LogWrite(msgString, ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_ClockGet(clock, currTime=currTime, timeStep=timeStep, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_TimePrint(currTime + timeStep, &
      preString="---------------------> to: ", unit=msgString, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
    call ESMF_LogWrite(msgString, ESMF_LOGMSG_INFO, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

  end subroutine

  !-----------------------------------------------------------------------------

end module
