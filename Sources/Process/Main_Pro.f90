!==============================================================================!
  program Processor
!------------------------------------------------------------------------------!
!   Unstructured Finite Volume 'LES'/RANS solver.                              !
!------------------------------------------------------------------------------!
!---------------------------------[Modules]------------------------------------!
  use Name_Mod, only: problem_name
  use Const_Mod
  use Flow_Mod
  use Les_Mod
  use Comm_Mod
  use Rans_Mod
  use Tokenizer_Mod
  use Grid_Mod
  use Grad_Mod
  use Bulk_Mod
  use Var_Mod
  use Solvers_Mod, only: D
  use Info_Mod
  use User_Mod
  use Control_Mod
  use Monitor_Mod
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Calling]------------------------------------!
  real :: Correct_Velocity
!----------------------------------[Locals]------------------------------------!
  integer           :: i, m, n, us, c
  real              :: mass_res, wall_time_start, wall_time_current
  character(len=80) :: name_save
  logical           :: restart, save_now, exit_now
  type(Grid_Type)   :: grid        ! grid used in computations
  real              :: time        ! physical time
  real              :: dt          ! time step
  integer           :: first_dt    ! first time step in this run
  integer           :: last_dt     ! number of time steps
  integer           :: max_ini     ! max number of inner iterations
  integer           :: min_ini     ! min number of inner iterations
  integer           :: n_stat      ! starting time step for statistic
  integer           :: ini         ! inner iteration counter
  integer           :: bsi, rsi    ! backup and results save interval
  real              :: simple_tol  ! tolerance for SIMPLE algorithm
  character(len=80) :: coupling    ! pressure velocity coupling
