!==============================================================================!
  subroutine Save_Cns_Geo(grid,             &
                          sub,              &  ! subdomain
                          n_nodes_sub,      &  ! number of nodes in the sub. 
                          n_cells_sub,      &  ! number of cells in the sub. 
                          n_faces_sub,      &  ! number of faces in the sub.
                          n_bnd_cells_sub,  &  ! number of bnd. cells in sub
                          n_buf_cells_sub,  &  ! number of buffer cells in sub.
                          NCFsub)
!------------------------------------------------------------------------------!
!   Writes: name.cns, name.geo                                                 !
!----------------------------------[Modules]-----------------------------------!
  use gen_mod
  use Div_Mod
  use Grid_Mod
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  type(Grid_Type) :: grid
  integer         :: sub, n_nodes_sub, n_cells_sub, n_faces_sub,  &
                     n_bnd_cells_sub,  n_buf_cells_sub, NCFsub
!-----------------------------------[Locals]-----------------------------------!
  integer              :: b, c, s, n, c1, c2, count, var, subo 
  integer              :: lower_bound, upper_bound
  character(len=80)    :: name_out
  integer, allocatable :: iwork(:,:)
  real, allocatable    :: work(:)
!==============================================================================!
!   The files name.cns and name.geo should merge into one file in some         !
!   of the future releases.                                                    !
!                                                                              !
!   sub             - subdomain number                                         !
!   n_nodes_sub     - number of nodes in subdomain                             !
!   n_cells_sub     - number of cells in subdomain                             !
!   n_faces_sub     - number of sides in subdomain, but without sides on buffer!
!   n_bnd_cells_sub - number of physicall boundary cells in subdomain          !
!   n_buf_cells_sub - number of buffer boundary faces in subdomain             !
!------------------------------------------------------------------------------!

  lower_bound = min(-n_buf_cells_sub, -grid % n_bnd_cells)
  upper_bound = max(grid % n_cells*8, grid % n_faces*4)

  allocate(iwork(lower_bound:upper_bound, 0:2));  iwork=0
  allocate(work(grid % n_faces));                 work=0.

  !----------------------!
  !                      !
  !   Create .cns file   !
  !                      !
  !----------------------!
  call Name_File( sub, name_out, '.cns' )
  open(9, file=name_out,form='unformatted')
  write(*, *) '# Creating the file: ', trim(name_out)

  !-----------------------------------------------!
  !   Number of cells, boundary cells ans sides   !
  !-----------------------------------------------!
  write(9) n_nodes_sub
  write(9) n_cells_sub
  write(9) n_bnd_cells_sub+n_buf_cells_sub 
  write(9) n_faces_sub+n_buf_cells_sub-NCFsub
  write(9) grid % n_sh  ! not sure how meaningful this is
  write(9) grid % n_materials
  write(9) grid % n_bnd_cond

  !---------------! 
  !   Materials   !
  !---------------! 
  do n = 1, grid % n_materials
    write(9) grid % materials(n) % name
  end do

  !-------------------------! 
  !   Boundary conditions   !
  !-------------------------! 
  do n = 1, grid % n_bnd_cond
    write(9) grid % bnd_cond % name(n)
  end do

  !-----------! 
  !   Cells   ! 
  !-----------! 

  ! Number of nodes for each cell
  count=0
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      count=count+1
      iwork(count,1) = grid % cells_n_nodes(c)
    end if
  end do 
  write(9) (iwork(c,1), c=1,count)

  ! Cells' nodes
  count=0
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      do n = 1, grid % cells_n_nodes(c)
        count=count+1
        iwork(count,1) = new_n(grid % cells_n(n,c))
      end do
    end if
  end do 
  write(9) (iwork(c,1), c=1,count)

  ! Cells' materials inside the domain
  count=0
  do c = 1, grid % n_cells
    if(new_c(c) /= 0) then
      count=count+1
      iwork(count,1) = grid % material(c)
    end if
  end do 
  write(9) (iwork(c,1), c=1,count)

  ! Materials on physicall boundary cells
  count=0
  do c = -1,-grid % n_bnd_cells, -1
    if(new_c(c) /= 0) then
      count=count+1
      iwork(count,1) = grid % material(c)
    end if
  end do

  ! Buffer boundary cell centers
  do s = 1, n_buf_cells_sub
    count=count+1
    iwork(count,1) = grid % material(buf_recv_ind(s))
  end do
  write(9) (iwork(c,1), c=1,count)
                      
  !-----------! 
  !   Faces   ! 
  !-----------!

  ! Number of nodes for each face
  count=0
  do s = 1, grid % n_faces
    if(new_f(s) /= 0) then
      count=count+1
      iwork(count,1) = grid % faces_n_nodes(s)
    end if
  end do 
  write(9) (iwork(s,1), s=1,count)

  ! Faces' nodes
  count=0
  do s = 1, grid % n_faces
    if(new_f(s) /= 0) then
      do n = 1, grid % faces_n_nodes(s)
        count=count+1
        iwork(count,1) = new_n(grid % faces_n(n,s))
      end do
    end if
  end do 
  write(9) (iwork(s,1), s=1,count)

  count=0

  ! n_faces_sub physical faces
  do s = 1, grid % n_faces  ! OK, later chooses just sides with new_f
    if( new_f(s)  > 0  .and.  new_f(s) <= n_faces_sub ) then
      count=count+1 
      iwork(count,0) = 0 
      iwork(count,1) = new_c(grid % faces_c(1,s))
      iwork(count,2) = new_c(grid % faces_c(2,s))
    end if
  end do 

  ! n_buf_cells_sub buffer faces (copy faces here, avoid them with buf_pos) 
  do s = 1, n_buf_cells_sub
    if(buf_pos(s) < 0) then             ! normal buffer (non-copy) 
      count=count+1 
      iwork(count,0) = buf_recv_ind(s)  ! old cell number
      iwork(count,1) = buf_send_ind(s)  ! new cell number
      iwork(count,2) = buf_pos(s)       ! position in the buffer
    end if
  end do 

 !write(9) (iwork(s,0), s=1,count) why is it OK to neglect this?
  write(9) (iwork(s,1), s=1,count)
  write(9) (iwork(s,2), s=1,count)

  !--------------! 
  !   Boundary   !
  !--------------! 
  count=0          ! count goes to negative

  ! n_bnd_cells_sub physical boundary cells
  do c = -1,-grid % n_bnd_cells,-1  ! OK, later chooses just cells with new_c
    if(new_c(c) /= 0) then
      count=count-1 
      ! nekad bio i: new_c(c)
      iwork(count,1) = grid % bnd_cond % color(c)   
      iwork(count,2) = new_c(grid % bnd_cond % copy_c(c)) 
      if(grid % bnd_cond % copy_c(c) /= 0) then
        if(proces(grid % bnd_cond % copy_c(c)) /= sub) then
          do b=1,n_buf_cells_sub
            if(buf_recv_ind(b) .eq. grid % bnd_cond % copy_c(c)) then
              print *, buf_pos(b) 
              print *, grid % xc(grid % bnd_cond % copy_c(c)),  &
                       grid % yc(grid % bnd_cond % copy_c(c)),  &
                       grid % zc(grid % bnd_cond % copy_c(c))  
              iwork(count,2)=-buf_pos(b) ! - sign, copy buffer
            end if
          end do
        endif
      endif
    end if
  end do 

  ! n_buf_cells_sub buffer cells
  do c = 1, n_buf_cells_sub
    count=count-1 
    ! nekad bio i: -n_bnd_cells_sub-c, 
    iwork(count,1) = BUFFER 
    iwork(count,2) = 0        ! hmm ? unused ? hmm ?
  end do 

  write(9) (iwork(c,1), c=-1,count,-1)
  write(9) (iwork(c,2), c=-1,count,-1)

  !----------!
  !   Copy   !
  !----------!
  count = 0
  do s = 1, grid % n_copy
    count = count + 1
    iwork(count,1) = grid % bnd_cond % copy_s(1,s) 
    iwork(count,2) = grid % bnd_cond % copy_s(2,s) 
  end do

  write(9) count 
  write(9) (iwork(c,1), c=1,count)
  write(9) (iwork(c,2), c=1,count)

  close(9)

  !----------------------!
  !                      !
  !   Create .geo file   !
  !                      !
  !----------------------!
  call Name_File( sub, name_out, '.geo' )
  open(9, file=name_out, form='unformatted')
  write(*, *) '# Creating the file: ', trim(name_out)

  !----------------------!
  !   Node coordinates   !
  !----------------------!
  do var = 1, 3
    count=0
    do n=1,grid % n_nodes
      if(new_n(n)  > 0) then
        count=count+1
        if(var .eq. 1) work(count) = grid % xn(n)
        if(var .eq. 2) work(count) = grid % yn(n)
        if(var .eq. 3) work(count) = grid % zn(n)
      end if
    end do 
    write(9) (work(n), n=1,count)
  end do

  !-----------------------------!
  !   Cell center coordinates   !
  !-----------------------------!
  do var = 1, 3
    count=0
    do c=1,grid % n_cells
      if(new_c(c)  > 0) then
        count=count+1
        if(var .eq. 1) work(count) = grid % xc(c)
        if(var .eq. 2) work(count) = grid % yc(c)
        if(var .eq. 3) work(count) = grid % zc(c)
      end if
    end do 
    write(9) (work(c), c=1,count)
  end do

  !---------------------------!
  !   Boundary cell centers   !
  !---------------------------!

  ! Physicall cells
  do var = 1, 3
    count=0
    do c = -1, -grid % n_bnd_cells, -1
      if(new_c(c) /= 0) then
        count=count+1
        if(var .eq. 1) work(count) = grid % xc(c)
        if(var .eq. 2) work(count) = grid % yc(c)
        if(var .eq. 3) work(count) = grid % zc(c)
      end if
    end do 

    ! Buffer boundary cell centers
    do s = 1, n_buf_cells_sub
      count=count+1
      if(var .eq.  1) work(count) = grid % xc(buf_recv_ind(s))
      if(var .eq.  2) work(count) = grid % yc(buf_recv_ind(s))
      if(var .eq.  3) work(count) = grid % zc(buf_recv_ind(s))
    end do
    write(9) (work(c), c=1,count)
  end do

  !------------------!
  !   Cell volumes   !
  !------------------!
  count=0
  do c = 1, grid % n_cells
    if(new_c(c)  > 0) then
      count=count+1
      work(count) = grid % vol(c)
    end if
  end do
  write(9) (work(c), c=1,count) 

  !---------------!
  !   Cell data   !
  !---------------!
  count=0
  do c = 1, grid % n_cells
    if(new_c(c)  > 0) then
      count=count+1
      work(count) = grid % delta(c)
    end if
  end do
  write(9) (work(c), c=1,count) 

  !-------------------!
  !   Wall distance   !
  !-------------------!
  count=0
  do c = 1, grid % n_cells
    if(new_c(c)  > 0) then
      count=count+1
      work(count) = grid % wall_dist(c)
    end if
  end do
  write(9) (work(c), c=1,count) 

  !-----------!
  !   Faces   !
  !-----------!

  ! From 1 to n_faces_sub -> cell faces for which both cells are inside sub
  do var=1,10
  count=0

  do s = 1, grid % n_faces
    if(new_f(s)  > 0 .and. new_f(s) <= n_faces_sub) then
      count=count+1
      if(var .eq.  1)  work(count) = grid % sx(s)
      if(var .eq.  2)  work(count) = grid % sy(s)
      if(var .eq.  3)  work(count) = grid % sz(s)
      if(var .eq.  4)  work(count) = grid % dx(s)
      if(var .eq.  5)  work(count) = grid % dy(s)
      if(var .eq.  6)  work(count) = grid % dz(s)
      if(var .eq.  7)  work(count) = grid % f(s)
      if(var .eq.  8)  work(count) = grid % xf(s)
      if(var .eq.  9)  work(count) = grid % yf(s)
      if(var .eq. 10)  work(count) = grid % zf(s)
    end if 
  end do

  ! From n_faces_sub+1 to n_faces_sub + n_buf_cells_sub 
  ! (think: are they in right order ?)
  do subo = 1, n_sub
    do s = 1, grid % n_faces
      if(new_f(s)  > n_faces_sub .and.  &
         new_f(s) <= n_faces_sub + n_buf_cells_sub) then
        c1 = grid % faces_c(1,s)
        c2 = grid % faces_c(2,s)
        if(c2  > 0) then
          if( (proces(c1) .eq. sub) .and. (proces(c2) .eq. subo) ) then 
            count=count+1
            if(var .eq.  1)  work(count) = grid % sx(s)
            if(var .eq.  2)  work(count) = grid % sy(s)
            if(var .eq.  3)  work(count) = grid % sz(s)
            if(var .eq.  4)  work(count) = grid % dx(s)
            if(var .eq.  5)  work(count) = grid % dy(s)
            if(var .eq.  6)  work(count) = grid % dz(s)
            if(var .eq.  7)  work(count) = grid % f(s)
            if(var .eq.  8)  work(count) = grid % xf(s)
            if(var .eq.  9)  work(count) = grid % yf(s)
            if(var .eq. 10)  work(count) = grid % zf(s)
          end if  
          if( (proces(c2) .eq. sub) .and. (proces(c1) .eq. subo) ) then 
            count=count+1
            if(var .eq.  1)  work(count) = -grid % sx(s)
            if(var .eq.  2)  work(count) = -grid % sy(s)
            if(var .eq.  3)  work(count) = -grid % sz(s)
            if(var .eq.  4)  work(count) = -grid % dx(s)
            if(var .eq.  5)  work(count) = -grid % dy(s)
            if(var .eq.  6)  work(count) = -grid % dz(s)
            if(var .eq.  7)  work(count) = 1.0 - grid % f(s)
            if(var .eq.  8)  work(count) = grid % xf(s) - grid % dx(s)
            if(var .eq.  9)  work(count) = grid % yf(s) - grid % dy(s)
            if(var .eq. 10)  work(count) = grid % zf(s) - grid % dz(s)
          end if  
        end if  ! c2 > 0 
      end if    ! I think this is not really necessary 
    end do
  end do

  write(9) (work(s),s=1,count)

  end do

  close(9)

  deallocate (iwork)
  deallocate (work)

  end subroutine