!==============================================================================!
  subroutine Save_Results(grid, name_save)
!------------------------------------------------------------------------------!
!   Writes results in VTU file format (for VisIt and Paraview)                 !
!------------------------------------------------------------------------------!
!---------------------------------[Modules]------------------------------------!
  use Name_Mod, only: problem_name
  use Const_Mod
  use Flow_Mod
  use Rans_Mod
  use Comm_Mod
  use Tokenizer_Mod
  use Grid_Mod
  use Control_Mod
  use User_Mod
  use Work_Mod, only: v2_calc   => r_cell_01,  &
                      uu_mean   => r_cell_02,  &
                      vv_mean   => r_cell_03,  &
                      ww_mean   => r_cell_04,  &
                      uv_mean   => r_cell_05,  &
                      uw_mean   => r_cell_06,  &
                      vw_mean   => r_cell_07,  &
                      tt_mean   => r_cell_08,  &
                      ut_mean   => r_cell_09,  &
                      vt_mean   => r_cell_10,  &
                      wt_mean   => r_cell_11,  &
                      kin_vis_t => r_cell_12
!------------------------------------------------------------------------------!
  implicit none
!--------------------------------[Arguments]-----------------------------------!
  type(Grid_Type)  :: grid
  character(len=*) :: name_save
!----------------------------------[Locals]------------------------------------!
  integer           :: c, n, offset
  character(len=80) :: name_out_8, name_out_9, store_name
!-----------------------------[Local parameters]-------------------------------!
  integer, parameter :: VTK_TETRA      = 10  ! cell shapes in VTK format
  integer, parameter :: VTK_HEXAHEDRON = 12
  integer, parameter :: VTK_WEDGE      = 13
  integer, parameter :: VTK_PYRAMID    = 14
  character(len= 0)  :: IN_0 = ''           ! indentation levels
  character(len= 2)  :: IN_1 = '  '
  character(len= 4)  :: IN_2 = '    '
  character(len= 6)  :: IN_3 = '      '
  character(len= 8)  :: IN_4 = '        '
  character(len=10)  :: IN_5 = '          '
