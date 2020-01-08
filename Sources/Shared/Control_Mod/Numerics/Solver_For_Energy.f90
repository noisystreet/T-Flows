!==============================================================================!
  subroutine Control_Mod_Solver_For_Energy(val, verbose)
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  character(len=80) :: val
  logical, optional :: verbose
!==============================================================================!

  call Control_Mod_Read_Char_Item('SOLVER_FOR_ENERGY', 'cg',  &
                                   val, verbose)
  call To_Upper_Case(val)

  if( val.ne.'BICG' .and. val.ne.'CGS' .and. val.ne.'CG') then
    if(this_proc < 2) then
      print *, '# ERROR!  Unknown linear solver for energy: ', trim(val)
      print *, '# Exiting!'
    end if
    call Comm_Mod_End
  end if

  end subroutine