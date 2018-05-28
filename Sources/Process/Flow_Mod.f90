!==============================================================================!
  module Flow_Mod
!------------------------------------------------------------------------------!
!   Module for basic flow field plus temperature.                              !
!   It is a bit of a mumbo-jumbo at this moment, it will furhter have to       !
!   differentiate into numerical and physica parts.                            !
!------------------------------------------------------------------------------!
!----------------------------------[Modules]-----------------------------------!
  use Var_Mod
  use Bulk_Mod
  use Matrix_Mod
!------------------------------------------------------------------------------!
  implicit none
!==============================================================================!

  ! Velocity components
  type(Var_Type) :: u
  type(Var_Type) :: v
  type(Var_Type) :: w

  ! Temperature
  type(Var_Type) :: t

  ! Pressure 
  type(Var_Type) :: p  
  type(Var_Type) :: pp

  ! Mass fluxes throught cell faces
  real,allocatable :: flux(:) 

  ! Variables determining if we are dealing with heat transfer and buoyancy
  ! (both can be either YES or NO)
  integer :: heat_transfer
  integer :: buoyancy

  ! Geometrical staff 
  real,allocatable :: f_coef(:)  ! face coefficient
  real,allocatable :: fw(:)      ! weight factors for the fluid phase

  ! Right hand side for velocity and pressure equations 
  type(Matrix_Type) :: a  ! system matrix for all variables
  real, allocatable :: b(:)

  real,allocatable :: phi_face(:)

  ! For advection schemes
  real, allocatable :: phi_max(:), phi_min(:) 

  ! Mass fluxes, bulk velocities and pressure drops
  type(Bulk_Type) :: bulk(100)

  ! Physical properties
  real :: viscosity, density, conductivity, diffusivity, capacity

  ! Angular velocity 
  real :: omega_x, omega_y, omega_z, omega

  ! Reference temperature
  real :: t_ref, t_inf

  end module