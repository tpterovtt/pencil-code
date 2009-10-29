! $Id: particles_viscosity.f90 10506 2009-03-19 12:42:20Z ajohan@strw.leidenuniv.nl $
!
!  This modules takes care of instantaneous collisions between
!  superparticles.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_collisions = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************
module Particles_collisions
!
  use Cparam
  use Cdata
  use Messages
  use Particles_cdata
  use Particles_sub
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'particles_collisions.h'
!
  real :: lambda_mfp_single=1.0, coeff_restitution=1.0
  integer :: ncoll_max_par=-1
  logical :: lcollision_random_angle=.false., lcollision_big_ball=.false.
  logical :: lshear_in_vp=.true.
  character (len=labellen) :: icoll='random-angle'
!
  integer :: idiag_ncoll
!
  namelist /particles_coll_run_pars/ &
      lambda_mfp_single, coeff_restitution, icoll, lshear_in_vp, &
      ncoll_max_par
!
  contains
!***********************************************************************
    subroutine initialize_particles_collisions(f,lstarting)
!
!  07-oct-08/anders: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      logical, intent(in) :: lstarting
!
      select case(icoll)
      case ('random-angle'); lcollision_random_angle=.true.
      case ('big-ball');     lcollision_big_ball=.true.
      case default
        if (lroot) print*, 'No such value for icoll: ', trim(icoll)
        call fatal_error('initialize_particles_collisions','')
      endselect
!
      allocate(kneighbour(mpar_loc))
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(lstarting)
!
    endsubroutine initialize_particles_collisions
!***********************************************************************
    subroutine calc_particles_collisions(fp,ineargrid)
!
!  Calculate collisions between superparticles by comparing the collision
!  time-scale to the time-step. A random number is used to determine
!  whether two superparticles collide in this time-step.
!
!  Collisions change the velocity vectors of the colliding particles
!  instantaneously.
!
!  23-mar-09/anders: coded
!
      use Diagnostics
      use General
      use Sub
!
      real, dimension (mpar_loc,mpvar) :: fp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      real, dimension (3) :: xpj, xpk, vpj, vpk, vvcm, vvkcm, vvkcmnew
      real, dimension (3) :: nvec, vvkcm_normal, vvkcm_parall
      real, dimension (3) :: tmp1, tmp2
      real :: deltavjk, tau_coll1, prob, r, theta_rot, phi_rot, ncoll
      integer :: l, j, k, ncoll_par
!
!  Reset collision counter.
!
      ncoll=0.0
!
!  Pencil loop.
!
      do imn=1,ny*nz
!
!  Create list of shepherd and neighbour particles for each grid cell in the
!  current pencil.
!
        call shepherd_neighbour(fp,ineargrid,kshepherd,kneighbour)
        do l=l1,l2
          k=kshepherd(l-nghost)
          if (k>0) then
            do while (k/=0)
              j=k
              ncoll_par=0
              do while (kneighbour(j)/=0 .and. &
                  (ncoll_max_par==-1 .or. (ncoll_par<ncoll_max_par)))
                j=kneighbour(j)
                xpk=fp(k,ixp:izp)
                vpk=fp(k,ivpx:ivpz)
                if (lshear .and. lshear_in_vp) vpk(2)=vpk(2)-qshear*Omega*xpk(1)
                xpj=fp(j,ixp:izp)
                vpj=fp(j,ivpx:ivpz)
                if (lshear .and. lshear_in_vp) vpj(2)=vpj(2)-qshear*Omega*xpj(1)
!
!  Calculate the relative speed of particles j and k.
!
                deltavjk=sqrt(sum((vpk-vpj)**2))
!
!  The time-scale for collisions between a representative particle from
!  superparticle k and the particle cluster in superparticle j is
!
!    tau_coll = 1/(n*sigma*dv) = lambda/dv
!
!  where lambda is the mean free path of a particle relative to a single
!  superparticle (this is a constant).
!
                tau_coll1=deltavjk/lambda_mfp_single
!
                if (tau_coll1/=0.0) then
!
!  The probability for a collision in this time-step is dt/tau_coll.
!
                  prob=dt*tau_coll1
                  call random_number_wrapper(r)
                  if (r<=prob) then
                    if (ip<=6) then
                      print*, 'calc_particles_collisions: collision between'// &
                          ' superparticles ', ipar(k), ' and ', ipar(j)
                      print*, 'calc_particles_collisions: xj, xk='
                      print*, '  ', xpj, sqrt(sum(xpj**2))
                      print*, '  ', xpk, sqrt(sum(xpk**2))
                      print*, 'calc_particles_collisions: **before**'
                      print*, 'calc_particles_collisions: vj, vk, vj+vk='
                      print*, '  ', vpj, sqrt(sum(vpj**2))
                      print*, '  ', vpk, sqrt(sum(vpk**2))
                      print*, '  ', vpj+vpk
                      print*, 'calc_particles_collisions: ej, ek, ej+ek='
                      print*, '  ', 0.5*(sum(vpj**2)), 0.5*(sum(vpk**2)), &
                          0.5*(sum(vpj**2))+0.5*(sum(vpk**2))
                      print*, 'calc_particles_collisions: lj, lk, lj+lk='
                      call cross(xpj,vpj,tmp1)
                      print*, '  ', tmp1
                      call cross(xpk,vpk,tmp2)
                      print*, '  ', tmp2
                      print*, '  ', tmp1+tmp2
                    endif
