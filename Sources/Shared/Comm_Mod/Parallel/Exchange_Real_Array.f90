!==============================================================================!
  subroutine Comm_Mod_Exchange_Real_Array(phi, length, dest)
!------------------------------------------------------------------------------!
!   Exchanges the values of a real array between the processors.               !
!------------------------------------------------------------------------------!
  implicit none
!---------------------------------[Arguments]----------------------------------!
  real    :: phi(length)
  integer :: length
  integer :: dest         ! destination processor
!-----------------------------------[Locals]-----------------------------------!
  integer :: rtag, stag, error
  integer :: status(MPI_STATUS_SIZE)
!==============================================================================!

  ! Form send and receive tags
  stag = (n_proc) * this_proc + dest  ! tag for sending
  rtag = (n_proc) * dest + this_proc  ! tag for receiving

  call Mpi_Sendrecv_Replace(phi(1),                & ! buffer
                            length,                & ! length
                            MPI_DOUBLE_PRECISION,  & ! datatype
                            (dest-1),              & ! dest,
                            stag,                  & ! sendtag,
                            (dest-1),              & ! source,
                            rtag,                  & ! recvtag,
                            MPI_COMM_WORLD,        &
                            status,                &
                            error)

  end subroutine
