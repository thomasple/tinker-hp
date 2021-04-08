c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     #######################################################################################
c     ##                                                                                   ##
c     ##  module baoabopi  --  BAOAB Path Integral Langevin molecular dynamics step    ##
c     ##                                                                                   ##
c     #######################################################################################
c
c
c     "baoabpi" performs a single molecular dynamics time step
c     via the BAOAB recursion formula
c
c     literature reference:
c
c     Efficient molecular dynamics using geodesic integration 
c     and solvent-solute splitting B. Leimkuhler and C. Matthews,
c     Proceedings of the Royal Society A, 472: 20160138, 2016
c
c
#include "tinker_precision.h"
      module baoabpi        
      implicit none

      real(r_p),allocatable, private, save::derivs(:,:)

      contains

      subroutine apply_b_pi (istep,dt)
      use atmtyp
      use atomsMirror
      use bath
      use beads
      use cutoff
      use domdec
      use deriv  ,only: info_forces,prtEForces,cDef
      use energi ,only: info_energy
      use freeze
      use langevin
      use mdstuf
      use moldyn
      use timestat
      use units
      use usage
      use mpi
      use utils  ,only:set_to_zero1m
      use utilgpu,only:prmem_requestm,rec_queue
      use sizes
      implicit none
      integer, intent(in) :: istep
      real(r_p), intent(in) :: dt
      integer i,j,iglob,ibead,ierr
      real(r_p) dt_x,factor
      real(r_p) pres
      real(r_p) part1,part2
      real(r_p) stress(3,3)
      real(r_p) time0,time1
      
!$acc data present(epotpi_loc,eintrapi_loc)
!$acc&     present(x,y,z,xold,yold,zold,v,a,mass,glob,use)

!$acc update host(x,y,z)
      write(0,*) "nbloc=",nbloc
      write(0,*) x(1),y(1),z(1)
      write(0,*) x(n),y(n),z(n)
 
      write(0,*) "prmem_requestm"
      call prmem_requestm(derivs,3,nbloc,async=.true.)
      write(0,*) "set_to_zero1m"
      call set_to_zero1m(derivs,3*nbloc,rec_queue)
!$acc wait
c
c     get the potential energy and atomic forces
c
      if(contract) then
        call gradfast(eintrapi_loc,derivs)
        call commforcesrespa(derivs,.true.)
      else
        write(0,*) "gradient"
        call gradient (epotpi_loc,derivs)     
        write(0,*) "commforces"
        call commforces(derivs) 
      endif
c
c     MPI : get total energy (and allreduce the virial)
c
      write(0,*) "reduceen"
      call reduceen(epotpi_loc)
      write(0,*) "MPI_BCAST"
!$acc host_data use_device(epotpi_loc)
!$acc wait
      call MPI_BCAST(epotpi_loc,1,MPI_RPREC,0,COMM_TINKER,ierr)
!$acc end host_data

c
c     use Newton's second law to get the next accelerations;
c     find the full-step velocities using the BAOAB recursion
c
c      write(*,*) 'x 1 = ',x(1),y(1),v(1,1),a(1,1)

      write(0,*) "update vel"
!$acc parallel loop collapse(2) present(derivs) async
      do i = 1, nloc
        do j = 1, 3
          iglob = glob(i)
          if (use(iglob)) then            
               a(j,iglob) = -convert * derivs(j,i)/mass(iglob)
               v(j,iglob) = v(j,iglob) + dt*a(j,iglob)
               !v(j,iglob) = v(j,iglob) + 0.5*dt*a(j,iglob)
          end if
        enddo
      enddo
!$acc wait

      write(0,*) "end apply_b"

!$acc end data


      end subroutine apply_b_pi

