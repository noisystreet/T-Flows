!==============================================================================!
  subroutine Swap_Real(a, b)
!------------------------------------------------------------------------------!
!   Swaps two real numbers.                                                    !
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  integer :: a, b
!-----------------------------------[Locals]-----------------------------------!
  integer :: t
!==============================================================================!

  t = a
  a = b
  b = t

  end subroutine