!==============================================================================!

  ! Get starting time
  call cpu_time(wall_time_start)
  time =  0.

  !------------------------------!
  !   Start parallel execution   !
  !------------------------------!
  call Comm_Mod_Start

  !--------------------------------!
  !   Splash out the logo screen   !
  !--------------------------------!
  if(this_proc  < 2) then
    call Logo_Pro
  endif

  !---------------------------------------------!
  !   Open control file and read problem name   !
  !---------------------------------------------!
  call Control_Mod_Open_File()
  call Control_Mod_Problem_Name(problem_name)

  ! Load the finite volume grid
  call Load_Cns(grid, this_proc)

  call Allocate_Memory(grid)
  call Load_Geo       (grid, this_proc)
  call Comm_Mod_Load_Buffers
  call Comm_Mod_Load_Maps(grid)

  call Comm_Mod_Exchange(grid, grid % vol(-grid % n_bnd_cells))

  call Matrix_Mod_Topology(grid, a)
  call Matrix_Mod_Topology(grid, d)

  call Comm_Mod_Wait

  ! Get the number of time steps from the control file
  call Control_Mod_Number_Of_Time_Steps(last_dt, verbose=.true.)
  call Control_Mod_Starting_Time_Step_For_Statistics(n_stat, verbose=.true.)
 
  call Allocate_Variables(grid)

  call Load_Boundary_Conditions(grid, .false.)
  call Load_Physical_Properties(grid)

  ! First time step is one, unless read from restart otherwise
  first_dt = 0
  call Load_Backup(grid, first_dt, restart)

  ! Read physical models from control file
  call Read_Physical(grid, restart)

  ! Initialize variables
  if(.not. restart) then
    call Load_Boundary_Conditions(grid, .true.)
    call Load_Physical_Properties(grid)
    call Initialize_Variables(grid)
    call Comm_Mod_Wait
  end if

  ! Initialize monitor
  call Monitor_Mod_Initialize(grid, restart)

  ! Plane for calcution of overall mass fluxes
  do m = 1, grid % n_materials
    call Control_Mod_Point_For_Monitoring_Plane(bulk(m) % xp,  &
                                                bulk(m) % yp,  &
                                                bulk(m) % zp)
  end do

  ! Prepare ...
  call Calculate_Face_Geometry(grid)
  call Bulk_Mod_Monitoring_Planes_Areas(grid, bulk)
  call Grad_Mod_Find_Bad_Cells         (grid)

  if(turbulence_model .eq. LES                 .and.  &
     turbulence_model_variant .eq. SMAGORINSKY .and.  &
     .not. restart)                                  &
     call Find_Nearest_Wall_Cell(grid)

  ! Prepare the gradient matrix for velocities
  call Compute_Gradient_Matrix(grid, .true.)

  ! Prepare matrix for fractional step method
  call Control_Mod_Pressure_Momentum_Coupling(coupling)
  if(coupling .eq. 'PROJECTION') then
    call Pressure_Matrix_Fractional(grid, dt)
  end if

  ! Print the areas of monitoring planes
  if(this_proc < 2) then
    do m = 1, grid % n_materials
      write(*,'(a6,i2,a2,1pe12.3)') ' # Ax(',m,')=', bulk(m) % area_x
      write(*,'(a6,i2,a2,1pe12.3)') ' # Ay(',m,')=', bulk(m) % area_y
      write(*,'(a6,i2,a2,1pe12.3)') ' # Az(',m,')=', bulk(m) % area_z
    end do
  end if

  !---------------!
  !               !
  !   Time loop   !
  !               !
  !---------------!

  call Control_Mod_Time_Step(dt, verbose=.true.)
  call Control_Mod_Backup_Save_Interval(bsi, verbose=.true.)
  call Control_Mod_Results_Save_Interval(rsi, verbose=.true.)

  ! It will save results in .vtk or .cgns file format, 
  ! depending on how the code was compiled
  call Save_Results(grid, problem_name)

  do n = first_dt + 1, last_dt

    time = time + dt

    ! Beginning of time steo
    call User_Mod_Beginning_Of_Time_Step(grid, n, time)

    ! Start info boxes.
    call Info_Mod_Time_Start()
    call Info_Mod_Iter_Start()
    call Info_Mod_Bulk_Start()

    ! Initialize and print time info box
    call cpu_time(wall_time_current)
    call Info_Mod_Time_Fill( n, time, (wall_time_current-wall_time_start) )
    call Info_Mod_Time_Print()

    if(turbulence_model .eq. DES_SPALART) then
      call Calculate_Shear_And_Vorticity(grid)
      call Calculate_Vorticity (grid)
    end if

    if(turbulence_model .eq. LES) then
      call Calculate_Shear_And_Vorticity(grid)
      if(turbulence_model_variant .eq. DYNAMIC) call Calculate_Sgs_Dynamic(grid)
      if(turbulence_model_variant .eq. WALE)    call Calculate_Sgs_Wale(grid)
      call Calculate_Sgs(grid)
    end if

    If(turbulence_model .eq. HYBRID_K_EPS_ZETA_F) then
      call Calculate_Sgs_Dynamic(grid)
      call Calculate_Sgs_Hybrid(grid)
    end if

    call Convective_Outflow(grid, dt)
    if(turbulence_model .eq. REYNOLDS_STRESS .or.  &
       turbulence_model .eq. HANJALIC_JAKIRLIC) then
      call Calculate_Vis_T_Rsm(grid)
    end if

    !--------------------------!
    !   Inner-iteration loop   !
    !--------------------------!
    if(coupling .eq. 'PROJECTION') then
      max_ini = 1
    else
      call Control_Mod_Max_Simple_Iterations(max_ini)
      call Control_Mod_Min_Simple_Iterations(min_ini)
    end if

    do ini = 1, max_ini  !  PROJECTION & SIMPLE

      call Info_Mod_Iter_Fill(ini)

      call Grad_Mod_For_P(grid, p % n, p % x, p % y, p % z)

      ! Compute velocity gradients
      call Grad_Mod_For_Phi(grid, u % n, 1, u % x, .true.)
      call Grad_Mod_For_Phi(grid, u % n, 2, u % y, .true.)
      call Grad_Mod_For_Phi(grid, u % n, 3, u % z, .true.)
      call Grad_Mod_For_Phi(grid, v % n, 1, v % x, .true.)
      call Grad_Mod_For_Phi(grid, v % n, 2, v % y, .true.)
      call Grad_Mod_For_Phi(grid, v % n, 3, v % z, .true.)
      call Grad_Mod_For_Phi(grid, w % n, 1, w % x, .true.)
      call Grad_Mod_For_Phi(grid, w % n, 2, w % y, .true.)
      call Grad_Mod_For_Phi(grid, w % n, 3, w % z, .true.)

      ! u velocity component
      call Compute_Momentum(grid, dt, ini, u,          &
                  u % x,   u % y,   u % z,             &
                  grid % sx,   grid % sy,   grid % sz, &
                  grid % dx,   grid % dy,   grid % dz, &
                  p % x,   v % x,   w % x)      ! dP/dx, dV/dx, dW/dx

      ! v velocity component
      call Compute_Momentum(grid, dt, ini, v,          &
                  v % y,   v % x,   v % z,             &
                  grid % sy,   grid % sx,   grid % sz, &
                  grid % dy,   grid % dx,   grid % dz, &
                  p % y,   u % y,   w % y)      ! dP/dy, dU/dy, dW/dy

      ! w velocity component
      call Compute_Momentum(grid, dt, ini, w,          &
                  w % z,   w % x,   w % y,             &
                  grid % sz,   grid % sx,   grid % sy, &
                  grid % dz,   grid % dx,   grid % dy, &
                  p % z,   u % z,   v % z)      ! dP/dz, dU/dz, dV/dz

      if(coupling .eq. 'PROJECTION') then
        call Comm_Mod_Exchange(grid, a % sav)
        call Balance_Mass(grid)
        call Compute_Pressure_Fractional(grid, dt, ini)
      endif
      if(coupling .eq. 'SIMPLE') then
        call Comm_Mod_Exchange(grid, a % sav)
        call Balance_Mass(grid)
        call Compute_Pressure_Simple(grid, dt, ini)
      end if

      call Grad_Mod_For_P(grid,  pp % n, p % x, p % y, p % z)

      call Bulk_Mod_Compute_Fluxes(grid, bulk, flux)
      mass_res = Correct_Velocity(grid, dt, ini) !  project the velocities

      ! Temperature
      if(heat_transfer .eq. YES) then
        call Compute_Temperature(grid, dt, ini, t)
      end if

      ! User scalars
      do us = 1, n_user_scalars
        call User_Mod_Compute_Scalar(grid, dt, ini, user_scalar(us))
      end do

      ! Rans models
      if(turbulence_model .eq. K_EPS) then

        ! Update the values at boundaries
        call Update_Boundary_Values(grid)

        call Calculate_Shear_And_Vorticity(grid)

        call Compute_Turbulent(grid, dt, ini, kin, n)
        call Compute_Turbulent(grid, dt, ini, eps, n)

        call Calculate_Vis_T_K_Eps(grid)

        if(heat_transfer .eq. YES) then
          call Calculate_Heat_Flux(grid)
        end if
      end if

      if(turbulence_model .eq. K_EPS_ZETA_F     .or.  &
         turbulence_model .eq. HYBRID_K_EPS_ZETA_F) then
        call Calculate_Shear_And_Vorticity(grid)

        call Compute_Turbulent(grid, dt, ini, kin, n)
        call Compute_Turbulent(grid, dt, ini, eps, n)
        call Update_Boundary_Values(grid)

        call Compute_F22(grid, ini, f22)
        call Compute_Turbulent(grid, dt, ini, zeta, n)

        call Calculate_Vis_T_K_Eps_Zeta_F(grid)

        if(heat_transfer .eq. YES) then
          call Calculate_Heat_Flux(grid)
        end if
      end if

      if(turbulence_model .eq. REYNOLDS_STRESS .or.  &
         turbulence_model .eq. HANJALIC_JAKIRLIC) then

        ! Update the values at boundaries
        call Update_Boundary_Values(grid)

        if(turbulence_model .eq. REYNOLDS_STRESS) then
          call Time_And_Length_Scale(grid)
        end if

        call Grad_Mod_For_Phi(grid, u % n, 1, u % x,.true.)    ! dU/dx
        call Grad_Mod_For_Phi(grid, u % n, 2, u % y,.true.)    ! dU/dy
        call Grad_Mod_For_Phi(grid, u % n, 3, u % z,.true.)    ! dU/dz

        call Grad_Mod_For_Phi(grid, v % n, 1, v % x,.true.)    ! dV/dx
        call Grad_Mod_For_Phi(grid, v % n, 2, v % y,.true.)    ! dV/dy
        call Grad_Mod_For_Phi(grid, v % n, 3, v % z,.true.)    ! dV/dz

        call Grad_Mod_For_Phi(grid, w % n, 1, w % x,.true.)    ! dW/dx
        call Grad_Mod_For_Phi(grid, w % n, 2, w % y,.true.)    ! dW/dy
        call Grad_Mod_For_Phi(grid, w % n, 3, w % z,.true.)    ! dW/dz

        call Compute_Stresses(grid, dt, ini, uu)
        call Compute_Stresses(grid, dt, ini, vv)
        call Compute_Stresses(grid, dt, ini, ww)

        call Compute_Stresses(grid, dt, ini, uv)
        call Compute_Stresses(grid, dt, ini, uw)
        call Compute_Stresses(grid, dt, ini, vw)

        if(turbulence_model .eq. REYNOLDS_STRESS) then
          call Compute_F22(grid, ini, f22)
        end if

        call Compute_Stresses(grid, dt, ini, eps)

        call Calculate_Vis_T_Rsm(grid)

        if(heat_transfer .eq. YES) then
          call Calculate_Heat_Flux(grid)
        end if
      end if

      if(turbulence_model .eq. SPALART_ALLMARAS .or.  &
         turbulence_model .eq. DES_SPALART) then
        call Calculate_Shear_And_Vorticity(grid)
        call Calculate_Vorticity(grid)

        ! Update the values at boundaries
        call Update_Boundary_Values(grid)

        call Compute_Turbulent(grid, dt, ini, vis, n)
        call Calculate_Vis_T_Spalart_Allmaras(grid)
      end if

      ! Update the values at boundaries
      call Update_Boundary_Values(grid)

      ! End of the current iteration
      call Info_Mod_Iter_Print()

      if(ini >= min_ini) then
        if(coupling .eq. 'SIMPLE') then
          call Control_Mod_Tolerance_For_Simple_Algorithm(simple_tol)
          if( u  % res <= simple_tol .and.  &
              v  % res <= simple_tol .and.  &
              w  % res <= simple_tol .and.  &
              mass_res <= simple_tol ) goto 1
        endif
      endif
    end do

    ! End of the current time step
