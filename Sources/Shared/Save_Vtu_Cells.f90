!==============================================================================!
  subroutine Save_Vtu_Cells(grid, sub, n_nodes_sub, n_cells_sub)
!------------------------------------------------------------------------------!
! Writes: name.vtu, name.faces.vtu, name.shadow.vtu                            !
!----------------------------------[Modules]-----------------------------------!
  use gen_mod, only: new_n, new_c
  use Div_Mod, only: n_sub
  use Grid_Mod
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
  integer         :: sub, n_nodes_sub, n_cells_sub
!-----------------------------------[Locals]-----------------------------------!
  integer            :: c, n, offset
  character(len=80)  :: name_out
!------------------------------[Local parameters]------------------------------!
  integer,           parameter :: VTK_TETRA      = 10  ! cells in VTK format
  integer,           parameter :: VTK_HEXAHEDRON = 12  
  integer,           parameter :: VTK_WEDGE      = 13
  integer,           parameter :: VTK_PYRAMID    = 14
  character(len= 0), parameter :: IN_0 = ''            ! indentation levels 
  character(len= 2), parameter :: IN_1 = '  '
  character(len= 4), parameter :: IN_2 = '    '
  character(len= 6), parameter :: IN_3 = '      '
  character(len= 8), parameter :: IN_4 = '        '
  character(len=10), parameter :: IN_5 = '          '