!==============================================================================!

  ! Store the name
  store_name = problem_name

  problem_name = name_save

  call Comm_Mod_Wait

  !--------------------------------------!
  !                                      !
  !   Create .pvtu file and .vtu files   !
  !                                      !
  !--------------------------------------!
  call Name_File(0, name_out_8, '.pvtu')
  call Name_File(this_proc, name_out_9, '.vtu')

  if(n_proc > 1 .and. this_proc .eq. 1) then
    open(8, file=name_out_8)
    print *, '# Creating file: ', trim(name_out_8)
  end if
  open(9, file=name_out_9)
  print *, '# Creating file: ', trim(name_out_9)

  !------------!
  !            !
  !   Header   !
  !            !
  !------------!
  if(n_proc > 1 .and. this_proc .eq. 1)  then
    write(8,'(a,a)') IN_0, '<?xml version="1.0"?>'
    write(8,'(a,a)') IN_0, '<VTKFile type="PUnstructuredGrid">'
    write(8,'(a,a)') IN_1, '<PUnstructuredGrid GhostLevel="0">'
  end if

  write(9,'(a,a)') IN_0, '<?xml version="1.0"?>'
  write(9,'(a,a)') IN_0, '<VTKFile type="UnstructuredGrid" version="0.1" ' //  &
                         'byte_order="LittleEndian">'
  write(9,'(a,a)') IN_1, '<UnstructuredGrid>'

  write(9,'(a,a,i0.0,a,i0.0,a)')   &
                   IN_2, '<Piece NumberOfPoints="', grid % n_nodes,      &
                              '" NumberOfCells ="', grid % n_cells, '">'

  !----------!
  !          !
  !   Grid   !
  !          !
  !----------!

  !-----------!
  !   Nodes   !
  !-----------!
  if(n_proc > 1 .and. this_proc .eq. 1)  then
    write(8,'(a,a)') IN_3, '<PPoints>'
    write(8,'(a,a)') IN_4, '<PDataArray type="Float32" NumberOfComponents=' // &
                           '"3" format="ascii"/>'
    write(8,'(a,a)') IN_3, '</PPoints>'
  end if
  write(9,'(a,a)') IN_3, '<Points>'
  write(9,'(a,a)') IN_4, '<DataArray type="Float32" NumberOfComponents' //  &
                         '="3" format="ascii">'
  do n = 1, grid % n_nodes
    write(9, '(a,1pe16.6e4,1pe16.6e4,1pe16.6e4)')                &
               IN_5, grid % xn(n), grid % yn(n), grid % zn(n)
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'
  write(9,'(a,a)') IN_3, '</Points>'

  !-----------!
  !   Cells   !
  !-----------!
  write(9,'(a,a)') IN_3, '<Cells>'

  ! First write all cells' nodes
  write(9,'(a,a)') IN_4, '<DataArray type="Int32" Name="connectivity"' //  &
                         ' format="ascii">'

  do c = 1, grid % n_cells
    if(grid % cells_n_nodes(c) .eq. 8) then
      write(9,'(a,8i9)')                                &
        IN_5,                                           &
        grid % cells_n(1,c)-1, grid % cells_n(2,c)-1,   &
        grid % cells_n(4,c)-1, grid % cells_n(3,c)-1,   &
        grid % cells_n(5,c)-1, grid % cells_n(6,c)-1,   &
        grid % cells_n(8,c)-1, grid % cells_n(7,c)-1
    else if(grid % cells_n_nodes(c) .eq. 6) then
      write(9,'(a,6i9)')                                &
        IN_5,                                           &
        grid % cells_n(1,c)-1, grid % cells_n(2,c)-1,   &
        grid % cells_n(3,c)-1, grid % cells_n(4,c)-1,   &
        grid % cells_n(5,c)-1, grid % cells_n(6,c)-1
    else if(grid % cells_n_nodes(c) .eq. 4) then
      write(9,'(a,4i9)')                                &
        IN_5,                                           &
        grid % cells_n(1,c)-1, grid % cells_n(2,c)-1,   &
        grid % cells_n(3,c)-1, grid % cells_n(4,c)-1
    else if(grid % cells_n_nodes(c) .eq. 5) then
      write(9,'(a,5i9)')                                &
        IN_5,                                           &
        grid % cells_n(5,c)-1, grid % cells_n(1,c)-1,   &
        grid % cells_n(2,c)-1, grid % cells_n(4,c)-1,   &
        grid % cells_n(3,c)-1
    else
      print *, '# Unsupported cell type with ',  &
                  grid % cells_n_nodes(c), ' nodes.'
      print *, '# Exiting'
      stop
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'

  ! Now write all cells' offsets
  write(9,'(a,a)') IN_4, '<DataArray type="Int32" Name="offsets" format="ascii">'
  offset = 0
  do c = 1, grid % n_cells
    offset = offset + grid % cells_n_nodes(c)
    write(9,'(a,i9)') IN_5, offset
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'

  ! Now write all cells' types
  write(9,'(a,a)') IN_4, '<DataArray type="UInt8" Name="types" format="ascii">'
  do c = 1, grid % n_cells
    if(grid % cells_n_nodes(c) .eq. 8) then
      write(9,'(a,i9)') IN_5, VTK_HEXAHEDRON
    else if(grid % cells_n_nodes(c) .eq. 6) then
      write(9,'(a,i9)') IN_5, VTK_WEDGE
    else if(grid % cells_n_nodes(c) .eq. 4) then
      write(9,'(a,i9)') IN_5, VTK_TETRA
    else if(grid % cells_n_nodes(c) .eq. 5) then
      write(9,'(a,i9)') IN_5, VTK_PYRAMID
    else
      print *, '# Unsupported cell type with ',  &
                  grid % cells_n_nodes(c), ' nodes.'
      print *, '# Exiting'
      stop
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'
  write(9,'(a,a)') IN_3, '</Cells>'

  !---------------------------------!
  !                                 !
  !   Results and other cell data   !
  !                                 !
  !---------------------------------!
  if(n_proc > 1 .and. this_proc .eq. 1)  then
    write(8,'(a,a)') IN_3, '<PCellData Scalars="scalars" vectors="velocity">'
  end if
  write(9,'(a,a)') IN_3, '<CellData Scalars="scalars" vectors="velocity">'

  !---------------!
  !   Materials   !
  !---------------!
  if(n_proc > 1 .and. this_proc .eq. 1)  then
    write(8,'(a,a)') IN_3, '<PDataArray type="UInt8" Name="materials"' //  &
                           ' format="ascii"/>'
  end if
  write(9,'(a,a)') IN_4, '<DataArray type="UInt8" Name="materials"' //  &
                         ' format="ascii">'
  do c = 1, grid % n_cells
    write(9,'(a,i9)') IN_5, grid % material(c)
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'

  !--------------!
  !   Velocity   !
  !--------------!
  call Save_Vtu_Vector(grid, IN_4, IN_5, "UVW", u % n(1), v % n(1), w % n(1))

  !--------------!
  !   Pressure   !
  !--------------!
  call Save_Vtu_Scalar(grid, IN_4, IN_5, p % name, p % n(1))

  !-----------------!
  !   Temperature   !
  !-----------------!
  if(heat_transfer .eq. YES) then
    call Save_Vtu_Scalar(grid, IN_4, IN_5, t % name, t % n(1))
  end if

  !--------------------------!
  !   Turbulent quantities   !
  !--------------------------!

  ! Save kin and eps
  if(turbulence_model .eq. K_EPS                  .or.  &
     turbulence_model .eq. K_EPS_ZETA_F           .or.  &
     turbulence_model .eq. HYBRID_K_EPS_ZETA_F    .or.  &
     turbulence_model .eq. REYNOLDS_STRESS  .or.  &
     turbulence_model .eq. HANJALIC_JAKIRLIC  ) then
    call Save_Vtu_Scalar(grid, IN_4, IN_5, kin % name, kin % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, eps % name, eps % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "P_KIN", p_kin(1))
  end if

  ! Save zeta and f22
  if(turbulence_model .eq. K_EPS_ZETA_F  .or.  &
     turbulence_model .eq. HYBRID_K_EPS_ZETA_F) then
    do c = 1, grid % n_cells
      v2_calc(c) = kin % n(c) * zeta % n(c)
    end do
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "V^2",       v2_calc (1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, zeta % name, zeta % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, f22  % name, f22  % n(1))
  end if

  ! Save vis and vis_t
  if(turbulence_model .eq. DES_SPALART .or.  &
     turbulence_model .eq. SPALART_ALLMARAS) then
    call Save_Vtu_Scalar(grid, IN_4, IN_5, vis % name, vis % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "VORT", vort(1))
  end if
  if(turbulence_model .eq. K_EPS                  .or.  &
     turbulence_model .eq. K_EPS_ZETA_F           .or.  &
     turbulence_model .eq. HYBRID_K_EPS_ZETA_F    .or.  &
     turbulence_model .eq. REYNOLDS_STRESS  .or.  &
     turbulence_model .eq. HANJALIC_JAKIRLIC      .or.  &
     turbulence_model .eq. LES                    .or.  &
     turbulence_model .eq. DES_SPALART            .or.  &
     turbulence_model .eq. SPALART_ALLMARAS) then
    kin_vis_t(1:grid % n_cells) = vis_t(1:grid % n_cells)/viscosity
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "VIS_T_to_VIS", &
      kin_vis_t(1))
  end if

  ! Reynolds stress models
  if(turbulence_model .eq. REYNOLDS_STRESS .or.  &
     turbulence_model .eq. HANJALIC_JAKIRLIC) then
    call Save_Vtu_Scalar(grid, IN_4, IN_5, uu % name, uu % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, vv % name, vv % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, ww % name, ww % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, uv % name, uv % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, uw % name, uw % n(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, vw % name, vw % n(1))
  end if

  ! Statistics for large-scale simulations of turbulence
  if(turbulence_model .eq. LES .or.  &
     turbulence_model .eq. DES_SPALART) then
    call Save_Vtu_Vector(grid, IN_4, IN_5, "UVW_MEAN",  &
                                u % mean(1), v % mean(1), w % mean(1))
    uu_mean = uu % mean(c) - u % mean(c) * u % mean(c)
    vv_mean = vv % mean(c) - v % mean(c) * v % mean(c)
    ww_mean = ww % mean(c) - w % mean(c) * w % mean(c)
    uv_mean = uv % mean(c) - u % mean(c) * v % mean(c)
    uw_mean = uw % mean(c) - u % mean(c) * w % mean(c)
    vw_mean = vw % mean(c) - v % mean(c) * w % mean(c)
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "UU_MEAN", uu_mean(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "VV_MEAN", uu_mean(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "WW_MEAN", uu_mean(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "UV_MEAN", uv_mean(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "UW_MEAN", uw_mean(1))
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "VW_MEAN", vw_mean(1))
    if(heat_transfer .eq. YES) then
      call Save_Vtu_Scalar(grid, IN_4, IN_5, "T_MEAN", t % mean(1))
      tt_mean = tt % mean(c) - t % mean(c) * t % mean(c)
      ut_mean = ut % mean(c) - u % mean(c) * t % mean(c)
      vt_mean = vt % mean(c) - v % mean(c) * t % mean(c)
      wt_mean = wt % mean(c) - w % mean(c) * t % mean(c)
      call Save_Vtu_Scalar(grid, IN_4, IN_5, "TT_MEAN", uu_mean(1))
      call Save_Vtu_Scalar(grid, IN_4, IN_5, "UT_MEAN", ut_mean(1))
      call Save_Vtu_Scalar(grid, IN_4, IN_5, "VT_MEAN", vt_mean(1))
      call Save_Vtu_Scalar(grid, IN_4, IN_5, "WT_MEAN", wt_mean(1))
    end if
  end if

  ! Save y+ for all turbulence models
  if(turbulence_model .ne. NONE) then
    call Save_Vtu_Scalar(grid, IN_4, IN_5, "Y_PLUS", y_plus(1))
  end if

  ! Wall distance and delta, important for all models
  call Save_Vtu_Scalar(grid, IN_4, IN_5, "WALL_DIST",  grid % wall_dist(1))
  call Save_Vtu_Scalar(grid, IN_4, IN_5, "CELL_DELTA", grid % delta(1))

  !-----------------------!
  !   Save user scalars   !
  !-----------------------!
  call User_Mod_Save_Vtu_Results(grid)

  !----------------------!
  !                      !
  !   End of cell data   !
  !                      !
  !----------------------!
  if(n_proc > 1 .and. this_proc .eq. 1) then
    write(8,'(a,a)') IN_3, '</PCellData>'
   end if
  write(9,'(a,a)') IN_3, '</CellData>'

  !------------!
  !            !
  !   Footer   !
  !            !
  !------------!
  if(n_proc > 1 .and. this_proc .eq. 1) then
    do n = 1, n_proc
      call Name_File(n, name_out_9, '.vtu')
      write(8, '(a,a,a,a)') IN_2, '<Piece Source="', trim(name_out_9), '"/>'
    end do
    write(8, '(a,a)') IN_1, '</PUnstructuredGrid>'
    write(8, '(a,a)') IN_0, '</VTKFile>'
    close(8)
  end if
  write(9,'(a,a)') IN_2, '</Piece>'
  write(9,'(a,a)') IN_1, '</UnstructuredGrid>'
  write(9,'(a,a)') IN_0, '</VTKFile>'
  close(9)

  ! Restore the name
  problem_name = store_name

  end subroutine