1   call Info_Mod_Bulk_Print()

    ! Write the values in monitoring points
    if(heat_transfer .eq. NO) then
      call Monitor_Mod_Write_4_Vars(n, u, v, w, p)
    else
      call Monitor_Mod_Write_5_Vars(n, u, v, w, t, p)
    end if
 
    ! Calculate mean values
    call Calculate_Mean(grid, n_stat, n) 

    call User_Mod_Calculate_Mean(grid, n_stat, n)
    
    !-----------------------------------------------------!
    !   Recalculate the pressure drop                     !
    !   to keep the constant mass flux                    !
    !                                                     !
    !   First Newtons law:                                !
    !                                                     !
    !   F = m * a                                         !
    !                                                     !
    !   where:                                            !
    !                                                     !
    !   a = dv / dt = dFlux / dt * 1 / (A * rho)          !
    !   m = rho * v                                       !
    !   F = Pdrop * l * A = Pdrop * v                     !
    !                                                     !
    !   finally:                                          !
    !                                                     !
    !   Pdrop * v = rho * v * dFlux / dt * 1 / (A * rho)  !
    !                                                     !
    !   after cancelling: v and rho, it yields:           !
    !                                                     !
    !   Pdrop = dFlux/dt/A                                !
    !-----------------------------------------------------!
    do m = 1, grid % n_materials
      if( abs(bulk(m) % flux_x_o) >= TINY ) then
        bulk(m) % p_drop_x = (bulk(m) % flux_x_o - bulk(m) % flux_x)  &
                           / (dt * bulk(m) % area_x + TINY)
      end if
      if( abs(bulk(m) % flux_y_o) >= TINY ) then
        bulk(m) % p_drop_y = (bulk(m) % flux_y_o - bulk(m) % flux_y)  &
                           / (dt * bulk(m) % area_y + TINY)
      end if
      if( abs(bulk(m) % flux_z_o) >= TINY ) then
        bulk(m) % p_drop_z = (bulk(m) % flux_z_o - bulk(m) % flux_z)  &
                           / (dt * bulk(m) % area_z + TINY)
      end if
    end do

    !----------------------!
    !   Save the results   !
    !----------------------!
    inquire(file='exit_now', exist=exit_now)
    inquire(file='save_now', exist=save_now)

    ! Form the file name
    name_save = problem_name
    write(name_save(len_trim(problem_name)+1:                    &
                    len_trim(problem_name)+3), '(a3)')   '-ts'
    write(name_save(len_trim(problem_name)+4:                    &
                    len_trim(problem_name)+9), '(i6.6)') n

    ! Is it time to save the restart file?
    if(save_now .or. exit_now .or. mod(n,bsi) .eq. 0) then
      call Save_Backup (grid, n, name_save)
    end if

    ! Is it time to save results for post-processing
    if(save_now .or. exit_now .or. mod(n,rsi) .eq. 0) then
      call Comm_Mod_Wait
      call Save_Results(grid, name_save)

      ! Write results in user-customized format
      call User_Mod_Save_Results(grid, name_save)
    end if

    ! Just before the end of time step
    call User_Mod_End_Of_Time_Step(grid, n, time)

    if(save_now) then
      open (9, file='save_now', status='old')
      close(9, status='delete')
    end if

    if(exit_now) then
      open (9, file='exit_now', status='old')
      close(9, status='delete')
      goto 2
    end if

  end do ! n, number of time steps

  if(this_proc < 2) then
    open(9, file='stop')
    close(9)
  end if

2 if(this_proc  < 2) print *, '# Exiting !'

  ! Close monitoring files
  call Monitor_Mod_Finalize

  ! Make the final call to user function
  call User_Mod_Before_Exit(grid)

  !----------------------------!
  !   End parallel execution   !
  !----------------------------!
  call Comm_Mod_End

  end program