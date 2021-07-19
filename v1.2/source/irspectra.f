!
!     Sorbonne University
!     Washington University in Saint Louis
!     University of Tex_sizeas at Austin
!
!     ###############################################################
!     ##                                                           ##
!     ##  subroutine qtbrandom--initialize a dynamics trajectory   ##
!     ##                                                           ##
!     ###############################################################
!

c     subroutine irspectra: get the total dipole moment of the system (permanent+induced)

      subroutine irspectra
      use adqtb
      use atmlst
      use atmtyp
      use atoms
      use bath
      use boxes
      use charge
      use cutoff
      use domdec
      use energi
      use freeze
      use langevin
      use math
      use mdstuf
      use molcul
      use moldyn
      use mpole
      use potent
      use qtb
      use timestat
      use usage
      use units
      use mpi
      implicit none
      integer i,j,l,istep,ierr
      integer iglob,iipole,iichg
      integer iloc
      integer iloc3,iloc2,iloc1
      integer imolcul,jglob,k
      real*8 oterm,hterm,q,beta_planck
      real*8, allocatable ::  vtot(:,:,:)
      real*8, allocatable :: Cmumu(:,:)
      real*8, allocatable ::  mudot(:,:)
      double complex, allocatable :: s_in(:), s_out(:)
      integer*8 plan, est,s

      oterm = 0.73612d0
      hterm = 0.13194d0

      s=3*nseg
      est=1
      beta_planck=1./(boltzmann/convert*kelvin)

      allocate(vtot(3,nloc,nseg))
      vtot = 0d0
      allocate(mudot(3,nseg))
     
      allocate(Cmumu(3,0:nad-1))

      Cmumu(:,:)=0d0
      mudot(:,:)=0d0

      if(compteur.le.startsavespec) then
        if (allocated(Cmumu_average)) deallocate (Cmumu_average)
         allocate(Cmumu_average(3,0:nad-1)) 
        Cmumu_average(:,:)=0d0
      endif

      open(12,file='IR_spectra_decomposed.out')
      open(13,file='IR_spectra.out')
      
      
      do i=1,nloc
        iglob=glob(i)
        imolcul = molcule(iglob) 
c        do k = imol(1,imolcul),imol(2,imolcul)
c          jglob = kmol(k)
c          if ((jglob.lt.1).or.(jglob.gt.nloc)) goto 10
c        end do
c
c        iloc3 = loc(iglob-3)
c        iloc2 = loc(iglob-2)
c        iloc1 = loc(iglob-1)
c          if (use(iglob) .and. (atomic(iglob).eq.0)) then
c            do j=1,3
c              vtot(1,i,:)=oterm*vad(1,iloc3,:)+hterm*vad(1,iloc2
c     &                        ,:)+hterm*vad(1,iloc1,:) 
c              vtot(2,i,:)=oterm*vad(2,iloc3,:)+hterm*vad(2,iloc2
c     &                        ,:)+hterm*vad(2,iloc1,:) 
c              vtot(3,i,:)=oterm*vad(3,iloc3,:)+hterm*vad(3,iloc2
c     &                        ,:)+hterm*vad(3,iloc1,:) 
c           enddo
c          else if (use(iglob)) then 
           if (use(iglob)) then 
            vtot(1,i,:)=vad(1,i,:)
            vtot(2,i,:)=vad(2,i,:)
            vtot(3,i,:)=vad(3,i,:)
          endif
c  10      continue
      enddo


        if (use_mpole) then
          do i= 1, npoleloc
            iipole = poleglob(i)
            iglob = ipole(iipole)
            iloc=loc(iglob)
            q=rpole(1,iipole)
              do j=1,3
                mudot(j,:)=mudot(j,:)+q*(vtot(j,iloc,:))
              enddo
            enddo
        else if (use_charge) then
          do i = 1, nionloc
            iichg = chgglob(i)
            iglob = iion(iichg)
            iloc=loc(iglob)
            q = pchg(iichg)
              do j=1,3
                mudot(j,:)=mudot(j,:)+q*(vtot(j,iloc,:))
              enddo
          enddo
        endif
      
        
      allocate(s_in(3*nseg))   
      allocate(s_out(3*nseg))

      if (ranktot.eq.0) then
        call MPI_REDUCE(MPI_IN_PLACE,mudot,3*nseg,MPI_REAL8
     &,MPI_SUM,0,
     $     MPI_COMM_WORLD,ierr)
      else
        call mPI_REDUCE(mudot,mudot,3*nseg,MPI_REAL8
     &,MPI_SUM,0,
     $     MPI_COMM_WORLD,ierr)
      endif



        




      if (ranktot.eq.0) then
      call dfftw_plan_dft_1d(plan,s,s_in,s_out,1,est)
        do j=1,3
          s_in(:)=dcmplx(0d0,0d0)
          s_in(1:nseg)=dcmplx(mudot(j,:),0d0)
          call dfftw_execute(plan,s_in,s_out)
          Cmumu(j,:)=Cmumu(j,:)+abs(s_out(1:nad))**2/nseg
        enddo

         Cmumu_average=Cmumu_average+Cmumu
        
         write(12,'(4e20.5)')0,Cmumu_average(:,0)
     &                /max(compteur-startsavespec+1,1)
         write(13,*) 0, ((pi*beta_planck)/(3*lightspd*volbox))
     &                *(Cmumu_average(1,0)
     &                +Cmumu_average(2,0)
     &                +Cmumu_average(3,0))
     &                /max(compteur-startsavespec+1,1)
        do i=1,nad-1
         write(12,'(4e20.5)')domega*i,Cmumu_average(:,i)
     &                /max(compteur-startsavespec+1,1)
         write(13,*) domega*i, ((pi*beta_planck)/(3*lightspd*volbox))
     &                *tanh(beta_planck*hbar_planck*(domega*i)/2.)
     &                /(beta_planck*hbar_planck*(domega*i)/2.)
     &                *(Cmumu_average(1,i)
     &                +Cmumu_average(2,i)
     &                +Cmumu_average(3,i))
     &                /max(compteur-startsavespec+1,1)
        enddo
      call dfftw_destroy_plan(plan) 
      endif
      
      close(12)
      close(13)
      
    


      return 
      end