c
c     !subroutine commposbead: communicate all positions to global master to be able
c     to make normal mode transformation and propagation,
c     then communicate back the positions after NM propagation
c
      subroutine apply_aoa_pi(istep,dt,pos_full,vel_full)
      use atoms
      use boxes, only: volbox,xbox,ybox,zbox
      use domdec
      use mpi
      use units
      use beads
      use langevin 
      use bath
      use cutoff
      use energi
      use freeze
      use mdstuf
      use moldyn
      use timestat
      use units
      use usage
      use atmtyp, only : mass
      use math
      use iounit
      use inform
      use molcul
      implicit none
      real(r_p), intent(in) :: dt
      integer, intent(in) :: istep
      real(8),intent(inout),allocatable::pos_full(:,:,:),vel_full(:,:,:)
      ! pos_full, vel_full must be filled only for ranktot 0
      integer i,j,k,iproc, ibead,l
      integer :: modstep
      real(r_p) :: dt2, a1,a2, sqrtmass

      dt2=0.5_re_p*dt

      if(isobaric) extvolold = extvol

c     propagate AOA
      if(ranktot .eq. 0) then

c       transform to normal modes
        DO i=1,n ; DO j=1,3
          vel_full(j,i,:)=matmul(eigmattr,vel_full(j,i,:))
          pos_full(j,i,:)=matmul(eigmattr,pos_full(j,i,:))
        ENDDO ; ENDDO

       if(isobaric) then
c         propagate volume velocity from previous step
          aextvol = 3.0_re_p*nbeads*convert*(
     &        extvol*(presvir-atmsph)/prescon 
     &        +gasconst*kelvin 
     &      )/masspiston
          vextvol = vextvol + dt2*aextvol          
        endif

        call apply_a_pi(pos_full,vel_full,dt2)

        call apply_o_pi(pos_full,vel_full,dt)

        call apply_a_pi(pos_full,vel_full,dt2)

c         update Ekcentroid  and presvir     
        presvir=presvir-prescon*(Ekcentroid/(3*nbeads*volbox))
        Ekcentroid=0
        DO i=1,n ; DO j=1,3          
          Ekcentroid=Ekcentroid+mass(i)*vel_full(j,i,1)**2
        ENDDO ; ENDDO
        Ekcentroid=Ekcentroid/convert        
        presvir=presvir+prescon*(Ekcentroid/(3*nbeads*volbox))

        if(isobaric) then
c         propagate volume velocity
          aextvol = 3.d0*nbeads*convert*(
     &        extvol*(presvir-atmsph)/prescon 
     &        +gasconst*kelvin 
     &      )/masspiston
          vextvol = vextvol + dt2*aextvol
        endif        

c         transform back to coordinates
        DO i=1,n ; DO j=1,3 
          vel_full(j,i,:)=matmul(eigmat,vel_full(j,i,:))
          pos_full(j,i,:)=matmul(eigmat,pos_full(j,i,:))          
        ENDDO ; ENDDO 
      endif


      if(isobaric) call rescale_box_pi(istep)     
     
      end subroutine apply_aoa_pi


      subroutine apply_a_pi(eigpos,eigvel,tau)
      use atoms
      use units
      use beads
      use bath
      implicit none
      real(8), intent(inout), allocatable :: eigpos(:,:,:),eigvel(:,:,:)
      real(r_p), intent(in) :: tau
      real(8) :: eigx0,eigv0
      real(r_p) :: acentroid,scale
      integer :: i,j,k

        if(isobaric) then
c         propagate centroid isobaric (half step)
          acentroid = sinh(tau*vextvol)/vextvol
          scale=exp(tau*vextvol)            
          extvol = extvol*exp(3.d0*tau*vextvol)

          DO i=1,n  ; DO j=1,3
            eigpos(j,i,1)=eigpos(j,i,1)*scale
     &        +acentroid*eigvel(j,i,1)
            eigvel(j,i,1)=eigvel(j,i,1)/scale
          ENDDO ; ENDDO 
        else
c         propagate centroid (half step)
          DO i=1,n ; DO j=1,3
            eigpos(j,i,1)=eigpos(j,i,1) + tau*eigvel(j,i,1)
          ENDDO ; ENDDO
        endif

