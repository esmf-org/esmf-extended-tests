! $Id:  Exp $
!
! Earth System Modeling Framework
! Copyright 2002-2022, University Corporation for Atmospheric Research,
! Massachusetts Institute of Technology, Geophysical Fluid Dynamics
! Laboratory, University of Michigan, National Centers for Environmental
! Prediction, Los Alamos National Laboratory, Argonne National Laboratory,
! NASA Goddard Space Flight Center.
! Licensed under the University of Illinois-NCSA License.
!

program MOAB_eval

  use ESMF
  implicit none
  logical :: correct
  integer :: localrc, rc
  integer :: localPet, petCount
  type(ESMF_VM) :: vm
  character(ESMF_MAXPATHLEN), dimension(8) :: files

  type(ESMF_Mesh) :: mesh
  real(ESMF_KIND_R8) :: beg_time, end_time
  real(ESMF_KIND_R8) :: max_time, avg_time
  integer :: i

   ! Init ESMF
  call ESMF_Initialize(rc=localrc, logappendflag=.false.)
  if (localrc /=ESMF_SUCCESS) stop

  ! get pet info
   call ESMF_VMGetGlobal(vm, rc=localrc)
  if (localrc /=ESMF_SUCCESS) stop

  call ESMF_VMGet(vm, petCount=petCount, localPet=localpet, rc=localrc)
  if (localrc /=ESMF_SUCCESS) stop

  files(1) = "data/ll10x10_grid.esmf.nc"
  files(2) = "data/ll20x20_grid.esmf.nc"
  files(3) = "data/ll40x40_grid.esmf.nc"
  files(4) = "data/ll80x80_grid.esmf.nc"
  files(5) = "data/ll160x160_grid.esmf.nc"
  files(6) = "data/ll320x320_grid.esmf.nc"
  files(7) = "data/ll640x640_grid.esmf.nc"
  files(8) = "data/ll1280x1280_grid.esmf.nc"

  ! Write out number of PETS
  if (localPet .eq. 0) then
    write(*,*) "timings of mesh create for grids of increasing size"
    write(*,*) ""
  endif

  !!!!!!!!!!!!!!! Time NativeMesh !!!!!!!!!!!!
  write(*,*) "ESMF MESH"
  do i=1,8
    write(*,*) trim(files(i))
  enddo
  write (*,*)

  ! Make sure  MOAB is off
  call ESMF_MeshSetMOAB(.false., rc=localrc)
  if (localrc .ne. ESMF_SUCCESS) stop


  do i=1,8

    call ESMF_VMLogMemInfo("before mesh create")
    call ESMF_VMBarrier(vm)
    call ESMF_VMWtime(beg_time)

    mesh=ESMF_MeshCreate(filename=files(i), &
!            fileformat=ESMF_FILEFORMAT_SCRIP, &
            fileformat=ESMF_FILEFORMAT_ESMFMESH, &
            rc=localrc)
    if (localrc /=ESMF_SUCCESS) stop

    call ESMF_VMWtime(end_time)
    call ESMF_VMLogMemInfo("after mesh create")
    if (localrc /=ESMF_SUCCESS) stop
    write(*,*) end_time - beg_time

    call ESMF_MeshDestroy(mesh, rc=localrc)
    if (localrc /=ESMF_SUCCESS) stop

  enddo

  write (*,*)
  write (*,*)

  !!!!!!!!!!!!!!! Time MOAB Mesh !!!!!!!!!!!!
  write(*,*) "MOAB MESH"
  do i=1,8
      write(*,*) trim(files(i))
  enddo
  write (*,*)

  ! Turn on MOAB
  call ESMF_MeshSetMOAB(.true., rc=localrc)
  if (localrc .ne. ESMF_SUCCESS) stop

  do i=1,8

    call ESMF_VMLogMemInfo("before mesh create")
    call ESMF_VMBarrier(vm)
    call ESMF_VMWtime(beg_time)

    mesh=ESMF_MeshCreate(filename=files(i), &
!            fileformat=ESMF_FILEFORMAT_SCRIP, &
            fileformat=ESMF_FILEFORMAT_ESMFMESH, &
            rc=localrc)
    if (localrc /=ESMF_SUCCESS) stop

    call ESMF_VMWtime(end_time)
    call ESMF_VMLogMemInfo("after mesh create")
    if (localrc /=ESMF_SUCCESS) stop

    write(*,*) end_time - beg_time

    call ESMF_MeshDestroy(mesh, rc=localrc)
    if (localrc /=ESMF_SUCCESS) stop

  enddo

  write (*,*)

  ! Finalize ESMF
  call ESMF_Finalize(rc=localrc)
  if (localrc /=ESMF_SUCCESS) stop

end program MOAB_eval