!==============================================================================!

  !----------------------!
  !                      !
  !   Create .vtu file   !
  !                      !
  !----------------------!
  call Name_File(sub, name_out, '.vtu')
  open(9, file=name_out)
  print *, '# Creating the file: ', trim(name_out)

  !-----------!
  !   Start   !
  !-----------!
  write(9,'(a,a)') IN_0, '<?xml version="1.0"?>'
  write(9,'(a,a)') IN_0, '<VTKFile type="UnstructuredGrid" version="0.1" ' //  &
                         'byte_order="LittleEndian">'
  write(9,'(a,a)') IN_1, '<UnstructuredGrid>'
  write(9,'(a,a,i0.0,a,i0.0,a)')   &
                   IN_2, '<Piece NumberOfPoints="', n_nodes_sub,      &
                              '" NumberOfCells ="', n_cells_sub, '">'

  !-----------!
  !   Nodes   !
  !-----------!
  write(9,'(a,a)') IN_3, '<Points>'
  write(9,'(a,a)') IN_4, '<DataArray type="Float32" NumberOfComponents' //  &
                         '="3" format="ascii">'
  do n = 1, grid % n_nodes
    if(new_n(n) /= 0) write(9, '(a,1pe15.7,1pe15.7,1pe15.7)')                &
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
    if(new_c(c) /= 0) then

      ! Hexahedral
      if(grid % cells_n_nodes(c) .eq. 8) then
        write(9,'(a,8i9)')                                           &
          IN_5,                                                      &
          new_n(grid % cells_n(1,c))-1, new_n(grid % cells_n(2,c))-1,  &
          new_n(grid % cells_n(4,c))-1, new_n(grid % cells_n(3,c))-1,  &
          new_n(grid % cells_n(5,c))-1, new_n(grid % cells_n(6,c))-1,  &
          new_n(grid % cells_n(8,c))-1, new_n(grid % cells_n(7,c))-1

      ! Wedge       
      else if(grid % cells_n_nodes(c) .eq. 6) then
        write(9,'(a,6i9)')                                           &
          IN_5,                                                      &
          new_n(grid % cells_n(1,c))-1, new_n(grid % cells_n(2,c))-1,  &
          new_n(grid % cells_n(3,c))-1, new_n(grid % cells_n(4,c))-1,  &
          new_n(grid % cells_n(5,c))-1, new_n(grid % cells_n(6,c))-1

      ! Tetrahedra  
      else if(grid % cells_n_nodes(c) .eq. 4) then
        write(9,'(a,4i9)')                                           &
          IN_5,                                                      &
          new_n(grid % cells_n(1,c))-1, new_n(grid % cells_n(2,c))-1,  &
          new_n(grid % cells_n(3,c))-1, new_n(grid % cells_n(4,c))-1

      ! Pyramid     
      else if(grid % cells_n_nodes(c) .eq. 5) then
        write(9,'(a,5i9)')                                           &
          IN_5,                                                      &
          new_n(grid % cells_n(1,c))-1, new_n(grid % cells_n(2,c))-1,  &
          new_n(grid % cells_n(4,c))-1, new_n(grid % cells_n(3,c))-1,  &
          new_n(grid % cells_n(5,c))-1
      else
        print *, '# Unsupported cell type with ',  &
                    grid % cells_n_nodes(c), ' nodes.'
        print *, '# Exiting'
        stop 
      end if
    end if
  end do  
  write(9,'(a,a)') IN_4, '</DataArray>'

  ! Now write all cells' offsets
  write(9,'(a,a)') IN_4, '<DataArray type="Int32" Name="offsets" format="ascii">'
  offset = 0
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      offset = offset + grid % cells_n_nodes(c)
      write(9,'(a,i9)') IN_5, offset
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'
 
  ! Now write all cells' types
  write(9,'(a,a)') IN_4, '<DataArray type="UInt8" Name="types" format="ascii">'
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      if(grid % cells_n_nodes(c) .eq. 4) write(9,'(a,i9)') IN_5, VTK_TETRA
      if(grid % cells_n_nodes(c) .eq. 8) write(9,'(a,i9)') IN_5, VTK_HEXAHEDRON
      if(grid % cells_n_nodes(c) .eq. 6) write(9,'(a,i9)') IN_5, VTK_WEDGE
      if(grid % cells_n_nodes(c) .eq. 5) write(9,'(a,i9)') IN_5, VTK_PYRAMID
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'
  write(9,'(a,a)') IN_3, '</Cells>'
 
  !---------------!
  !   Cell data   !
  !---------------!
  write(9,'(a,a)') IN_3, '<CellData Scalars="scalars" vectors="velocity">'

  ! Materials
  write(9,'(a,a)') IN_4, '<DataArray type="UInt8" Name="materials" format="ascii">'
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      write(9,'(a,i9)') IN_5, grid % material(c)
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'

  ! Wall distance
  write(9,'(a,a)') IN_4, '<DataArray type="Float32" Name="wall distance" format="ascii">'
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      write(9,'(a,1pe15.7)') IN_5, grid % wall_dist(c)
    end if
  end do
  write(9,'(a,a)') IN_4, '</DataArray>'

  !------------!
  !   Footer   !
  !------------!
  write(9,'(a,a)') IN_3, '</CellData>'
  write(9,'(a,a)') IN_2, '</Piece>'
  write(9,'(a,a)') IN_1, '</UnstructuredGrid>'
  write(9,'(a,a)') IN_0, '</VTKFile>'

  close(9)

  !-----------------------!
  !                       !
  !   Create .pvtu file   !
  !                       !
  !-----------------------!

  ! Create it only from subdomain 1, when decomposed
  if(n_sub > 1 .and. sub .eq. 1) then

    call Name_File(0, name_out, '.pvtu')
    print *, '# Creating the file: ', trim(name_out)
    open(9, file = name_out)
  
    ! Header
    write(9,'(a,a)') IN_0, '<?xml version="1.0"?>'
    write(9,'(a,a)') IN_0, '<VTKFile type="PUnstructuredGrid">'
    write(9,'(a,a)') IN_1, '<PUnstructuredGrid GhostLevel="0">'

    ! This section must be present
    write(9,'(a,a)') IN_2, '<PPoints>'
    write(9,'(a,a)') IN_3, '<PDataArray type="Float32" NumberOfComponents=' // &
                           '"3" format="ascii"/>'
    write(9,'(a,a)') IN_2, '</PPoints>'

    ! Data section is not mandatory, but very useful
    write(9,'(a,a)') IN_2, '<PCellData Scalars="scalars" vectors="velocity">'
    write(9,'(a,a)') IN_3, '<PDataArray type="UInt8" Name="materials"' // &
                           ' format="ascii"/>'
    write(9,'(a,a)') IN_2, '</PCellData>'

    ! Write out the names of all the pieces
    do n = 1, n_sub
      call Name_File(n, name_out, '.vtu')
      write(9, '(a,a,a,a)') IN_2, '<Piece Source="', trim(name_out), '"/>'
    end do

    ! Footer
    write(9, '(a)') IN_1, '</PUnstructuredGrid>'
    write(9, '(a)') IN_0, '</VTKFile>'

    close(9)

  end if

  end subroutine