!
!  Choose random unit vector direction in COM frame. Here theta_rot is the
!  pole angle and phi_rot is the azimuthal angle. While we can choose phi_rot
!  randomly, theta_rot must be chosen with care so that equal areas on the
!  unit sphere are equally probable.
!    (see http://mathworld.wolfram.com/SpherePointPicking.html)
!
                    if (lcollision_random_angle) then
                      call random_number_wrapper(theta_rot)
                      theta_rot=acos(2*theta_rot-1)
                      call random_number_wrapper(phi_rot)
                      phi_rot  =phi_rot*2*pi
                      vvcm=0.5*(vpj+vpk)
                      vvkcm=vpk-vvcm
                      vvkcmnew(1)=+sin(theta_rot)*cos(phi_rot)
                      vvkcmnew(2)=+sin(theta_rot)*sin(phi_rot)
                      vvkcmnew(3)=+cos(theta_rot)
!
!  Multiply unit vector by length of velocity vector.
!
                      vvkcmnew=vvkcmnew* &
                          sqrt(vvkcm(1)**2+vvkcm(2)**2+vvkcm(3)**2)
!
!  Dissipate some of the relative energy.
!
                      if (coeff_restitution/=1.0) &
                          vvkcmnew=vvkcmnew*coeff_restitution
!
!  Change velocity vectors in normal frame.
!
                      vpk=+vvkcmnew+vvcm
                      vpj=-vvkcmnew+vvcm
!
                    endif
!
!  Alternative method for collisions where each particle is considered to be
!  a big ball stretching to the surface of the other particle. We can then
!  solve the collision problem with perfect conservation of momentum, energy
!  and angular momentum.
!
                    if (lcollision_big_ball) then
                      nvec=xpj-xpk
                      nvec=nvec/sqrt(sum(nvec**2))
                      vvcm=0.5*(vpj+vpk)
                      vvkcm=vpk-vvcm
                      vvkcm_normal=nvec*(sum(vvkcm*nvec))
                      vvkcm_parall=vvkcm-vvkcm_normal
                      if (ip<=6) then
                        print*, 'calc_particles_collisions: nvec, vvkcm, vvkcm_normal, vvkcm_parall='
                        print*, '  ', nvec
                        print*, '  ', vvkcm
                        print*, '  ', vvkcm_normal
                        print*, '  ', vvkcm_parall
                      endif
                      if (coeff_restitution/=1.0) &
                          vvkcm_normal=vvkcm_normal*coeff_restitution
                      vpk=vvcm+vvkcm_parall-vvkcm_normal
                      vpj=vvcm-vvkcm_parall+vvkcm_normal
                    endif
                    if (ip<=6) then
                      print*, 'calc_particles_collisions: **after**'
                      print*, 'calc_particles_collisions: vj, vk, vj+vk='
                      print*, '  ', vpj, sqrt(sum(vpj**2))
                      print*, '  ', vpk, sqrt(sum(vpk**2))
                      print*, '  ', vpj+vpk
                      print*, 'calc_particles_collisions: ej, ek, ej+ek='
                      print*, '  ', 0.5*(sum(vpj**2)), 0.5*(sum(vpk**2)), &
                          0.5*(sum(vpj**2))+0.5*(sum(vpk**2))
                      print*, 'calc_particles_collisions: lj, lk, lj+lk='
                      call cross(xpj,vpj,tmp1)
                      print*, '  ', tmp1
                      call cross(xpk,vpk,tmp2)
                      print*, '  ', tmp2
                      print*, '  ', tmp1+tmp2
                    endif
                    if (lshear .and. lshear_in_vp) then
                      vpk(2)=vpk(2)+qshear*Omega*xpk(1)
                      vpj(2)=vpj(2)+qshear*Omega*xpj(1)
                    endif
                    fp(k,ivpx:ivpz)=vpk
                    fp(j,ivpx:ivpz)=vpj
                    ncoll=ncoll+1.0
                    ncoll_par=ncoll_par+1.0
!
                  endif
                endif
              enddo
              k=kneighbour(k)
            enddo
!  "if (k>0) then"
          endif
!
        enddo
      enddo
!
      if (mod(it,it1)==0) then
        if (ncoll/=0.0) then
          if (idiag_ncoll/=0) &
              call sum_weighted_name((/ncoll/),(/1.0/),idiag_ncoll)
        else
          if (idiag_ncoll/=0) &
              call sum_weighted_name((/0.0/),(/0.0/),idiag_ncoll)
        endif
      endif
!
    endsubroutine calc_particles_collisions
!***********************************************************************
    subroutine read_particles_coll_run_pars(unit,iostat)
!
!  Read run parameters from run.in.
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,nml=particles_coll_run_pars,err=99,iostat=iostat)
      else
        read(unit,nml=particles_coll_run_pars,err=99)
      endif
!
99    return
    endsubroutine read_particles_coll_run_pars
!***********************************************************************
    subroutine write_particles_coll_run_pars(unit)
!
!  Write run parameters to param.nml.
!
      integer, intent(in) :: unit
!
      write(unit,NML=particles_coll_run_pars)
!
    endsubroutine write_particles_coll_run_pars
!*******************************************************************
    subroutine rprint_particles_collisions(lreset,lwrite)
!
!  Read and register diagnostic parameters.
!
!  28-mar-09/anders: adapted
!
      use Diagnostics
!
      logical :: lreset
      logical, optional :: lwrite
!
      integer :: iname
!
      if (lreset) then
        idiag_ncoll=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'ncoll',idiag_ncoll)
      enddo
!
    endsubroutine rprint_particles_collisions
!***********************************************************************
endmodule Particles_collisions