c         propagate springs (half step)
        DO k=2,nbeads
          DO i=1,n ; DO j=1,3           
            eigx0=eigpos(j,i,k)
            eigv0=eigvel(j,i,k)
            eigpos(j,i,k)=eigx0*cos(omkpi(k)*tau)
     $            +eigv0*sin(omkpi(k)*tau)/omkpi(k)
            eigvel(j,i,k)=eigv0*cos(omkpi(k)*tau)
     $           -eigx0*sin(omkpi(k)*tau)*omkpi(k)
          ENDDO ; ENDDO
        ENDDO

      end subroutine apply_a_pi

      subroutine apply_o_pi(eigpos,eigvel,tau)
        use atmtyp, only : mass
        use atoms
        use units
        use beads
        use bath
        use langevin
        use random_mod
        implicit none
        real(8),intent(inout),allocatable :: eigpos(:,:,:),eigvel(:,:,:)
        real(r_p), intent(in) :: tau
        real(r_p) :: acentroid,a1p,a2p,gammak,a1,a2
        integer :: i,j,k

c         propagate langevin (full step, TRPMD)
        DO k=1,nbeads
          gammak=max(gamma,omkpi(k))
          a1 = exp(-gammak*tau)
          a2 = sqrt((1.-a1**2)*nbeads*boltzmann*kelvin)
          DO i=1,n ; DO j=1,3 
            eigvel(j,i,k)=eigvel(j,i,k)*a1 
     &              + a2*normal()/sqrt(mass(i))
          ENDDO; ENDDO
        ENDDO

        if(isobaric) then
c         langevin piston (full step)
          a1p = exp(-gammapiston*tau)
          a2p = sqrt((1-a1p**2)*nbeads*boltzmann*kelvin/masspiston)
          vextvol = vextvol*a1p + a2p*normal()
        endif

      end subroutine apply_o_pi

      subroutine compute_grad_slow()
      use atmtyp
      use atoms
      use bath
      use beads
      use cutoff
      use deriv
      use domdec
      use energi
      use freeze
      use langevin
      use mdstuf
      use moldyn
      use neigh
      use timestat
      use units
      use usage
      use mpi
      use utils  ,only:set_to_zero1m
      use utilgpu,only:prmem_requestm,rec_queue
      implicit none
      integer i,j,iglob,ibead,ierr
      integer iloc,iloc1,iloc2,iloc3,ilocrec1,ilocrec2,ilocrec3

!$acc data present(einterpi_loc)
!$acc&     present(x,y,z,a,mass,glob,use)
      call prmem_requestm(derivs,3,nbloc,async=.true.)
      call set_to_zero1m(derivs,3*nbloc,rec_queue)
      
      call gradslow(einterpi_loc,derivs)      
      call reduceen(einterpi_loc)
      call MPI_BCAST(einterpi_loc,1,MPI_REAL8,0,COMM_TINKER,ierr)

      call commforcesrespa(derivs,.false.)
      !write(0,*) einterpi_loc

!$acc parallel loop collapse(2) present(derivs) async
      do i = 1, nloc
        do j = 1, 3
          iglob = glob(i)
          if (use(iglob)) then       
            a(j,iglob) = -convert * derivs(j,i)/mass(iglob)   
          end if
        end do
      end do
!$acc wait
!$acc end data
      deallocate(derivs)
      
      end subroutine compute_grad_slow



      subroutine apply_b_slow(polymer,dt)
      use atmtyp
      use atoms
      use bath
      use beads
      use cutoff
      use deriv
      use domdec
      use energi
      use freeze
      use langevin
      use mdstuf
      use moldyn
      use neigh
      use timestat
      use units
      use usage
      use mpi
      implicit none
      type(POLYMER_COMM_TYPE) :: polymer,polymer_ctr
      real(r_p), intent(in) :: dt
      integer i,j,k,iglob,ibead,ierr

      DO i=1,n;  DO j=1,3
        polymer%vel(j,i,:)=polymer%vel(j,i,:)+ dt*convert
     &                            *polymer%forces_slow(j,i,:)/mass(i)
      enddo;enddo

      end subroutine apply_b_slow

      end module baoabpi
