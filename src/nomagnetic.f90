module Magnetic

  use Cparam

  implicit none

  integer :: iaa
  real :: fring1,Iring1,Rring1,wr1,nr1x,nr1y,nr1z,r1x,r1y,r1z
  real :: fring2,Iring2,Rring2,wr2,nr2x,nr2y,nr2z,r2x,r2y,r2z

  contains

!***********************************************************************
    subroutine register_aa()
!
!  Initialise variables which should know that we solve for the vector
!  potential: iaa, etc; increase nvar accordingly
!  3-may-2002/wolf: dummy routine
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_aa called twice')
      first = .false.
!
      lmagnetic = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$RCSfile: nomagnetic.f90,v $", &
           "$Revision: 1.1 $", &
           "$Date: 2002-05-03 15:27:43 $")
!
    endsubroutine register_aa
!***********************************************************************
    subroutine init_aa(f,init,ampl,xx,yy,zz)
!
!  initialise magnetic field; called from start.f90
!  3-may-2002/wolf: dummy routine
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mvar) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz
      real    :: ampl
      integer :: init
!
    endsubroutine init_aa
!***********************************************************************
    subroutine daa_dt(f,df,uu,rho1,TT1,cs2)
!
!  magnetic field evolution
!  3-may-2002/wolf: dummy routine
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mvar) :: f,df
      real, dimension (nx,3) :: uu
      real, dimension (nx) :: rho1,TT1,cs2
!
    endsubroutine daa_dt
!***********************************************************************

endmodule Magnetic
