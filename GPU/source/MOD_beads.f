c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     #####################################################################
c     ##                                                                 ##
c     ##  module beads   --  pimd variables                              ##
c     ##                                                                 ##
c     #####################################################################
c
c
c     nbeads  number of global replicas used for PIMD simulations
c     nbeadsloc  number of local replicas used for PIMD simulations
c     nproctot number of process for beads parallelism
c     nproc number of process for gradient parallelism
c     ncomm number of communicators for beads parallelism
c     locbead : array to switch from global to local beads
c     ibeadsloc : number of the current local beads
c     
c  dynamical variables replicated for PIMD simulations
c
c     pospi : array of positions
c     velpi : array of velocities
c     api : array of accelerations
c     
c     array used for domain decomposition within a bead:
c      glob
c      loc
c      repart
c      repartrec
c      domlen
c      domlenrec number of reciprocal atoms in the reciprocal domains
c      domlenpole
c      domlenpolerec
c      globrec
c      locrec
c      globrec1
c      locrec1
c      bufbegrec
c      bufbegpole
c      bufbeg
c     buflen1,buflen2,buf1,buf2,bufbeg1,bufbeg2 explicit direct-reciprocal atomic correspondance, 
c      nloc
c      nbloc
c      nlocrec
c      nblocrec local + neighbors reciprocal number of atoms
c      nlocnl local nl number of atoms
c      nblocrecdir local + neighbors direct+reciprocal number of atoms
c
c      molecule 
c      nmolelocpi,molculeglobpi
c
c      VDW :
c        nvdwblocpi,vdwglobpi,nvdwlocnlpi,vdwglobnlpi
c        nvlstpi,vlstpi
c
c      BONDS:
c        nbondlocpi,bndglobpi
c
c      STRETCH-BEND:
c        nstrbndlocpi,strbndglobpi
c
c      ANGLE-ANGLE:
c        nanganglocpi,angangglobpi
c
c      OP-BENDING:
c        nopbendlocpi,opbendglobpi
c
c      OP-DIST:
c        nopdistlocpi,opdistglobpi
c
c      IMPROP:
c        niproplocpi,impropglobpi
c
c      IMPTOR:
c        nitorslocpi,imptorglobpi 
c
c      TORSION:
c        ntorslocpi,torsglobpi 
c
c      PITORSION:
c        npitorslocpi,pitorsglobpi 
c
c      STRETCH-TORSION:
c        nstrtorlocpi,strtorglobpi 
c
c      TORSION-TORSION:
c        ntortorlocpi,tortorglobpi 
c
c      ANGLE:
c        nanglelocpi,angleglobpi 
c
c      CHARGE:
c        nionreclocpi,chgrecglobpi 
c        nionlocpi,chgglobpi
c        nionlocnlpi,chgglobnlpi
c        nelstpi,elstpi
c
c      MULTIPOLE:
c        npolereclocpi,polerecglobpi 
c        npolelocpi,poleglobpi,polelocpi
c        npolelocnlpi,poleglobnlpi
c        
c      POLARIZATION:
c        udaltpi,upaltpi,nualtpi
c        uindpi,uinppi
c        
c
c      STATS:
c        etot_sumpi,etot2_sumpi,eint_sumpi,eint2_sumpi
c        epot_sumpi,epot2_sumpi,ekin_sumpi,ekin2_sumpi
c        temp_sumpi,temp2_sumpi,pres_sumpi,pres2_sumpi
c        dens_sumpi,dens2_sumpi
c
c      TIME:
c        timestep
c
#include "tinker_precision.h"
      module beads
      implicit none
      integer :: ibead_loaded_loc,ibead_loaded_glob
      integer :: nbeads,nbeadsloc,nprocbeads   
!$acc declare create(nbeads)


      integer :: rank_beadloc, ncomm  

      logical :: contract
      integer :: nbeads_ctr, nbeadsloc_ctr  

      real(r_p) :: temppi,temppi_cl
      real(r_p) :: epotpi_loc,etotpi_loc
      real(r_p) :: eksumpi_loc,ekinpi_loc(3,3)
      real(r_p) :: ekprim,ekvir,presvir
      real(r_p) :: ekcentroid
      real(r_p) :: ekprim_ave, epotpi_ave, temppi_ave      
      real(r_p) :: eintrapi_loc
      real(r_p) :: einterpi_loc
      
      real(8), allocatable :: eigmat(:,:)
      real(8), allocatable :: eigmattr(:,:)
      real(8), allocatable ::  omkpi(:)
      
      real(8), allocatable :: contractor_mat(:,:)
      real(8), allocatable :: uncontractor_mat(:,:)

      TYPE POLYMER_COMM_TYPE
        integer :: nbeads
        integer :: nbeadsloc_max
        integer, allocatable :: nbeadscomm(:),nloccomm(:,:) 
        integer, allocatable :: globbeadcomm(:,:)
        integer, allocatable :: repart_dof_beads(:,:,:)

        real(8), allocatable :: pos(:,:,:),vel(:,:,:)
        real(8), allocatable :: forces(:,:,:)
        real(8), allocatable :: forces_slow(:,:,:)
      END TYPE     

      TYPE BEAD_TYPE
        real(r_p), allocatable :: x(:), y(:),z(:)
        real(r_p), allocatable :: v(:,:), a(:,:)
        real(r_p) :: dedv
        real(r_p) :: epot, etot, eksum, ekin(3,3)
        real(r_p) :: eintra
        real(r_p) :: einter

        integer :: ibead_loc
        integer :: ibead_glob
        integer :: contraction_level

        !PARALLELISM
        integer :: nloc,nbloc,nlocrec
        integer :: nblocrec,nlocnl
        integer :: nblocrecdir
        integer, allocatable :: glob(:),locpi(:),repart(:)        
        integer, allocatable :: repartrec(:), domlen(:)
        integer, allocatable :: domlenrec(:),domlenpole(:)
        integer, allocatable :: domlenpolerec(:),globrec(:)
        integer, allocatable :: locrec(:),globrec1(:)
        integer, allocatable :: locrec1(:)
        integer, allocatable :: bufbegrec(:)
        integer, allocatable :: bufbegpole(:),bufbeg(:)
        integer, allocatable :: buflen1(:),buflen2(:)
        integer, allocatable :: buf1(:),buf2(:)
        integer, allocatable :: bufbeg1(:),bufbeg2(:)
        integer :: nmoleloc
        integer, allocatable :: molculeglob(:)

        !NBLIST
        integer, allocatable :: ineignl(:)

        !
        !     BOND-STRETCHING
        !
        integer :: nbondloc
        integer, allocatable :: bndglob(:)
        !
        !     STRETCH-BENDING
        !
        integer :: nstrbndloc
        integer, allocatable :: strbndglob(:)
        !
        !     UREY-BRADLEY
        !
        integer :: nureyloc
        integer, allocatable :: ureyglob(:)
        !
        !     ANGLE-ANGLE
        !
        integer :: nangangloc
        integer, allocatable :: angangglob(:)
        !
        !     OP-BENDING
        !
        integer :: nopbendloc
        integer, allocatable :: opbendglob(:)
        !
        !     OP-DIST
        !
        integer :: nopdistloc
        integer, allocatable :: opdistglob(:)
        !
        !     IMPROP
        !
        integer :: niproploc
        integer, allocatable :: impropglob(:)
        !
        !     IMPTOR
        !
        integer :: nitorsloc
        integer, allocatable :: imptorglob(:)
        !
        !     TORSION
        !
        integer :: ntorsloc
        integer, allocatable ::torsglob(:)
        !
        !     PITORSION
        !
        integer :: npitorsloc
        integer, allocatable :: pitorsglob(:)
        !
        !     STRETCH-TORSION
        !
        integer :: nstrtorloc
        integer, allocatable ::strtorglob(:)
        !
        !     TORSION-TORSION
        !
        integer :: ntortorloc
        integer, allocatable :: tortorglob(:)
        !
        !     ANGLE
        !
        integer :: nangleloc
        integer, allocatable :: angleglob(:)
        !
        !     CHARGE
        !
        integer :: nionrecloc, nionloc, nionlocnl
        integer nionlocloop,nionlocnlloop
        integer nionlocnlb,nionlocnlb_pair,nionlocnlb2_pair
     &       ,nshortionlocnlb2_pair
        integer, allocatable :: chgrecglob(:)
        integer, allocatable ::chgglob(:)
        integer, allocatable :: chgglobnl(:)
        integer, allocatable :: nelst(:),elst(:,:),shortelst(:,:)
        integer, allocatable :: nelstc(:),nshortelst(:),nshortelstc(:)
        integer, allocatable :: eblst(:),ieblst(:)
        integer, allocatable :: shorteblst(:),ishorteblst(:)
        integer,allocatable :: celle_key(:),celle_glob(:)
     &              ,celle_pole(:),celle_loc(:),celle_ploc(:)
     &              ,celle_plocnl(:)
        integer,allocatable :: celle_chg(:)
        real(t_p),allocatable:: celle_x(:),celle_y(:),celle_z(:)
        !
        !     MULTIPOLE
        !
        integer :: npolerecloc,npoleloc,npolebloc, npolelocnl
        integer :: npolelocnlb,npolelocnlb_pair
        integer :: npolelocnlb2_pair,nshortpolelocnlb2_pair
        integer, allocatable :: polerecglob(:)
        integer, allocatable :: poleglob(:)
        integer, allocatable :: poleloc(:),polelocnl(:),polerecloc(:)
        integer, allocatable :: poleglobnl(:)
        integer npolerecloc_old,npolereclocloop
        integer npolelocloop, npolelocnlloop,npoleblocloop
        !
        !      POLARIZATION
        !
        integer :: nualt
        real(t_p), allocatable :: udalt(:,:,:),upalt(:,:,:)
        real(t_p), allocatable :: uind(:,:),uinp(:,:)
        !
        !     VDW
        !
        integer :: nvdwloc,nvdwbloc,nvdwlocnl,nvdwlocnlb,nvdwlocnlb_pair
        integer :: nvdwblocloop
        integer :: nvdwlocnlb2_pair,nshortvdwlocnlb2_pair
        integer, allocatable :: vdwglob(:)
        integer, allocatable :: vdwglobnl(:),vdwlocnl(:)
        integer, allocatable :: nvlst(:),vlst(:,:)
        integer, allocatable :: nshortvlst(:),shortvlst(:,:)
        integer, allocatable :: vblst(:),ivblst(:)
        integer, allocatable :: shortvblst(:),ishortvblst(:)
        integer,allocatable :: cellv_key(:),cellv_glob(:)
     &                        ,cellv_loc(:),cellv_jvdw(:)


        !
        !     SCALING FACTORS
        !
        integer :: n_vscale,n_mscale,n_cscale
        integer :: n_uscale,n_dpscale,n_dpuscale
        integer,allocatable :: vcorrect_ik(:,:)
        real(t_p), allocatable :: vcorrect_scale(:)
        integer,allocatable :: mcorrect_ik(:,:)
        real(t_p), allocatable :: mcorrect_scale(:)
        integer,allocatable :: ccorrect_ik(:,:)
        real(t_p), allocatable :: ccorrect_scale(:)
        integer,allocatable :: ucorrect_ik(:)
        real(t_p), allocatable :: ucorrect_scale(:)
        integer,allocatable :: dpcorrect_ik(:)
        real(t_p), allocatable :: dpcorrect_scale(:)
        integer,allocatable :: dpucorrect_ik(:)
        real(t_p), allocatable :: dpucorrect_scale(:)
        !
        !     STAT
        !
        real(t_p) :: etot_sum,etot2_sum
        real(t_p) :: eint_sum,eint2_sum
        real(t_p) :: epot_sum,epot2_sum
        real(t_p) :: ekin_sum,ekin2_sum
        real(t_p) :: temp_sum,temp2_sum
        real(t_p) :: pres_sum,pres2_sum
        real(t_p) :: dens_sum,dens2_sum
          
        !
        !     TIME
        !
        real(t_p) :: timestep
      END TYPE

      TYPE(BEAD_TYPE), allocatable :: beadsloc(:)
      TYPE(BEAD_TYPE), allocatable :: beadsloc_ctr(:)


      save

      contains

      subroutine deallocate_polymer(polymer)
        implicit none
        TYPE(POLYMER_COMM_TYPE), intent(inout) :: polymer

        if(allocated(polymer%pos)) deallocate(polymer%pos)
        if(allocated(polymer%vel)) deallocate(polymer%vel)
        if(allocated(polymer%forces)) deallocate(polymer%forces)

        if(allocated(polymer%nbeadscomm)) deallocate(polymer%nbeadscomm)
        if(allocated(polymer%nloccomm)) deallocate(polymer%nloccomm)
        if(allocated(polymer%globbeadcomm)) 
     &                      deallocate(polymer%globbeadcomm)
        if(allocated(polymer%repart_dof_beads)) 
     &                      deallocate(polymer%repart_dof_beads)

      end subroutine

      subroutine allocpi()
      use angle
      use atoms
      use bath
      use bitor
      use domdec
      use molcul
      use neigh
      use sizes
      use pitors
      use potent
      use tors
      use uprior
      use units
      use mdstuf
      implicit none
      integer ibead,i,ierr,j,k
      real(8), allocatable :: WORK(:)
      real(8), allocatable :: WORK_ctr(:),eigMat_ctr(:,:),omkpi_ctr(:)

      ibead_loaded_loc = -1
      ibead_loaded_glob = -1

      if(ranktot.eq.0) then

        Ekcentroid=nfree*nbeads*kelvin*gasconst      
      
        if (allocated(eigmat)) deallocate(eigmat)
        allocate(eigmat(nbeads,nbeads))
        if (allocated(eigmattr)) deallocate(eigmattr)
        allocate(eigmattr(nbeads,nbeads))
        if (allocated(omkpi)) deallocate(omkpi)
        allocate(omkpi(nbeads))        
        allocate(WORK(3*nbeads))

        eigmat=0
        DO i=1,nbeads-1
          eigmat(i,i)=2
          eigmat(i+1,i)=-1
          eigmat(i,i+1)=-1
        ENDDO
        eigmat(1,nbeads)=-1
        eigmat(nbeads,1)=-1
        eigmat(nbeads,nbeads)=2
        call DSYEV('V','U',nbeads,eigMat,nbeads, 
     $       omkpi,WORK,3*nbeads,ierr)
        omkpi(1)=0
        omkpi(:)=sqrt(omkpi)*(nbeads*boltzmann*kelvin/hbar)
        eigmattr=transpose(eigmat)
!$acc enter data copyin(eigmat,eigmattr,omkpi)
        deallocate(WORK)


        if (contract) then
          allocate(eigmat_ctr(nbeads_ctr,nbeads_ctr))
          allocate(omkpi_ctr(nbeads_ctr))
          allocate(WORK_ctr(3*nbeads_ctr))
          eigmat_ctr=0
          do i=1,nbeads_ctr-1
            eigmat_ctr(i,i)=2
            eigmat_ctr(i+1,i)=-1
            eigmat_ctr(i,i+1)=1
          enddo
          eigmat_ctr(1,nbeads_ctr)=-1
          eigmat_ctr(nbeads_ctr,1)=-1
          eigmat_ctr(nbeads_ctr,nbeads_ctr)=2
          call DSYEV('V','U',nbeads_ctr,eigMat_ctr,nbeads_ctr, 
     $        omkpi_ctr,WORK_ctr,3*nbeads_ctr,ierr)

          if (allocated(contractor_mat)) deallocate(contractor_mat)
          allocate(contractor_mat(nbeads_ctr,nbeads))
          contractor_mat(:,:) = 0._8
          do i=1,nbeads_ctr ; do j=1,nbeads            
            do k=1,nbeads_ctr
              contractor_mat(i,j) = contractor_mat(i,j)
     &          + eigmat_ctr(i,k)*eigmat(j,k)
            enddo
          enddo; enddo
          contractor_mat=contractor_mat*sqrt(nbeads_ctr*1._8/nbeads)

          if (allocated(uncontractor_mat)) deallocate(uncontractor_mat)
          allocate(uncontractor_mat(nbeads,nbeads_ctr))
          uncontractor_mat = nbeads*transpose(contractor_mat)/nbeads_ctr
          deallocate(WORK_ctr,eigMat_ctr,omkpi_ctr)
        endif
      endif

      if(allocated(beadsloc)) deallocate(beadsloc)
      allocate(beadsloc(nbeadsloc))      
      do i=1,nbeadsloc
!        write(0,*) "allocbea=",i,"/",nbeadsloc
        call allocbead(beadsloc(i))
        beadsloc(i)%ibead_loc = i
        beadsloc(i)%ibead_glob = rank_beadloc*int(nbeads/ncomm) + i
        ! OK if the last rank_beadloc takes the remaining beads
        !write(0,*) ranktot,"loc=",i,"glob=",beadsloc(i)%ibead_glob
      enddo

      if(contract) then
        if(allocated(beadsloc_ctr)) deallocate(beadsloc_ctr)
        allocate(beadsloc_ctr(nbeadsloc_ctr))
        do i=1,nbeadsloc_ctr
          call allocbead(beadsloc_ctr(i))
          beadsloc_ctr(i)%ibead_loc = i
          beadsloc_ctr(i)%ibead_glob = 
     &       rank_beadloc*int(nbeads_ctr/ncomm) + i
          ! OK if the last rank_beadloc takes the remaining beads
        enddo
      endif

      end subroutine allocpi

      subroutine allocbead(bead)
      use angle
      use atoms
      use bath
      use bitor
      use domdec
      use molcul
      use neigh
      use sizes
      use pitors
      use potent
      use tors
      use uprior
      use units
      use mdstuf
      implicit none
      TYPE(BEAD_TYPE), intent(inout) :: bead

      call deallocate_bead(bead)

!$acc enter data create(bead)
!$acc data present(bead)

      allocate(bead%x(n))
      allocate(bead%y(n))
      allocate(bead%z(n))
      allocate(bead%v(3,n))
      allocate(bead%a(3,n))
!$acc enter data create(bead%x,bead%y,bead%z,bead%v,bead%a) async
    
    
      allocate(bead%glob(n))
      allocate(bead%locpi(n))
      allocate(bead%repart(n))
      allocate(bead%repartrec(n))
      allocate(bead%domlen(nproc))
      allocate(bead%domlenrec(nproc))
      allocate(bead%domlenpole(nproc))
      allocate(bead%domlenpolerec(nproc))
      allocate(bead%globrec(n))
      allocate(bead%locrec(n))
      allocate(bead%globrec1(n))
      allocate(bead%locrec1(n))
      allocate(bead%bufbegrec(nproc))
      allocate(bead%bufbegpole(nproc))
      allocate(bead%bufbeg(nproc))
      allocate(bead%buflen1(nproc))
      allocate(bead%buflen2(nproc))
      allocate(bead%buf1(n))
      allocate(bead%buf2(n))
      allocate(bead%bufbeg1(nproc))
      allocate(bead%bufbeg2(nproc))
      allocate(bead%molculeglob(nmol))
!$acc enter data create(bead%glob)
!$acc&           create(bead%locpi)
!$acc&           create(bead%repart)
!$acc&           create(bead%repartrec)
!$acc&           create(bead%domlen)
!$acc&           create(bead%domlenrec)
!$acc&           create(bead%domlenpole)
!$acc&           create(bead%domlenpolerec)
!$acc&           create(bead%globrec)
!$acc&           create(bead%locrec)
!$acc&           create(bead%globrec1)
!$acc&           create(bead%locrec1)
!$acc&           create(bead%bufbegrec)
!$acc&           create(bead%bufbegpole)
!$acc&           create(bead%bufbeg)
!$acc&           create(bead%buflen1)
!$acc&           create(bead%buflen2)
!$acc&           create(bead%buf1)
!$acc&           create(bead%buf2)
!$acc&           create(bead%bufbeg1)
!$acc&           create(bead%bufbeg2)
!$acc&           create(bead%molculeglob) async


      if(allocated(ineignl)) then
        allocate(bead%ineignl(n))
!$acc enter data create(bead%ineignl) async
      endif
         


      if (use_vdw) then
        allocate(bead%vdwglob(n))
        allocate(bead%vdwglobnl(n))
        allocate(bead%vdwlocnl(n))
!$acc enter data create(bead%vdwglob) 
!$acc&           create(bead%vdwglobnl)
!$acc&           create(bead%vdwlocnl) async
      end if

      if (use_bond) then
        allocate(bead%bndglob(8*n))
!$acc enter data create(bead%bndglob)  async
      end if

      if (use_strbnd) then
        allocate(bead%strbndglob(nangle))
!$acc enter data create(bead%strbndglob)  async
      end if
      
      if (use_urey) then
        allocate(bead%ureyglob(nangle))
!$acc enter data create(bead%ureyglob)  async
      end if

      if (use_angang) then
        allocate(bead%angangglob(ntors))
!$acc enter data create(bead%angangglob)  async
      end if

      if (use_opbend) then
        allocate(bead%opbendglob(nangle))
!$acc enter data create(bead%opbendglob)  async
      end if

      if (use_opdist) then
        allocate(bead%opdistglob(n))
!$acc enter data create(bead%opdistglob)  async
      end if

      if (use_improp) then
        allocate(bead%impropglob(6*n))
!$acc enter data create(bead%impropglob)  async
      end if

      if (use_imptor) then
        allocate(bead%imptorglob(6*n))
!$acc enter data create(bead%imptorglob)  async
      end if

      if (use_tors) then
        allocate(bead%torsglob(6*n))
!$acc enter data create(bead%torsglob)  async
      end if

      if (use_pitors) then 
        allocate(bead%pitorsglob(ntors))
!$acc enter data create(bead%pitorsglob)  async
      end if

      if (use_strtor) then
        allocate(bead%strtorglob(ntors))
!$acc enter data create(bead%strtorglob)  async
      end if

      if (use_tortor) then
        allocate(bead%tortorglob(nbitor))
!$acc enter data create(bead%tortorglob)  async
      end if

      if (use_angle) then
        allocate(bead%angleglob(4*n))
!$acc enter data create(bead%angleglob)  async
      end if

      if (use_charge) then
        allocate(bead%chgrecglob(n))
        allocate(bead%chgglob(n))
        allocate(bead%chgglobnl(n))
!$acc enter data create(bead%chgrecglob) 
!$acc&           create(bead%chgglob)
!$acc&           create(bead%chgglobnl) async
      end if

      if (use_polar) then
        allocate(bead%udalt(3,n,maxualt))
        allocate(bead%upalt(3,n,maxualt))
        allocate(bead%uind(3,n))
        allocate(bead%uinp(3,n))
!$acc enter data create(bead%udalt(:,:,:)) 
!$acc&           create(bead%upalt(:,:,:))
!$acc&           create(bead%uind)
!$acc&           create(bead%uinp) async
      end if

      if (use_mpole) then
        allocate(bead%polerecglob(n))
        allocate(bead%poleglob(n))
        allocate(bead%poleloc(n))
        allocate(bead%poleglobnl(n))
        allocate(bead%polelocnl(n))
        allocate(bead%polerecloc(n))
!$acc enter data create(bead%polerecglob) 
!$acc&           create(bead%poleglob)
!$acc&           create(bead%poleloc)
!$acc&           create(bead%poleglobnl)
!$acc&           create(bead%polelocnl)
!$acc&           create(bead%polerecloc) async
      end if

!$acc wait

!$acc end  data 

      
      end subroutine

      subroutine deallocate_bead(bead)
        implicit none
        TYPE(BEAD_TYPE), intent(inout) :: bead

        if (allocated(bead%x)) deallocate(bead%x)
        if (allocated(bead%y)) deallocate(bead%y)
        if (allocated(bead%z)) deallocate(bead%z)
        if (allocated(bead%v)) deallocate(bead%v)
        if (allocated(bead%a)) deallocate(bead%a)   
        if (allocated(bead%glob)) deallocate(bead%glob)
        if (allocated(bead%locpi)) deallocate(bead%locpi)
        if (allocated(bead%repart)) deallocate(bead%repart)
        if (allocated(bead%repartrec)) deallocate(bead%repartrec)
        if (allocated(bead%domlen)) deallocate(bead%domlen)
        if (allocated(bead%domlenrec)) deallocate(bead%domlenrec)
        if (allocated(bead%domlenpole)) deallocate(bead%domlenpole)
        if (allocated(bead%domlenpolerec))deallocate(bead%domlenpolerec)
        if (allocated(bead%globrec)) deallocate(bead%globrec)
        if (allocated(bead%locrec)) deallocate(bead%locrec)
        if (allocated(bead%globrec1)) deallocate(bead%globrec1)
        if (allocated(bead%locrec1)) deallocate(bead%locrec1)
        if (allocated(bead%bufbegrec)) deallocate(bead%bufbegrec)
        if (allocated(bead%bufbegpole)) deallocate(bead%bufbegpole)
        if (allocated(bead%bufbeg)) deallocate(bead%bufbeg)
        if (allocated(bead%buflen1)) deallocate(bead%buflen1)
        if (allocated(bead%buflen2)) deallocate(bead%buflen2)
        if (allocated(bead%bufbeg1)) deallocate(bead%bufbeg1)
        if (allocated(bead%buf1)) deallocate(bead%buf1)
        if (allocated(bead%buf2)) deallocate(bead%buf2)
        if (allocated(bead%bufbeg2)) deallocate(bead%bufbeg2)
        if (allocated(bead%molculeglob)) deallocate(bead%molculeglob)
        if (allocated(bead%ineignl)) deallocate(bead%ineignl)
        !if (allocated(bead%locnl)) deallocate(bead%locnl)
        if (allocated(bead%vdwglob)) deallocate(bead%vdwglob)
        if (allocated(bead%vdwglobnl)) deallocate(bead%vdwglobnl)
        if (allocated(bead%vdwlocnl)) deallocate(bead%vdwlocnl)
        if (allocated(bead%bndglob)) deallocate(bead%bndglob)
        if (allocated(bead%strbndglob)) deallocate(bead%strbndglob)
        if (allocated(bead%ureyglob)) deallocate(bead%ureyglob)
        if (allocated(bead%angangglob)) deallocate(bead%angangglob)
        if (allocated(bead%opbendglob)) deallocate(bead%opbendglob)
        if (allocated(bead%opdistglob)) deallocate(bead%opdistglob)
        if (allocated(bead%impropglob)) deallocate(bead%impropglob)
        if (allocated(bead%imptorglob)) deallocate(bead%imptorglob)
        if (allocated(bead%torsglob)) deallocate(bead%torsglob)
        if (allocated(bead%pitorsglob)) deallocate(bead%pitorsglob)
        if (allocated(bead%strtorglob)) deallocate(bead%strtorglob)
        if (allocated(bead%tortorglob)) deallocate(bead%tortorglob)
        if (allocated(bead%angleglob)) deallocate(bead%angleglob)
        if (allocated(bead%chgrecglob)) deallocate(bead%chgrecglob)
        if (allocated(bead%chgglob)) deallocate(bead%chgglob)
        if (allocated(bead%chgglobnl)) deallocate(bead%chgglobnl)
        if (allocated(bead%udalt)) deallocate(bead%udalt)
        if (allocated(bead%upalt)) deallocate(bead%upalt)
        if (allocated(bead%uind)) deallocate(bead%uind)
        if (allocated(bead%uinp)) deallocate(bead%uinp)
        if (allocated(bead%polerecglob)) deallocate(bead%polerecglob)
        if (allocated(bead%poleglob)) deallocate(bead%poleglob)
        if (allocated(bead%poleloc)) deallocate(bead%poleloc)
        if (allocated(bead%polerecloc)) deallocate(bead%polerecloc)
        if (allocated(bead%polelocnl)) deallocate(bead%polelocnl)
        if (allocated(bead%poleglobnl)) deallocate(bead%poleglobnl)

        if (allocated(bead%nvlst)) deallocate(bead%nvlst)
        if (allocated(bead%vlst)) deallocate(bead%vlst)
        if (allocated(bead%nelst)) deallocate(bead%nelst)
        if (allocated(bead%elst)) deallocate(bead%elst)

        if (allocated(bead%nelstc)) deallocate(bead%nelstc)
        if (allocated(bead%shortelst)) deallocate(bead%shortelst)
        if (allocated(bead%nshortelst)) deallocate(bead%nshortelst)
        if (allocated(bead%shortelst)) deallocate(bead%shortelst)
        if (allocated(bead%nshortelstc)) deallocate(bead%nshortelstc)

        if (allocated(bead%eblst)) deallocate(bead%eblst)
        if (allocated(bead%ieblst)) deallocate(bead%ieblst)
        if (allocated(bead%shorteblst)) deallocate(bead%shorteblst)
        if (allocated(bead%ishorteblst)) deallocate(bead%ishorteblst)

        if (allocated(bead%celle_key)) deallocate(bead%celle_key)
        if (allocated(bead%celle_glob)) deallocate(bead%celle_glob)
        if (allocated(bead%celle_pole)) deallocate(bead%celle_pole)
        if (allocated(bead%celle_loc)) deallocate(bead%celle_loc)
        if (allocated(bead%celle_ploc)) deallocate(bead%celle_ploc)
        if (allocated(bead%celle_plocnl)) deallocate(bead%celle_plocnl)
        if (allocated(bead%celle_chg)) deallocate(bead%celle_chg)
        if (allocated(bead%celle_x)) deallocate(bead%celle_x)
        if (allocated(bead%celle_y)) deallocate(bead%celle_y)
        if (allocated(bead%celle_z)) deallocate(bead%celle_z)

        if (allocated(bead%nshortvlst)) deallocate(bead%nshortvlst)
        if (allocated(bead%shortvlst)) deallocate(bead%shortvlst)
        if (allocated(bead%vblst)) deallocate(bead%vblst)
        if (allocated(bead%ivblst)) deallocate(bead%ivblst)
        if (allocated(bead%shortvblst)) deallocate(bead%shortvblst)
        if (allocated(bead%ishortvblst)) deallocate(bead%ishortvblst)
        if (allocated(bead%cellv_key)) deallocate(bead%cellv_key)
        if (allocated(bead%cellv_glob)) deallocate(bead%cellv_glob)
        if (allocated(bead%cellv_loc)) deallocate(bead%cellv_loc)
        if (allocated(bead%cellv_jvdw)) deallocate(bead%cellv_jvdw)


      end subroutine deallocate_bead
      

      subroutine initbead(istep,bead,skip_parameters)
      use angang
      use angle
      use atomsMirror
      use atmlst
      use atmtyp
      use bitor
      use bond
      use charge
      use domdec
      use energi
      use improp
      use imptor
      use molcul
      use moldyn
      use mpole
      use neigh
      use opbend, only: nopbendloc
      use opdist
      use pitors
      use polar
      use potent
      use sizes
      use stat
      use strbnd
      use strtor
      use timestat
      use tors
      use tortor
      use uprior
      use urey
      use vdw
      use virial
      implicit none
      integer, intent(in) :: istep
      type(BEAD_TYPE), intent(inout) :: bead 
      logical,intent(in) :: skip_parameters
      integer ibead,i,j,k,modnl


!$acc wait
!$acc data present(bead)
c
c     positions, speed, mass
c
!!!$acc update host(x(:),y(:),z(:),v(:,:),a(:,:))

!$acc parallel loop 
      do i=1,n
        bead%x(i) = x(i)
        bead%y(i) = y(i)
        bead%z(i) = z(i)
!$acc loop
        do j=1,3
          bead%v(j,i) = v(j,i)
          bead%a(j,i) = a(j,i)
        enddo
      enddo

      !print *,"initbead pos update host"
!$acc update host(bead%x(:),bead%y(:),bead%z(:),bead%v(:,:),bead%a(:,:))
      !write(0,*) "initbead ener"

!$acc update host(eksumpi_loc,ekinpi_loc)
      if(contract) then
!$acc update host(eintrapi_loc,einterpi_loc)
        bead%eintra=eintrapi_loc
        bead%einter=einterpi_loc
        bead%epot=eintrapi_loc+einterpi_loc
        bead%etot=eintrapi_loc+einterpi_loc+eksumpi_loc
      else
!$acc update host(epotpi_loc)
        bead%epot=epotpi_loc
        bead%etot=epotpi_loc+eksumpi_loc
      endif

      bead%eksum=eksumpi_loc
      bead%ekin=ekinpi_loc
      bead%dedv = dedv

      !write(0,*) "initbead glob"
      bead%nloc = nloc
!$acc parallel loop
      do i=1,n
        bead%glob(i) = glob(i)
      enddo

!$acc update host(bead%glob(:))

!$acc end data
c
c     STAT
c
      bead%etot_sum = etot_sum
      bead%etot2_sum= etot2_sum
      bead%eint_sum = eint_sum
      bead%eint2_sum= eint2_sum
      bead%epot_sum = epot_sum
      bead%epot2_sum= epot2_sum
      bead%ekin_sum = ekin_sum
      bead%ekin2_sum= ekin2_sum
      bead%temp_sum = temp_sum
      bead%temp2_sum= temp2_sum
      bead%pres_sum = pres_sum
      bead%pres2_sum= pres2_sum
      bead%dens_sum = dens_sum
      bead%dens2_sum= dens2_sum

      if(skip_parameters) return

!$acc data present(bead)
      modnl = mod(istep,ineigup)
c
c     parallelism
c
      !write(0,*) "initbead bloc",nblocrecdir

      bead%nbloc = nbloc
      bead%nlocrec = nlocrec
      bead%nblocrec = nblocrec
      bead%nlocnl = nlocnl
      bead%nblocrecdir = nblocrecdir

!$acc parallel loop async
      do i=1,n
      bead%locpi(i) = loc(i)
      bead%repart(i) = repart(i)
      bead%repartrec(i) = repartrec(i)
      bead%globrec(i) = globrec(i)
      bead%locrec(i) = locrec(i)
      bead%globrec1(i) = globrec1(i)
      bead%locrec1(i) = locrec1(i)
      enddo

!$acc parallel loop async
      do i=1,nproc
      bead%domlen(i) = domlen(i)
      bead%domlenrec(i) = domlenrec(i)
      bead%domlenpole(i) = domlenpole(i)
      bead%domlenpolerec(i) = domlenpolerec(i)
      bead%bufbegrec(i) = bufbegrec(i)
      bead%bufbegpole(i) = bufbegpole(i)
      bead%bufbeg(i) = bufbeg(i)
      bead%buflen1(i) = buflen1(i)
      bead%buflen2(i) = buflen2(i)
      bead%bufbeg1(i) =  bufbeg1(i)
      bead%bufbeg2(i) = bufbeg2(i)
      enddo

!$acc parallel loop async      
      do i=1,nblocrecdir
      bead%buf1(i) = buf1(i)
      bead%buf2(i) = buf2(i)
      enddo

!$acc parallel loop async      
      do i=1,nmol
      bead%molculeglob(i) = molculeglob(i)
      enddo
      
      if(allocated(bead%ineignl)) then
!$acc parallel loop async
        do i=1,n
        bead%ineignl(i) = ineignl(i)
        enddo
      endif
c
c     VDW 
c
      !write(0,*) "initbead vdw"

      if (use_vdw) then
!$acc parallel loop async
        do i=1,n
        bead%vdwglob(i) = vdwglob(i)
        bead%vdwglobnl(i) = vdwglobnl(i)
        bead%vdwlocnl(i) = vdwlocnl(i)
        enddo

        bead%nvdwbloc = nvdwbloc
        bead%nvdwlocnl = nvdwlocnl
        bead%nvdwlocnlb = nvdwlocnlb
        bead%nvdwlocnlb_pair = nvdwlocnlb_pair
        bead%nvdwlocnlb2_pair = nvdwlocnlb2_pair
        bead%nshortvdwlocnlb2_pair = nshortvdwlocnlb2_pair
        bead%nvdwblocloop = nvdwblocloop

      end if
c
c     BONDS
c
      !write(0,*) "initbead bonds"
      if (use_bond) then
!$acc parallel loop async
        do i=1,8*n
        bead%bndglob(i) = bndglob(i)
        enddo
        bead%nbondloc = nbondloc
      end if
c
c     STRETCH-BEND
c
      !write(0,*) "initbead strbnd"
      if (use_strbnd) then
!$acc parallel loop async
        do i=1,nangle
        bead%strbndglob(i) = strbndglob(i)
        enddo
        bead%nstrbndloc = nstrbndloc
      end if
c
c     UREY-BRADLEY
c
      if (use_urey) then
!$acc parallel loop async
        do i=1,nangle
        bead%ureyglob(i) = ureyglob(i)
        enddo
        bead%nureyloc = nureyloc
      end if
c
c     ANGlE-ANGLE
c
      if (use_angang) then
!$acc parallel loop async
        do i=1,ntors
        bead%angangglob(i) = angangglob(i)
        enddo
        bead%nangangloc = nangangloc
      end if
c
c     OP-BENDING
c
      if (use_opbend) then
!$acc parallel loop async
        do i=1,nangle
        bead%opbendglob(i) = opbendglob(i)
        enddo
        bead%nopbendloc = nopbendloc
      end if
c
c     OP-DIST
c
      if (use_opdist) then
!$acc parallel loop async
        do i=1,n
        bead%opdistglob(i) = opdistglob(i)
        enddo
        bead%nopdistloc = nopdistloc
      end if
c
c     IMPROP
c
      if (use_improp) then
!$acc parallel loop async
        do i=1,6*n
        bead%impropglob(i) = impropglob(i)
        enddo
        bead%niproploc = niproploc
      end if
c
c     IMPTOR
c
      if (use_imptor) then
!$acc parallel loop async
        do i=1,6*n
        bead%imptorglob(i) = imptorglob(i)
        enddo
        bead%nitorsloc = nitorsloc
      end if
c
c     TORSION
c
      if (use_tors) then
!$acc parallel loop async
        do i=1,6*n
        bead%torsglob(i) = torsglob(i)
        enddo
        bead%ntorsloc = ntorsloc
      end if
c
c     PITORSION
c
      if (use_pitors) then
!$acc parallel loop async
        do i=1,ntors
        bead%pitorsglob(i) = pitorsglob(i)
        enddo
        bead%npitorsloc = npitorsloc
      end if
c
c     STRETCH-TORSION
c
      if (use_strtor) then
!$acc parallel loop async
        do i=1,ntors
        bead%strtorglob(i) = strtorglob(i)
        enddo
        bead%nstrtorloc = nstrtorloc
      end if
c
c     TORSION-TORSION
c
      if (use_tortor) then
!$acc parallel loop async
        do i=1,nbitor
        bead%tortorglob(i) = tortorglob(i)
        enddo
        bead%ntortorloc = ntortorloc
      end if
c
c     ANGLE
c
      if (use_angle) then
!$acc parallel loop async
        do i=1,4*n
        bead%angleglob(i) = angleglob(i)
        enddo
        bead%nangleloc = nangleloc
      end if
c
c     CHARGE
c
      !write(0,*) "initbead charge"

      !write(0,*) "initbead charge"
      if (use_charge) then
!$acc parallel loop async
        do i=1,n
        bead%chgrecglob(i) = chgrecglob(i)
        bead%chgglob(i) = chgglob(i)
        bead%chgglobnl(i) = chgglobnl(i)
        enddo
        bead%nionrecloc = nionrecloc
        bead%nionloc = nionloc
        bead%nionlocnl = nionlocnl
        bead%nionlocloop = nionlocloop
        bead%nionlocnlloop = nionlocnlloop
        bead%nionlocnlb = nionlocnlb
        bead%nionlocnlb_pair = nionlocnlb_pair
        bead%nionlocnlb2_pair = nionlocnlb2_pair
        bead%nshortionlocnlb2_pair = nshortionlocnlb2_pair
      end if

c
c     MULTIPOLE
c
      !write(0,*) "initbead mpole"
      if (use_mpole) then
!$acc parallel loop async
        do i=1,n
        bead%poleloc(i) = poleloc(i)
        bead%polerecloc(i) = polerecloc(i)
        bead%polelocnl(i) = polelocnl(i)
        enddo
!$acc parallel loop async
        do i=1,nlocrec
        bead%polerecglob(i)=polerecglob(i)
        enddo
!$acc parallel loop async
        do i=1,nbloc
        bead%poleglob(i)=poleglob(i)
        enddo
!$acc parallel loop async
        do i=1,nlocnl
        bead%poleglobnl(i)=poleglobnl(i)
        enddo
        bead%npolerecloc = npolerecloc
        bead%npoleloc = npoleloc
        bead%npolebloc = npolebloc        
        bead%npolelocnl = npolelocnl
        bead%npolelocnlb = npolelocnlb
        bead%npolelocnlb_pair = npolelocnlb_pair
        bead%npolelocnlb2_pair = npolelocnlb2_pair
        bead%nshortpolelocnlb2_pair = nshortpolelocnlb2_pair
        bead%npolerecloc_old = npolerecloc_old
        bead%npolelocloop = npolelocloop
        bead%npolelocnlloop = npolelocnlloop
        bead%npoleblocloop = npoleblocloop
        bead%npolereclocloop = npolereclocloop
        
      end if
c
c     POLARIZATION
c

      if (use_polar) then
        bead%nualt = nualt
!$acc parallel loop collapse(3) async
        do k=1,maxualt
          do i=1,n ; do j=1,3
          bead%udalt(j,i,k) = udalt(j,i,k)
          bead%upalt(j,i,k) = upalt(j,i,k)
          enddo; enddo
        enddo
!$acc parallel loop collapse(2) async
        do i=1,n ; do j=1,3
        bead%uind(j,i) = uind(j,i)
        bead%uinp(j,i) = uinp(j,i)
        enddo; enddo
      end if

!$acc wait
!$acc end data 

c
c     TIME
c
      bead%timestep = timestep

      end subroutine initbead

      subroutine resize_nl_arrays_bead(bead)
      use angle
      use atoms
      use bath
      use bitor
      use domdec
      use molcul
      use neigh
      use sizes
      use pitors
      use potent
      use tors
      use uprior
      use units
      use mdstuf
      use polpot
      use chgpot
      use mplpot
      use vdwpot
      implicit none
      TYPE(BEAD_TYPE), intent(inout) :: bead
      integer nblocrecdirmax,modnl

!$acc wait
!$acc data present(bead)

      if (allocated(nvlst)) then
        if (allocated(bead%nvlst)) then 
!$acc exit data delete(bead%nvlst)
          deallocate(bead%nvlst)
        endif
        allocate(bead%nvlst(size(nvlst)))
!$acc enter data create(bead%nvlst)
      endif

      if(allocated(vlst)) then
        if (allocated(bead%vlst)) then 
!$acc exit data delete(bead%vlst)
          deallocate(bead%vlst)
        endif
        allocate(bead%vlst(size(vlst,1),size(vlst,2)))
!$acc enter data create(bead%vlst)
      endif

      if(allocated(nelst)) then
        if (allocated(bead%nelst)) then 
!$acc exit data delete(bead%nelst)
          deallocate(bead%nelst)
        endif
        allocate(bead%nelst(size(nelst)))
!$acc enter data create(bead%nelst)
      endif

      if (allocated(elst)) then        
        if (allocated(bead%elst)) then 
!$acc exit data delete(bead%elst)
          deallocate(bead%elst)
        endif
        allocate(bead%elst(size(elst,1),size(elst,2)))
!$acc enter data create(bead%elst)
      end if

      if (allocated(nelstc)) then        
        if (allocated(bead%nelstc)) then 
!$acc exit data delete(bead%nelstc)
          deallocate(bead%nelstc)
        endif
        allocate(bead%nelstc(size(nelstc)))
!$acc enter data create(bead%nelstc)
      end if

      if (allocated(shortelst)) then        
        if (allocated(bead%shortelst)) then 
!$acc exit data delete(bead%shortelst)
          deallocate(bead%shortelst)
        endif
        allocate(bead%shortelst(size(shortelst,1),size(shortelst,2)))
!$acc enter data create(bead%shortelst)
      end if

      if (allocated(nshortelst)) then        
        if (allocated(bead%nshortelst)) then 
!$acc exit data delete(bead%nshortelst)
          deallocate(bead%nshortelst)
        endif
        allocate(bead%nshortelst(size(nshortelst)))
!$acc enter data create(bead%nshortelst)
      end if

      if (allocated(nshortelstc)) then        
        if (allocated(bead%nshortelstc)) then 
!$acc exit data delete(bead%nshortelstc)
          deallocate(bead%nshortelstc)
        endif
        allocate(bead%nshortelstc(size(nshortelstc)))
!$acc enter data create(bead%nshortelstc)
      end if

      if (allocated(eblst)) then        
        if (allocated(bead%eblst)) then 
!$acc exit data delete(bead%eblst)
          deallocate(bead%eblst)
        endif
        allocate(bead%eblst(size(eblst)))
!$acc enter data create(bead%eblst)
      end if

       if (allocated(ieblst)) then        
        if (allocated(bead%ieblst)) then 
!$acc exit data delete(bead%ieblst)
          deallocate(bead%ieblst)
        endif
        allocate(bead%ieblst(size(ieblst)))
!$acc enter data create(bead%ieblst)
      end if

      if (allocated(shorteblst)) then        
        if (allocated(bead%shorteblst)) then 
!$acc exit data delete(bead%shorteblst)
          deallocate(bead%shorteblst)
        endif
        allocate(bead%shorteblst(size(shorteblst)))
!$acc enter data create(bead%shorteblst)
      end if

      if (allocated(ishorteblst)) then        
        if (allocated(bead%ishorteblst)) then 
!$acc exit data delete(bead%ishorteblst)
          deallocate(bead%ishorteblst)
        endif
        allocate(bead%ishorteblst(size(ishorteblst)))
!$acc enter data create(bead%ishorteblst)
      end if

      if (allocated(nshortvlst)) then        
        if (allocated(bead%nshortvlst)) then 
!$acc exit data delete(bead%nshortvlst)
          deallocate(bead%nshortvlst)
        endif
        allocate(bead%nshortvlst(size(nshortvlst)))
!$acc enter data create(bead%nshortvlst)
      end if

      if (allocated(shortvlst)) then        
        if (allocated(bead%shortvlst)) then 
!$acc exit data delete(bead%shortvlst)
          deallocate(bead%shortvlst)
        endif
        allocate(bead%shortvlst(size(shortvlst,1),size(shortvlst,2)))
!$acc enter data create(bead%shortvlst)
      end if

      if (allocated(vblst)) then        
        if (allocated(bead%vblst)) then 
!$acc exit data delete(bead%vblst)
          deallocate(bead%vblst)
        endif
        allocate(bead%vblst(size(vblst)))
!$acc enter data create(bead%vblst)
      end if

      if (allocated(ivblst)) then        
        if (allocated(bead%ivblst)) then 
!$acc exit data delete(bead%ivblst)
          deallocate(bead%ivblst)
        endif
        allocate(bead%ivblst(size(ivblst)))
!$acc enter data create(bead%ivblst)
      end if

      if (allocated(shortvblst)) then        
        if (allocated(bead%shortvblst)) then 
!$acc exit data delete(bead%shortvblst)
          deallocate(bead%shortvblst)
        endif
        allocate(bead%shortvblst(size(shortvblst)))
!$acc enter data create(bead%shortvblst)
      end if

      if (allocated(ishortvblst)) then        
        if (allocated(bead%ishortvblst)) then 
!$acc exit data delete(bead%ishortvblst)
          deallocate(bead%ishortvblst)
        endif
        allocate(bead%ishortvblst(size(ishortvblst)))
!$acc enter data create(bead%ishortvblst)
      end if

      if(allocated(celle_glob))  then
        if (allocated(bead%celle_glob)) then 
!$acc exit data delete(bead%celle_glob)
          deallocate(bead%celle_glob)
        endif
        allocate(bead%celle_glob(size(celle_glob)))
!$acc enter data create(bead%celle_glob)
      endif

      if(allocated(celle_pole))  then
        if (allocated(bead%celle_pole)) then 
!$acc exit data delete(bead%celle_pole)
          deallocate(bead%celle_pole)
        endif
        allocate(bead%celle_pole(size(celle_pole)))
!$acc enter data create(bead%celle_pole)
      endif

      if(allocated(celle_plocnl))  then
        if (allocated(bead%celle_plocnl)) then 
!$acc exit data delete(bead%celle_plocnl)
          deallocate(bead%celle_plocnl)
        endif
        allocate(bead%celle_plocnl(size(celle_plocnl)))
!$acc enter data create(bead%celle_plocnl)
      endif

      if(allocated(celle_key))  then
        if (allocated(bead%celle_key)) then 
!$acc exit data delete(bead%celle_key)
          deallocate(bead%celle_key)
        endif
        allocate(bead%celle_key(size(celle_key)))
!$acc enter data create(bead%celle_key)
      endif

      if(allocated(celle_chg))  then
        if (allocated(bead%celle_chg)) then 
!$acc exit data delete(bead%celle_chg)
          deallocate(bead%celle_chg)
        endif
        allocate(bead%celle_chg(size(celle_chg)))
!$acc enter data create(bead%celle_chg)
      endif

      if(allocated(celle_loc))  then
        if (allocated(bead%celle_loc)) then 
!$acc exit data delete(bead%celle_loc)
          deallocate(bead%celle_loc)
        endif
        allocate(bead%celle_loc(size(celle_loc)))
!$acc enter data create(bead%celle_loc)
      endif

      if(allocated(celle_ploc))  then
        if (allocated(bead%celle_ploc)) then 
!$acc exit data delete(bead%celle_ploc)
          deallocate(bead%celle_ploc)
        endif
        allocate(bead%celle_ploc(size(celle_ploc)))
!$acc enter data create(bead%celle_ploc)
      endif

      if(allocated(celle_x))  then
        if (allocated(bead%celle_x)) then 
!$acc exit data delete(bead%celle_x)
          deallocate(bead%celle_x)
        endif
        allocate(bead%celle_x(size(celle_x)))
!$acc enter data create(bead%celle_x)
      endif

      if(allocated(celle_y))  then
        if (allocated(bead%celle_y)) then 
!$acc exit data delete(bead%celle_y)
          deallocate(bead%celle_y)
        endif
        allocate(bead%celle_y(size(celle_y)))
!$acc enter data create(bead%celle_y)
      endif

      if(allocated(celle_z))  then
        if (allocated(bead%celle_z)) then 
!$acc exit data delete(bead%celle_z)
          deallocate(bead%celle_z)
        endif
        allocate(bead%celle_z(size(celle_z)))
!$acc enter data create(bead%celle_z)
      endif

      if(allocated(cellv_key))  then
        if (allocated(bead%cellv_key)) then 
!$acc exit data delete(bead%cellv_key)
          deallocate(bead%cellv_key)
        endif
        allocate(bead%cellv_key(size(cellv_key)))
!$acc enter data create(bead%cellv_key)
      endif

      if(allocated(cellv_glob))  then
        if (allocated(bead%cellv_glob)) then 
!$acc exit data delete(bead%cellv_glob)
          deallocate(bead%cellv_glob)
        endif
        allocate(bead%cellv_glob(size(cellv_glob)))
!$acc enter data create(bead%cellv_glob)
      endif

      if(allocated(cellv_loc))  then
        if (allocated(bead%cellv_loc)) then 
!$acc exit data delete(bead%cellv_loc)
          deallocate(bead%cellv_loc)
        endif
        allocate(bead%cellv_loc(size(cellv_loc)))
!$acc enter data create(bead%cellv_loc)
      endif

      if(allocated(cellv_jvdw))  then
        if (allocated(bead%cellv_jvdw)) then 
!$acc exit data delete(bead%cellv_jvdw)
          deallocate(bead%cellv_jvdw)
        endif
        allocate(bead%cellv_jvdw(size(cellv_jvdw)))
!$acc enter data create(bead%cellv_jvdw)
      endif

      if(allocated(vcorrect_ik))  then
        if (allocated(bead%vcorrect_ik)) then 
!$acc exit data delete(bead%vcorrect_ik)
          deallocate(bead%vcorrect_ik)
        endif
        allocate(bead%vcorrect_ik(size(vcorrect_ik,1)
     &        ,size(vcorrect_ik,2)))
!$acc enter data create(bead%vcorrect_ik)
      endif

      if(allocated(vcorrect_scale))  then
        if (allocated(bead%vcorrect_scale)) then 
!$acc exit data delete(bead%vcorrect_scale)
          deallocate(bead%vcorrect_scale)
        endif
        allocate(bead%vcorrect_scale(size(vcorrect_scale)))
!$acc enter data create(bead%vcorrect_scale)
      endif

      if(allocated(mcorrect_ik))  then
        if (allocated(bead%mcorrect_ik)) then 
!$acc exit data delete(bead%mcorrect_ik)
          deallocate(bead%mcorrect_ik)
        endif
        allocate(bead%mcorrect_ik(size(mcorrect_ik,1)
     &        ,size(mcorrect_ik,2)))
!$acc enter data create(bead%mcorrect_ik)
      endif

      if(allocated(mcorrect_scale))  then
        if (allocated(bead%mcorrect_scale)) then 
!$acc exit data delete(bead%mcorrect_scale)
          deallocate(bead%mcorrect_scale)
        endif
        allocate(bead%mcorrect_scale(size(mcorrect_scale)))
!$acc enter data create(bead%mcorrect_scale)
      endif

      if(allocated(ccorrect_ik))  then
        if (allocated(bead%ccorrect_ik)) then 
!$acc exit data delete(bead%ccorrect_ik)
          deallocate(bead%ccorrect_ik)
        endif
        allocate(bead%ccorrect_ik(size(ccorrect_ik,1)
     &        ,size(ccorrect_ik,2)))
!$acc enter data create(bead%ccorrect_ik)
      endif

      if(allocated(ccorrect_scale))  then
        if (allocated(bead%ccorrect_scale)) then 
!$acc exit data delete(bead%ccorrect_scale)
          deallocate(bead%ccorrect_scale)
        endif
        allocate(bead%ccorrect_scale(size(ccorrect_scale)))
!$acc enter data create(bead%ccorrect_scale)
      endif

      if(allocated(ucorrect_ik))  then
        if (allocated(bead%ucorrect_ik)) then 
!$acc exit data delete(bead%ucorrect_ik)
          deallocate(bead%ucorrect_ik)
        endif
        allocate(bead%ucorrect_ik(size(ucorrect_ik)))
!$acc enter data create(bead%ucorrect_ik)
      endif

       if(allocated(ucorrect_scale))  then
        if (allocated(bead%ucorrect_scale)) then 
!$acc exit data delete(bead%ucorrect_scale)
          deallocate(bead%ucorrect_scale)
        endif
        allocate(bead%ucorrect_scale(size(ucorrect_scale)))
!$acc enter data create(bead%ucorrect_scale)
      endif

      if(allocated(dpcorrect_ik))  then
        if (allocated(bead%dpcorrect_ik)) then 
!$acc exit data delete(bead%dpcorrect_ik)
          deallocate(bead%dpcorrect_ik)
        endif
        allocate(bead%dpcorrect_ik(size(dpcorrect_ik)))
!$acc enter data create(bead%dpcorrect_ik)
      endif

      if(allocated(dpcorrect_scale))  then
        if (allocated(bead%dpcorrect_scale)) then 
!$acc exit data delete(bead%dpcorrect_scale)
          deallocate(bead%dpcorrect_scale)
        endif
        allocate(bead%dpcorrect_scale(size(dpcorrect_scale)))
!$acc enter data create(bead%dpcorrect_scale)
      endif

      if(allocated(dpucorrect_ik))  then
        if (allocated(bead%dpucorrect_ik)) then 
!$acc exit data delete(bead%dpucorrect_ik)
          deallocate(bead%dpucorrect_ik)
        endif
        allocate(bead%dpucorrect_ik(size(dpucorrect_ik)))
!$acc enter data create(bead%dpucorrect_ik)
      endif

       if(allocated(dpucorrect_scale))  then
        if (allocated(bead%dpucorrect_scale)) then 
!$acc exit data delete(bead%dpucorrect_scale)
          deallocate(bead%dpucorrect_scale)
        endif
        allocate(bead%dpucorrect_scale(size(dpucorrect_scale)))
!$acc enter data create(bead%dpucorrect_scale)
      endif

!$acc end data


      end subroutine resize_nl_arrays_bead
c
      subroutine savebeadnl(istep,bead)
      use domdec
      use neigh
      use potent
      use polpot
      use chgpot
      use mplpot
      use vdwpot
      implicit none
      TYPE(BEAD_TYPE), intent(inout) :: bead
      integer, intent(in) ::  istep
      integer modnl,i,j,k,n1,n2

!$acc wait

      modnl = mod(istep,ineigup)
      !write(0,*) "modnl=",modnl,istep,ineigup

      if(modnl==0) call resize_nl_arrays_bead(bead)
!$acc data present(bead)
c
c      ! COPY ARRAYS THAT CHANGE EACH STEP
c
      if (allocated(celle_loc)) then
        n1=size(celle_loc)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_loc(i) = celle_loc(i)
        ENDDO
      endif

      if (allocated(celle_ploc)) then
        n1=size(celle_ploc)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_ploc(i) = celle_ploc(i)
        ENDDO
      endif

      if (allocated(celle_x)) then
        n1=size(celle_x)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_x(i) = celle_x(i)
        ENDDO
      endif

      if (allocated(celle_y)) then
        n1=size(celle_y)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_y(i) = celle_y(i)
        ENDDO
      endif

      if (allocated(celle_z)) then
        n1=size(celle_z)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_z(i) = celle_z(i)
        ENDDO
      endif

!$acc end data

      if (modnl.ne.0) return
c
c      ! COPY ARRAYS THAT CHANGE ONLY WHEN WE RECOMPUTE THE NBLIST
c

!$acc data present(bead)

      if (allocated(nvlst)) then
        n1=size(nvlst)
!$acc parallel loop async
        DO i=1,n1
        bead%nvlst(i) = nvlst(i)
        ENDDO
      endif

      if(allocated(vlst)) then
        n1=size(vlst,1)
        n2=size(vlst,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%vlst(i,j) = vlst(i,j)
        ENDDO ;ENDDO
      endif

      if(allocated(nelst)) then
        n1=size(nelst)
!$acc parallel loop async
        DO i=1,n1
        bead%nelst(i) = nelst(i)
        ENDDO
      endif

      if (allocated(elst)) then        
        n1=size(elst,1)
        n2=size(elst,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%elst(i,j) = elst(i,j)
        ENDDO;ENDDO
      end if

      if (allocated(nelstc)) then        
        n1=size(nelstc)
!$acc parallel loop async
        DO i=1,n1
        bead%nelstc(i) = nelstc(i)
        ENDDO
      end if

      if (allocated(shortelst)) then        
        n1=size(shortelst,1)
        n2=size(shortelst,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%shortelst(i,j) = shortelst(i,j)
        ENDDO;ENDDO
      end if

      if (allocated(nshortelst)) then        
        n1=size(nshortelst)
!$acc parallel loop async
        DO i=1,n1
        bead%nshortelst(i) = nshortelst(i)
        ENDDO
      end if

      if (allocated(nshortelstc)) then        
        n1=size(nshortelstc)
!$acc parallel loop async
        DO i=1,n1
        bead%nshortelstc(i) = nshortelstc(i)
        ENDDO
      end if

      if (allocated(eblst)) then        
        n1=size(eblst)
!$acc parallel loop async
        DO i=1,n1
        bead%eblst(i) = eblst(i)
        ENDDO
      end if

       if (allocated(ieblst)) then        
        n1=size(ieblst)
!$acc parallel loop async
        DO i=1,n1
        bead%ieblst(i) = ieblst(i)
        ENDDO
      end if

      if (allocated(shorteblst)) then        
        n1=size(shorteblst)
!$acc parallel loop async
        DO i=1,n1
        bead%shorteblst(i) = shorteblst(i)
        ENDDO
      end if

      if (allocated(ishorteblst)) then        
        n1=size(ishorteblst)
!$acc parallel loop async
        DO i=1,n1
        bead%ishorteblst(i) = ishorteblst(i)
        ENDDO
      end if
      

      if (allocated(nshortvlst)) then        
        n1=size(nshortvlst)
!$acc parallel loop async
        DO i=1,n1
        bead%nshortvlst(i) = nshortvlst(i)
        ENDDO
      end if

      if (allocated(shortvlst)) then        
        n1=size(shortvlst,1)
        n2=size(shortvlst,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%shortvlst(i,j) = shortvlst(i,j)
        ENDDO;ENDDO
      end if

      if (allocated(vblst)) then        
        n1=size(vblst)
!$acc parallel loop async
        DO i=1,n1
        bead%vblst(i) = vblst(i)
        ENDDO
      end if

      if (allocated(ivblst)) then        
        n1=size(ivblst)
!$acc parallel loop async
        DO i=1,n1
        bead%ivblst(i) = ivblst(i)
        ENDDO
      end if

      if (allocated(shortvblst)) then        
        n1=size(shortvblst)
!$acc parallel loop async
        DO i=1,n1
        bead%shortvblst(i) = shortvblst(i)
        ENDDO
      end if

      if (allocated(ishortvblst)) then        
        n1=size(ishortvblst)
!$acc parallel loop async
        DO i=1,n1
        bead%ishortvblst(i) = ishortvblst(i)
        ENDDO
      end if

      if(allocated(celle_glob))  then
        n1=size(celle_glob)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_glob(i) = celle_glob(i)
        ENDDO
      endif

      if(allocated(celle_pole))  then
        n1=size(celle_pole)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_pole(i) = celle_pole(i)
        ENDDO
      endif

      if(allocated(celle_plocnl))  then
        n1=size(celle_plocnl)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_plocnl(i) = celle_plocnl(i)
        ENDDO
      endif
      
      if(allocated(celle_key))  then
        n1=size(celle_key)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_key(i) = celle_key(i)
        ENDDO
      endif

      if(allocated(celle_chg))  then
        n1=size(celle_chg)
!$acc parallel loop async
        DO i=1,n1
        bead%celle_chg(i) = celle_chg(i)
        ENDDO
      endif

      if(allocated(cellv_key))  then
        n1=size(cellv_key)
!$acc parallel loop async
        DO i=1,n1
        bead%cellv_key(i) = cellv_key(i)
        ENDDO
      endif

      if(allocated(cellv_glob))  then
        n1=size(cellv_glob)
!$acc parallel loop async
        DO i=1,n1
        bead%cellv_glob(i) = cellv_glob(i)
        ENDDO
      endif

      if(allocated(cellv_loc))  then
        n1=size(cellv_loc)
!$acc parallel loop async
        DO i=1,n1
        bead%cellv_loc(i) = cellv_loc(i)
        ENDDO
      endif

       if(allocated(cellv_jvdw))  then
        n1=size(cellv_jvdw)
!$acc parallel loop async
        DO i=1,n1
        bead%cellv_jvdw(i) = cellv_jvdw(i)
        ENDDO
      endif

      ! SCALING FACTORS
      bead%n_vscale=n_vscale
      bead%n_mscale=n_mscale
      bead%n_cscale=n_cscale
      bead%n_uscale=n_uscale
      bead%n_dpscale=n_dpscale
      bead%n_dpuscale=n_dpuscale
      
      if(allocated(vcorrect_ik) .and.size(vcorrect_ik)>0) then
        n1=size(vcorrect_ik,1)
        n2=size(vcorrect_ik,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%vcorrect_ik(i,j) = vcorrect_ik(i,j)
        ENDDO;ENDDO
      endif

      if(allocated(vcorrect_scale).and.size(vcorrect_scale)>0) then
        n1=size(vcorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%vcorrect_scale(i) = vcorrect_scale(i)
        ENDDO
      endif

      if(allocated(mcorrect_ik).and.size(mcorrect_ik)>0) then
        n1=size(mcorrect_ik,1)
        n2=size(mcorrect_ik,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%mcorrect_ik(i,j) = mcorrect_ik(i,j)
        ENDDO;ENDDO
      endif

      if(allocated(mcorrect_scale).and.size(mcorrect_scale)>0) then
        n1=size(mcorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%mcorrect_scale(i) = mcorrect_scale(i)
        ENDDO
      endif

      if(allocated(ccorrect_ik).and.size(ccorrect_ik)>0) then
        n1=size(ccorrect_ik,1)
        n2=size(ccorrect_ik,2)
!$acc parallel loop collapse(2) async 
        DO j=1,n2 ; DO i=1,n1
        bead%ccorrect_ik(i,j) = ccorrect_ik(i,j)
        ENDDO;ENDDO
      endif

      if(allocated(ccorrect_scale).and.size(ccorrect_scale)>0) then
        n1=size(ccorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%ccorrect_scale(i) = ccorrect_scale(i)
        ENDDO
      endif

      if(allocated(ucorrect_ik).and. size(ucorrect_ik)>0) then
        n1=size(ucorrect_ik)
!$acc parallel loop async
        DO i=1,n1
        bead%ucorrect_ik(i) = ucorrect_ik(i)
        ENDDO
      endif

       if(allocated(ucorrect_scale).and.size(ucorrect_scale)>0) then
        n1=size(ucorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%ucorrect_scale(i) = ucorrect_scale(i)
        ENDDO
      endif

      if(allocated(dpcorrect_ik).and.size(dpcorrect_ik)>0)  then
        n1=size(dpcorrect_ik)
!$acc parallel loop async
        DO i=1,n1
        bead%dpcorrect_ik(i) = dpcorrect_ik(i)
        ENDDO
      endif

      if(allocated(dpcorrect_scale).and.size(dpcorrect_scale)>0) then
        n1=size(dpcorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%dpcorrect_scale(i) = dpcorrect_scale(i)
        ENDDO
      endif

      if(allocated(dpucorrect_ik).and.size(dpucorrect_ik)>0) then
        n1=size(dpucorrect_ik)
!$acc parallel loop async
        DO i=1,n1
        bead%dpucorrect_ik(i) = dpucorrect_ik(i)
        ENDDO
      endif

       if(allocated(dpucorrect_scale).and.size(dpucorrect_scale)>0) then
        n1=size(dpucorrect_scale)
!$acc parallel loop async
        DO i=1,n1
        bead%dpucorrect_scale(i) = dpucorrect_scale(i)
        ENDDO
      endif

!$acc wait
!$acc end data

      end
      

      subroutine pushbead(istep,bead,skip_parameters)
      use angang
      use angle
      use atomsMirror
      use atmlst
      use atmtyp
      use bitor
      use bond
      use charge
      use domdec
      use energi
      use improp
      use imptor
      use molcul
      use moldyn
      use mpole
      use neigh
      use opbend, only: nopbendloc
      use opdist
      use pitors
      use polar
      use potent
      use sizes
      use stat
      use strbnd
      use strtor
      use timestat
      use tors
      use tortor
      use uprior
      use urey
      use vdw
      use virial
      use polpot
      use chgpot
      use mplpot
      use vdwpot
      use utilgpu,only:prmem_request
      implicit none
      integer, intent(in) :: istep
      type(BEAD_TYPE), intent(inout) :: bead
      LOGICAL, intent(in) :: skip_parameters
      integer modnl,n1,n2,i,j,k

!$acc wait
      ibead_loaded_glob = bead%ibead_glob
      ibead_loaded_loc = bead%ibead_loc

      !write(0,*) "push energies"

      if(contract) then
        eintrapi_loc=bead%eintra
        einterpi_loc=bead%einter
        epotpi_loc=bead%eintra+bead%einter
        eksumpi_loc=bead%eksum
        ekinpi_loc=bead%ekin
        dedv=bead%dedv
!$acc update device(eintrapi_loc,einterpi_loc) async
      else
        epotpi_loc=bead%epot
        eksumpi_loc=bead%eksum
        ekinpi_loc=bead%ekin
        dedv=bead%dedv
      endif
!$acc update device(eksumpi_loc,ekinpi_loc,epotpi_loc) async

!$acc data present(bead)
!$acc update device(bead%x,bead%y,bead%z,bead%v,bead%a)
      !write(0,*) "push position"    
!$acc parallel loop 
      do i=1,n
        x(i) = bead%x(i)
        y(i) = bead%y(i)
        z(i) = bead%z(i)
!$acc loop
        do j=1,3
          v(j,i) = bead%v(j,i)
          a(j,i) = bead%a(j,i)
        enddo
      enddo  

      nloc = bead%nloc
!$acc parallel loop
      do i=1,n
        glob(i) = bead%glob(i)
      enddo

!$acc end data
c
c     STAT
c
      ! write(0,*) "push stat"
      etot_sum  = bead%etot_sum
      etot2_sum = bead%etot2_sum
      eint_sum  = bead%eint_sum
      eint2_sum = bead%eint2_sum
      epot_sum  = bead%epot_sum
      epot2_sum = bead%epot2_sum
      ekin_sum  = bead%ekin_sum
      ekin2_sum = bead%ekin2_sum
      temp_sum  = bead%temp_sum
      temp2_sum = bead%temp2_sum
      pres_sum  = bead%pres_sum
      pres2_sum = bead%pres2_sum
      dens_sum  = bead%dens_sum
      dens2_sum = bead%dens2_sum
c
      if (skip_parameters) return

      modnl = mod(istep,ineigup)
!$acc data present(bead)

c
c     parallelism
c
      ! write(0,*) "push parallelism"
      nbloc = bead%nbloc
      nlocrec = bead%nlocrec
      nblocrec = bead%nblocrec
      nlocnl = bead%nlocnl
      nblocrecdir = bead%nblocrecdir

!$acc parallel loop async
      do i=1,n
      loc(i) = bead%locpi(i)
      repart(i) = bead%repart(i)
      repartrec(i) = bead%repartrec(i)
      globrec(i) = bead%globrec(i)
      locrec(i) = bead%locrec(i)
      globrec1(i) = bead%globrec1(i)
      locrec1(i) = bead%locrec1(i)
      enddo

!$acc parallel loop async
      do i=1,nproc
      domlen(i) = bead%domlen(i)
      domlenrec(i) = bead%domlenrec(i)
      domlenpole(i) = bead%domlenpole(i)
      domlenpolerec(i) = bead%domlenpolerec(i)
      bufbegrec(i) = bead%bufbegrec(i)
      bufbegpole(i) = bead%bufbegpole(i)
      bufbeg(i) = bead%bufbeg(i)
      buflen1(i) = bead%buflen1(i)
      buflen2(i) = bead%buflen2(i)
      bufbeg1(i) =  bead%bufbeg1(i)
      bufbeg2(i) = bead%bufbeg2(i)
      enddo

!$acc parallel loop async      
      do i=1,nblocrecdir
      buf1(i) = bead%buf1(i)
      buf2(i) = bead%buf2(i)
      enddo

!$acc parallel loop async      
      do i=1,nmol
      molculeglob(i) = bead%molculeglob(i)
      enddo

      if(allocated(bead%ineignl)) then
!$acc parallel loop async
        do i=1,n
        ineignl(i) = bead%ineignl(i)
        enddo
      endif

c
c     VDW
c
      if (use_vdw) then
        ! write(0,*) "push VDW"
!$acc parallel loop async
        do i=1,n
        vdwglob(i) =  bead%vdwglob(i)
        vdwglobnl(i) =bead%vdwglobnl(i)
        vdwlocnl(i) = bead%vdwlocnl(i)
        enddo
        nvdwbloc = bead%nvdwbloc
        nvdwlocnl = bead%nvdwlocnl
        nvdwblocloop = bead%nvdwblocloop
        nvdwlocnlb = bead%nvdwlocnlb
        nvdwlocnlb_pair = bead%nvdwlocnlb_pair
        nvdwlocnlb2_pair = bead%nvdwlocnlb2_pair
        nshortvdwlocnlb2_pair = bead%nshortvdwlocnlb2_pair
      endif
c
c     BOND
c
      if (use_bond) then
        !write(0,*) "push BOND"
        nbondloc = bead%nbondloc
!$acc parallel loop async
        do i=1,8*n
        bndglob(i) = bead%bndglob(i)
        enddo
      endif
c
c     STRETCH-BEND
c
      if (use_strbnd) then
        !write(0,*) "push STRETCH-BEND"
        nstrbndloc = bead%nstrbndloc
!$acc parallel loop async
        do i=1,nangle
        strbndglob(i) = bead%strbndglob(i)
        enddo
      endif
c
c     UREY-BRADLEY
c
      if (use_urey) then
        !write(0,*) "push UREY-BRADLEY"
        nureyloc = bead%nureyloc
!$acc parallel loop async
        do i=1,nangle
        bead%ureyglob(i) = ureyglob(i)
        enddo
      endif
c
c     ANGLE-ANGLE
c
      if (use_angang) then
        !write(0,*) "push ANGLE-ANGLE"
        nangangloc = bead%nangangloc
!$acc parallel loop async
        do i=1,ntors
        angangglob(i) = bead%angangglob(i)
        enddo
      endif
c
c     OP-BENDING
c
      if (use_opbend) then
        !write(0,*) "push OP-BENDING"
        nopbendloc = bead%nopbendloc
!$acc parallel loop async
        do i=1,nangle
        opbendglob(i) = bead%opbendglob(i)
        enddo
      endif
c
c     OP-DIST
c
      if (use_opdist) then
        !write(0,*) "push  OP-DIST"
        nopdistloc = bead%nopdistloc
!$acc parallel loop async
        do i=1,n
        opdistglob(i) = bead%opdistglob(i)
        enddo
      endif
c
c     IMPROP
c
      if (use_improp) then
       ! write(0,*) "push IMPROP"
        niproploc = bead%niproploc
!$acc parallel loop async
        do i=1,6*n
        impropglob(i) = bead%impropglob(i)
        enddo
      endif
c
c     IMPTOR
c
      if (use_imptor) then
       ! write(0,*) "push IMPTOR"
        nitorsloc = bead%nitorsloc
!$acc parallel loop async
        do i=1,6*n
        imptorglob(i) = bead%imptorglob(i)
        enddo
      endif
c
c     TORSION
c
      if (use_tors) then
        !write(0,*) "push TORSION"
        ntorsloc = bead%ntorsloc
!$acc parallel loop async
        do i=1,6*n
        torsglob(i) = bead%torsglob(i)
        enddo
      endif
c
c     PITORSION
c
      if (use_pitors) then
        !write(0,*) "push PITORSION"
        npitorsloc = bead%npitorsloc
!$acc parallel loop async
        do i=1,ntors
        pitorsglob(i) = bead%pitorsglob(i)
        enddo
      endif
c
c     STRETCH-TORSION
c
      if (use_strtor) then
        !write(0,*) "push STRETCH-TORSION"
        nstrtorloc = bead%nstrtorloc
!$acc parallel loop async
        do i=1,ntors
        strtorglob(i) = bead%strtorglob(i)
        enddo
      endif
c
c     TORSION-TORSION
c
      if (use_tortor) then
        !write(0,*) "push TORSION-TORSION"
        ntortorloc = bead%ntortorloc
!$acc parallel loop async
        do i=1,nbitor
        tortorglob(i) = bead%tortorglob(i)
        enddo
      endif
c
c     ANGLE
c
      if (use_angle) then
        !write(0,*) "push ANGLE"
        nangleloc = bead%nangleloc
!$acc parallel loop async
        do i=1,4*n
        angleglob(i) = bead%angleglob(i)
        enddo
      endif
c
c     CHARGE
c
      if (use_charge) then
        !write(0,*) "push CHARGE"
        nionrecloc = bead%nionrecloc
        nionloc = bead%nionloc
        nionlocnl = bead%nionlocnl
        nionlocloop = bead%nionlocloop
        nionlocnlloop=bead%nionlocnlloop
        nionlocnlb = bead%nionlocnlb
        nionlocnlb_pair = bead%nionlocnlb_pair
        nionlocnlb2_pair = bead%nionlocnlb2_pair
        nshortionlocnlb2_pair = bead%nshortionlocnlb2_pair
!$acc parallel loop async
        do i=1,n
        chgrecglob(i) = bead%chgrecglob(i)
        chgglob(i) = bead%chgglob(i)
        chgglobnl(i) = bead%chgglobnl(i)
        enddo
      endif

c
c     MULTIPOLE
c
      if (use_mpole) then
        !write(0,*) "push MULTIPOLE"
        npolerecloc = bead%npolerecloc        
        npoleloc = bead%npoleloc
        npolebloc = bead%npolebloc
        npolelocnl = bead%npolelocnl
        npolelocnlb = bead%npolelocnlb
        npolelocnlb_pair = bead%npolelocnlb_pair
        npolelocnlb2_pair = bead%npolelocnlb2_pair
        nshortpolelocnlb2_pair = bead%nshortpolelocnlb2_pair
        npolerecloc_old = bead%npolerecloc_old
        npolelocloop = bead%npolelocloop
        npolelocnlloop = bead%npolelocnlloop
        npoleblocloop = bead%npoleblocloop
        npolereclocloop = bead%npolereclocloop
!$acc parallel loop async
        do i=1,n
        poleloc(i) = bead%poleloc(i)
        polerecloc(i) = bead%polerecloc(i)
        polelocnl(i) = bead%polelocnl(i)
        enddo
!$acc parallel loop async
        do i=1,nlocrec
        polerecglob(i)=bead%polerecglob(i)
        enddo
!$acc parallel loop async
        do i=1,nbloc
        poleglob(i)=bead%poleglob(i)
        enddo
!$acc parallel loop async
        do i=1,nlocnl
        poleglobnl(i)=bead%poleglobnl(i)
        enddo
      endif
c
c     POLARIZATION
c
      if (use_polar) then
        !write(0,*) "push POLARIZATION"
        nualt = bead%nualt
!$acc parallel loop collapse(3) async
        do k=1,maxualt
          do i=1,n ; do j=1,3
          udalt(j,i,k) = bead%udalt(j,i,k)
          upalt(j,i,k) = bead%upalt(j,i,k)
          enddo; enddo
        enddo
!$acc parallel loop collapse(2) async
        do i=1,n ; do j=1,3
        uind(j,i) = bead%uind(j,i)
        uinp(j,i) = bead%uinp(j,i)
        enddo; enddo
      endif



      !NEIGHBORLIST

      if (allocated(celle_loc)) then
        n1=size(bead%celle_loc)
        call prmem_request(celle_loc,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_loc(i) = bead%celle_loc(i)
        ENDDO
      endif

      if (allocated(celle_ploc)) then
        n1=size(bead%celle_ploc)
        call prmem_request(celle_ploc,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_ploc(i) = bead%celle_ploc(i)
        ENDDO
      endif

      if (allocated(celle_x)) then
        n1=size(bead%celle_x)
        call prmem_request(celle_x,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_x(i) = bead%celle_x(i)
        ENDDO
      endif

      if (allocated(celle_y)) then
        n1=size(bead%celle_y)
        call prmem_request(celle_y,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_y(i) = bead%celle_y(i)
        ENDDO
      endif

      if (allocated(celle_z)) then
        n1=size(bead%celle_z)
        call prmem_request(celle_z,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_z(i) = bead%celle_z(i)
        ENDDO
      endif

      if (allocated(nvlst)) then
        n1=size(bead%nvlst)
        call prmem_request(nvlst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nvlst(i) = bead%nvlst(i)
        ENDDO
      endif

      if(allocated(vlst)) then
        n1=size(bead%vlst,1)
        n2=size(bead%vlst,2)
        call prmem_request(vlst,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        vlst(i,j) = bead%vlst(i,j)
        ENDDO ; ENDDO
      endif

      if(allocated(nelst)) then
        n1=size(bead%nelst)
        call prmem_request(nelst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nelst(i) = bead%nelst(i)
        ENDDO
      endif

      if (allocated(elst)) then  
        n1=size(bead%elst,1)
        n2=size(bead%elst,2)
        call prmem_request(elst,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        elst(i,j) = bead%elst(i,j)
        ENDDO ; ENDDO
      end if

      if (allocated(nelstc)) then   
        n1=size(bead%nelstc)
        call prmem_request(nelstc,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nelstc(i) = bead%nelstc(i)
        ENDDO
      end if

      if (allocated(shortelst)) then 
        n1=size(bead%shortelst,1)
        n2=size(bead%shortelst,2)
        call prmem_request(shortelst,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        shortelst(i,j) = bead%shortelst(i,j)
        ENDDO ; ENDDO
      end if

      if (allocated(nshortelst)) then      
        n1=size(bead%nshortelst)
        call prmem_request(nshortelst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nshortelst(i) = bead%nshortelst(i)
        ENDDO
      end if

      if (allocated(nshortelstc)) then   
        n1=size(bead%nshortelstc)
        call prmem_request(nshortelstc,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nshortelstc(i) = bead%nshortelstc(i)
        ENDDO
      end if

      if (allocated(eblst)) then   
        n1=size(bead%eblst)
        call prmem_request(eblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        eblst(i) = bead%eblst(i)
        ENDDO
      end if

      if (allocated(ieblst)) then  
        n1=size(bead%ieblst)
        call prmem_request(ieblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ieblst(i) = bead%ieblst(i)
        ENDDO
      end if

      if (allocated(shorteblst)) then 
        n1=size(bead%shorteblst)
        call prmem_request(shorteblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        shorteblst(i) = bead%shorteblst(i)
        ENDDO
      end if

      if (allocated(ishorteblst)) then   
        n1=size(bead%ishorteblst)
        call prmem_request(ishorteblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ishorteblst(i) = bead%ishorteblst(i)
        ENDDO
      end if
      

      if (allocated(nshortvlst)) then 
        n1=size(bead%nshortvlst)
        call prmem_request(nshortvlst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        nshortvlst(i) = bead%nshortvlst(i)
        ENDDO
      end if

      if (allocated(shortvlst)) then   
        n1=size(bead%shortvlst,1)
        n2=size(bead%shortvlst,2)
        call prmem_request(shortvlst,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        shortvlst(i,j) = bead%shortvlst(i,j)
        ENDDO ; ENDDO
      end if

      if (allocated(vblst)) then   
        n1=size(bead%vblst)
        call prmem_request(vblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        vblst(i) = bead%vblst(i)
        ENDDO
      end if

      if (allocated(ivblst)) then  
        n1=size(bead%ivblst)
        call prmem_request(ivblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ivblst(i) = bead%ivblst(i)
        ENDDO
      end if

      if (allocated(shortvblst)) then  
        n1=size(bead%shortvblst)
        call prmem_request(shortvblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        shortvblst(i) = bead%shortvblst(i)
        ENDDO
      end if

      if (allocated(ishortvblst)) then
        n1=size(bead%ishortvblst)
        call prmem_request(ishortvblst,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ishortvblst(i) = bead%ishortvblst(i)
        ENDDO
      end if

      if(allocated(celle_glob))  then
        n1=size(bead%celle_glob)
        call prmem_request(celle_glob,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_glob(i) = bead%celle_glob(i)
        ENDDO
      endif

      if(allocated(celle_pole))  then
        n1=size(bead%celle_pole)
        call prmem_request(celle_pole,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_pole(i) = bead%celle_pole(i)
        ENDDO
      endif

      if(allocated(celle_plocnl))  then
        n1=size(bead%celle_plocnl)
        call prmem_request(celle_plocnl,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_plocnl(i) = bead%celle_plocnl(i)
        ENDDO
      endif
      
      if(allocated(celle_key))  then
        n1=size(bead%celle_key)
        call prmem_request(celle_key,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_key(i) = bead%celle_key(i)
        ENDDO
      endif

      if(allocated(celle_chg))  then
        n1=size(bead%celle_chg)
        call prmem_request(celle_chg,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        celle_chg(i) = bead%celle_chg(i)
        ENDDO
      endif

      if(allocated(cellv_key))  then
        n1=size(bead%cellv_key)
        call prmem_request(cellv_key,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        cellv_key(i) = bead%cellv_key(i)
        ENDDO
      endif

      if(allocated(cellv_glob))  then
        n1=size(bead%cellv_glob)
        call prmem_request(cellv_glob,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        cellv_glob(i) = bead%cellv_glob(i)
        ENDDO
      endif

      if(allocated(cellv_loc))  then
        n1=size(bead%cellv_loc)
        call prmem_request(cellv_loc,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        cellv_loc(i) = bead%cellv_loc(i)
        ENDDO
      endif

       if(allocated(cellv_jvdw))  then
        n1=size(bead%cellv_jvdw)
        call prmem_request(cellv_jvdw,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        cellv_jvdw(i) = bead%cellv_jvdw(i)
        ENDDO
      endif

      !SCALING FACTORS
      n_vscale=bead%n_vscale
      n_mscale=bead%n_mscale
      n_cscale=bead%n_cscale
      n_uscale=bead%n_uscale
      n_dpscale=bead%n_dpscale
      n_dpuscale=bead%n_dpuscale

      if(allocated(vcorrect_ik).and.size(vcorrect_ik)>0) then
        n1=size(bead%vcorrect_ik,1)
        n2=size(bead%vcorrect_ik,2)
        call prmem_request(vcorrect_ik,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        vcorrect_ik(i,j) = bead%vcorrect_ik(i,j)
        ENDDO ; ENDDO
      endif

      if(allocated(vcorrect_scale).and.size(vcorrect_scale)>0) then
        n1=size(bead%vcorrect_scale)
        call prmem_request(vcorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        vcorrect_scale(i) = bead%vcorrect_scale(i)
        ENDDO
      endif

      if(allocated(mcorrect_ik).and.size(mcorrect_ik)>0) then
        n1=size(bead%mcorrect_ik,1)
        n2=size(bead%mcorrect_ik,2)
        call prmem_request(mcorrect_ik,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        mcorrect_ik(i,j) = bead%mcorrect_ik(i,j)
        ENDDO ; ENDDO
      endif

      if(allocated(mcorrect_scale).and.size(mcorrect_scale)>0) then
        n1=size(bead%mcorrect_scale)
        call prmem_request(mcorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        mcorrect_scale(i) = bead%mcorrect_scale(i)
        ENDDO
      endif

      if(allocated(ccorrect_ik).and.size(ccorrect_ik)>0) then
        n1=size(bead%ccorrect_ik,1)
        n2=size(bead%ccorrect_ik,2)
        call prmem_request(ccorrect_ik,n1,n2
     &        ,async=.true.)
!$acc parallel loop collapse(2) async
        DO j=1,n2; DO i=1,n1
        ccorrect_ik(i,j) = bead%ccorrect_ik(i,j)
        ENDDO ; ENDDO
      endif

      if(allocated(ccorrect_scale).and.size(ccorrect_scale)>0) then
        n1=size(bead%ccorrect_scale)
        call prmem_request(ccorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ccorrect_scale(i) = bead%ccorrect_scale(i)
        ENDDO
      endif

      if(allocated(ucorrect_ik).and.size(ucorrect_ik)>0) then
        n1=size(bead%ucorrect_ik)
        call prmem_request(ucorrect_ik,n1
     &        ,async=.true.)
        ucorrect_ik(1:n1) = bead%ucorrect_ik(1:n1)
!$acc parallel loop async
        DO i=1,n1
        ucorrect_ik(i) = bead%ucorrect_ik(i)
        ENDDO
      endif

      if(allocated(ucorrect_scale).and.size(ucorrect_scale)>0) then
        n1=size(bead%ucorrect_scale)
        call prmem_request(ucorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        ucorrect_scale(i) = bead%ucorrect_scale(i)
        ENDDO
      endif

      if(allocated(dpcorrect_ik).and.size(dpcorrect_ik)>0) then
        n1=size(bead%dpcorrect_ik)
        call prmem_request(dpcorrect_ik,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        dpcorrect_ik(i) = bead%dpcorrect_ik(i)
        ENDDO
      endif

      if(allocated(dpcorrect_scale).and.size(dpcorrect_scale)>0) then
        n1=size(bead%dpcorrect_scale)
        call prmem_request(dpcorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        dpcorrect_scale(i) = bead%dpcorrect_scale(i)
        ENDDO
      endif

      if(allocated(dpucorrect_ik).and.size(dpucorrect_ik)>0) then
        n1=size(bead%dpucorrect_ik)
        call prmem_request(dpucorrect_ik,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        dpucorrect_ik(i) = bead%dpucorrect_ik(i)
        ENDDO
      endif

      if(allocated(dpucorrect_scale).and.size(dpucorrect_scale)>0) then
        n1=size(bead%dpucorrect_scale)
        call prmem_request(dpucorrect_scale,n1
     &        ,async=.true.)
!$acc parallel loop async
        DO i=1,n1
        dpucorrect_scale(i) = bead%dpucorrect_scale(i)
        ENDDO
      endif


c
c     TIME
c 
      timestep = bead%timestep

      ! write(0,*) "pushbead done"

      !SYNCHRONIZE GPU with CPU
!$acc wait
!$acc end data

      end subroutine pushbead


      subroutine compute_observables_pi(pos,vel,forces,istep,dt)
      use atoms
      use units
      use atmtyp
      use math
      use boxes
      use mdstuf
      use bath
      use mpi
      use domdec
      !use qtb
      IMPLICIT NONE
      real(8), intent(in),allocatable :: pos(:,:,:),vel(:,:,:)
     &                                   ,forces(:,:,:)
      real(r_p), intent(in) :: dt
      integer, intent(in) :: istep
      real(8), allocatable :: centroid(:,:),vel_centroid(:,:)
      real(8) :: omp,omp2,dedv_mean
      integer :: ibead,i,j,k,ierr
      real(8) :: buffer_energy(4)

!$acc wait
c
c     reduce potential and kinetic energies
c
      buffer_energy=0
      DO ibead=1,nbeadsloc        
        buffer_energy(1)=buffer_energy(1) + beadsloc(ibead)%eksum
        buffer_energy(2)=buffer_energy(2) + beadsloc(ibead)%dedv
        if(contract) then
          buffer_energy(3)=buffer_energy(3) + beadsloc(ibead)%eintra
        else
          buffer_energy(3)=buffer_energy(3) + beadsloc(ibead)%epot
        endif
      ENDDO

      if(contract) then
        DO ibead=1,nbeadsloc_ctr
          buffer_energy(4)=buffer_energy(4) + beadsloc_ctr(ibead)%einter
        ENDDO
      endif

      if ((ranktot.eq.0).and.(contract)) then
         call MPI_REDUCE(MPI_IN_PLACE,buffer_energy,4,MPI_REAL8
     $      ,MPI_SUM,0,MPI_COMM_WORLD,ierr)
         eksumpi_loc=buffer_energy(1)/(nbeads*nproc)
         dedv_mean=buffer_energy(2)/(nbeads*nproc)
         eintrapi_loc=buffer_energy(3)/(nbeads*nproc)
         einterpi_loc=buffer_energy(4)/(nbeads_ctr*nproc)
         epotpi_loc =  eintrapi_loc +  einterpi_loc
      else if ((ranktot.eq.0).and.(contract.eqv..false.)) then
         call MPI_REDUCE(MPI_IN_PLACE,buffer_energy,3,MPI_REAL8
     $      ,MPI_SUM,0,MPI_COMM_WORLD,ierr)         
         eksumpi_loc=buffer_energy(1)/(nbeads*nproc)
         dedv_mean=buffer_energy(2)/(nbeads*nproc)
         epotpi_loc=buffer_energy(3)/(nbeads*nproc)
      endif

      if((ranktot.ne.0).and.(contract)) then
          call MPI_REDUCE(buffer_energy,buffer_energy,4,MPI_REAL8
     $     ,MPI_SUM,0,MPI_COMM_WORLD,ierr)
      else if ((ranktot.ne.0).and.(contract.eqv..false.)) then
        call MPI_REDUCE(buffer_energy,buffer_energy,3,MPI_REAL8
     $     ,MPI_SUM,0,MPI_COMM_WORLD,ierr)
      end if
      

      if(ranktot.eq.0) then
        allocate(centroid(3,n),vel_centroid(3,n))
        centroid(:,:)=0.d0
        vel_centroid(:,:)=0.d0
        DO ibead=1,nbeads
          DO i=1,n
            centroid(:,i)=centroid(:,i)+pos(:,i,ibead)
            vel_centroid(:,i)=vel_centroid(:,i)+vel(:,i,ibead)
          ENDDO
        ENDDO  
        centroid(:,:)=centroid(:,:)/REAL(nbeads)
        vel_centroid(:,:)=vel_centroid(:,:)/REAL(nbeads) 

        Ekcentroid=0.d0
        DO i=1,n ; DO j=1,3          
          Ekcentroid=Ekcentroid+mass(i)*vel_centroid(j,i)**2
        ENDDO ; ENDDO
        Ekcentroid=0.5d0*Ekcentroid/convert

        !if (ir) then
        !  k = mod(istep-1,nseg)+1
        !  vad(:,:,k)=vel_centroid(:,:)
        !  if ((mod(istep,nseg).eq.0)) then
        !      call irspectra_pimd
        !      compteur=compteur+1
        ! endif
        !endif

        deallocate(vel_centroid)

        omp=nbeads*boltzmann*kelvin/hbar        
        omp2=omp*omp

c       COMPUTE PRIMITIVE KINETIC ENERGY
        ekprim=0.d0
        DO ibead=1,nbeads-1
          DO i=1,n
        !    if (atomic(i).eq.0) cycle
            DO j=1,3
              ekprim = ekprim - 0.5*mass(i)*omp2
     &          *(pos(j,i,ibead+1)-pos(j,i,ibead))**2
            ENDDO
          ENDDO
        ENDDO  
        DO i=1,n
        ! if (atomic(i).eq.0) cycle
          DO j=1,3
            ekprim = ekprim - 0.5*mass(i)*omp2
     &          *(pos(j,i,nbeads)-pos(j,i,1))**2
          ENDDO
        ENDDO  
        ekprim = (ekprim/nbeads
     &          + 0.5*nbeads*nfree*boltzmann*kelvin)/convert
        !ekprim = ekprim/nbeads/convert + eksumpi_loc

c       COMPUTE VIRIAL KINETIC ENERGY
        ekvir=0.d0
        DO ibead=1,nbeads
          DO i=1,n
        !  if (atomic(i).eq.0) cycle
            DO j=1,3
              ekvir=ekvir+(pos(j,i,ibead)-centroid(j,i))
     &                      *forces(j,i,ibead)
            ENDDO
          ENDDO
        ENDDO
        ekvir=0.5d0*ekvir/nbeads

        presvir = prescon*( -dedv_mean + 2.d0*(Ekcentroid
     &               - ekvir)/(3.d0*volbox) )

        ekvir=0.5d0*nfree*boltzmann*kelvin/convert-ekvir
        !ekvir= Ekcentroid - ekvir
        temppi = 2.0d0 * ekvir / (nfree * gasconst)
        temppi_cl = 2.0d0 * eksumpi_loc / (nfree * gasconst)

      endif

      end subroutine compute_observables_pi
      

      subroutine rescale_box_pi(istep)
c      rescale the simulation box according to extvol computed by ranktot 0
        use mpi
        use domdec
        use bath
        use boxes, only: volbox,xbox,ybox,zbox
        implicit none
        integer, intent(in) :: istep
        integer :: ierr
        real(8) :: third,scale

c       broadcast new volume  
        call MPI_BCAST(extvol,1,MPI_TPREC,0,MPI_COMM_WORLD,ierr)
        !call MPI_BARRIER(MPI_COMM_WORLD,ierr)
c       rescale box
        third=1.d0/3.d0
        scale=(extvol/extvolold)**third
        xbox = (extvol)**third
        ybox = (extvol)**third
        zbox = (extvol)**third  
        
!$acc update device(xbox,ybox,zbox)
c
c     propagate the new box dimensions to other lattice values
c 
        call lattice   
        call ddpme3dnpt(scale,istep)
      end subroutine rescale_box_pi

c ---------------------------------------------------------------------
c    COMMUNICATION ROUTINES

      subroutine prepare_loaded_bead (istep)
      use atmtyp
      use atomsMirror
      use cutoff
      use domdec
      use energi
      use freeze
      use mdstuf
      use moldyn
      use timestat
      use units
      use usage
      use mpi
      implicit none
      integer, intent(in) :: istep
      real*8 time0,time1
      real*8 oterm,hterm
      integer :: i,iglob

c     Reassign the particules that have changed of domain
c
c     -> real space
c
      time0 = mpi_wtime()
c
      call reassign
c
c     -> reciprocal space
c
      call reassignpme(.false.)
      time1 = mpi_wtime()
      timereneig = timereneig + time1 - time0
c
c     communicate positions
c
      time0 = mpi_wtime()
      call commpos
      call commposrec
      time1 = mpi_wtime()
      timecommstep = timecommstep + time1 - time0

      call reCast_position
c
c
      call reinitnl(istep)
c
      time0 = mpi_wtime()
      call mechanicstep(istep)
      time1 = mpi_wtime()
c
      timeparam = timeparam + time1 - time0
c
      time0 = mpi_wtime()
      call allocstep
      time1 = mpi_wtime()
      timeclear = timeclear  + time1 - time0

      !rebuild the neighbor lists
      if (use_list) call nblist(istep)

!$acc wait
          
      end subroutine prepare_loaded_bead



      subroutine get_polymer_info(polymer,beads
     &   ,get_nloccomm,get_globbeadcomm)
      use domdec
      use mpi
      use atoms
      use atmtyp
      use units
      implicit none
      type(POLYMER_COMM_TYPE), intent(inout) :: polymer
      type(BEAD_TYPE), intent(in) :: beads(:)
      LOGICAL, intent(in) :: get_nloccomm,get_globbeadcomm 
      integer i,l,iproc,ibead,ierr,iglob
      integer status(MPI_STATUS_SIZE),tagmpi
      integer, allocatable :: reqrec(:),reqsend(:),buffer(:,:)
      integer :: nsend,isend

      allocate(reqsend(nproctot))
      allocate(reqrec(nproctot))

      if(allocated(polymer%nbeadscomm)) deallocate(polymer%nbeadscomm)
      nsend=0
      if(get_nloccomm) then        
        if(allocated(polymer%nloccomm)) deallocate(polymer%nloccomm)
        nsend=nsend+1
      endif
      if(get_globbeadcomm) then      
        if(allocated(polymer%globbeadcomm)) then 
          deallocate(polymer%globbeadcomm)
        endif
        nsend=nsend+1
      endif      

c     first get the number of beads per process
c   
      if (ranktot.eq.0) then
        allocate(polymer%nbeadscomm(nproctot))  
        polymer%nbeadscomm(1)=size(beads)
        do i = 1, nproctot-1
          tagmpi = nproctot*ranktot + i + 1
          call MPI_IRECV(polymer%nbeadscomm(i+1),1,
     $     MPI_INT,i,tagmpi,MPI_COMM_WORLD,reqrec(i),ierr)
          call MPI_WAIT(reqrec(i),status,ierr)
c          write(*,*) 'nbeads of ',i,' = ',nbeadscomm(i+1)
        end do
       
      else
        tagmpi = ranktot + 1
        call MPI_ISEND(size(beads),1,MPI_INT,0,tagmpi,MPI_COMM_WORLD,
     $   reqsend(1),ierr)
        call MPI_WAIT(reqsend(1),status,ierr)
      end if

c
c     get the number of atoms per process
c   
      if(nsend==0) return

      if (ranktot.eq.0) then        
        polymer%nbeadsloc_max = maxval(polymer%nbeadscomm)
        if(get_nloccomm) then
          allocate(polymer%nloccomm(polymer%nbeadsloc_max,nproctot))
          do i=1,size(beads) 
            polymer%nloccomm(i,1)=beads(i)%nloc
          enddo
        endif
        if(get_globbeadcomm) then
          allocate(polymer%globbeadcomm(polymer%nbeadsloc_max,nproctot))
          do i=1,size(beads) 
            polymer%globbeadcomm(i,1)=beads(i)%ibead_glob
          enddo
        endif        
        do i = 1, nproctot-1
          allocate(buffer(polymer%nbeadscomm(i+1),nsend))
          tagmpi = i + 1
          call MPI_IRECV(buffer,nsend*polymer%nbeadscomm(i+1),
     $     MPI_INT,i,tagmpi,MPI_COMM_WORLD,reqrec(i),ierr)
          call MPI_WAIT(reqrec(i),status,ierr)
c          write(*,*) 'nloc of ',i,' = ',nloccomm(i+1)
          isend=1
          if(get_nloccomm) then
            polymer%nloccomm(1:polymer%nbeadscomm(i+1),i+1)
     &         =buffer(:,isend)
            isend=isend+1
          endif
          if(get_globbeadcomm) then
            polymer%globbeadcomm(1:polymer%nbeadscomm(i+1),i+1)
     &         =buffer(:,isend)
            isend=isend+1
          endif
          deallocate(buffer)
        end do
      else
        tagmpi = ranktot + 1
        allocate(buffer(size(beads),nsend))
        isend=1
        if(get_nloccomm) then
          do i=1,size(beads) 
            buffer(i,isend)=beads(i)%nloc
          enddo
          isend=isend+1
        endif
        if(get_globbeadcomm) then
          do i=1,size(beads) 
            buffer(i,isend)=beads(i)%ibead_glob
          enddo
          isend=isend+1
        endif
        call MPI_ISEND(buffer,nsend*size(beads),MPI_INT
     $   ,0,tagmpi,MPI_COMM_WORLD,reqsend(1),ierr)
        call MPI_WAIT(reqsend(1),status,ierr)
      end if

      end subroutine get_polymer_info


      subroutine gather_polymer(polymer,beads, 
     &                send_pos,send_vel,send_forces)
      use domdec
      use mpi
      use atoms
      use atmtyp
      use units
      implicit none
      type(BEAD_TYPE), intent(in) :: beads(:)
      TYPE(POLYMER_COMM_TYPE), intent(inout) :: polymer
      ! pos_full,vel_full,forces_full will be allocated for ranktot 0 (and deallocated for all the other procs)
      ! get_repart_dof_beads must be called before to fill out the polymer info concerning parallelization
      LOGICAL, intent(in) :: send_pos,send_vel,send_forces
      integer i,j,k,l,iproc,ibead,ierr,iglob
      integer status(MPI_STATUS_SIZE),tagmpi
      real(r_p), allocatable :: buffer(:,:),indexposcomm(:,:,:,:)
      integer, allocatable :: reqrec(:),reqsend(:)
      integer :: nsend,isend,nloc_max

      allocate(reqsend(nproctot))
      allocate(reqrec(nproctot))

      nsend=1 ! always send repart_dof_beads
      if(send_pos) nsend = nsend + 3
      if(send_vel) nsend = nsend + 3
      if(send_forces) nsend = nsend + 3

      if(allocated(polymer%repart_dof_beads))then
        deallocate(polymer%repart_dof_beads)
      endif
      if(send_pos) then
        if(allocated(polymer%pos)) deallocate(polymer%pos)
      endif
      if(send_vel) then
        if(allocated(polymer%vel)) deallocate(polymer%vel)
      endif
      if(send_forces) then
        if(allocated(polymer%forces)) deallocate(polymer%forces)
      endif

c     gather number of beads and degrees of freedom
      call get_polymer_info(polymer,beads,.TRUE.,.TRUE.)

      if (ranktot.eq.0) then
        ! number of beads in the polymer is the sum of the communicated beads 
        ! divided by the spatial number of procs
        polymer%nbeads = SUM(polymer%nbeadscomm)/nproc        
        allocate(polymer%repart_dof_beads(n,polymer%nbeads,nproctot))
        allocate(indexposcomm(nsend,n,polymer%nbeads,nproctot))        
      end if     
      
c
c     get their indexes and positions, velocities and forces
c   
      if (ranktot.eq.0) then
        do i = 1, nproctot-1
          tagmpi = i + 1
          do k=1,polymer%nbeadscomm(i+1)
            call MPI_IRECV(indexposcomm(1,1,k,i+1),
     $     nsend*polymer%nloccomm(k,i+1),
     $     MPI_RPREC,i,tagmpi,MPI_COMM_WORLD,reqrec(i),ierr)
            call MPI_WAIT(reqrec(i),status,ierr)
          enddo
        end do
      else
        tagmpi = ranktot + 1        
        do k = 1, size(beads)
         allocate(buffer(nsend,beads(k)%nloc))
         buffer = 0.d0
         do i = 1, beads(k)%nloc
          iglob = beads(k)%glob(i)
          buffer(1,i) = real(iglob,r_p)
          isend=2
          if(send_pos) then
            buffer(isend,i) = beads(k)%x(iglob)
            buffer(isend+1,i) = beads(k)%y(iglob)
            buffer(isend+2,i) = beads(k)%z(iglob)
            isend = isend + 3
          endif

          if(send_vel) then
            buffer(isend,i) = beads(k)%v(1,iglob)
            buffer(isend+1,i) = beads(k)%v(2,iglob)
            buffer(isend+2,i) = beads(k)%v(3,iglob)
            isend = isend + 3
          endif

          if(send_forces) then
            buffer(isend,i)=beads(k)%a(1,iglob)*mass(iglob)/convert
            buffer(isend+1,i)=beads(k)%a(2,iglob)*mass(iglob)/convert
            buffer(isend+2,i)=beads(k)%a(3,iglob)*mass(iglob)/convert
            isend = isend + 3
          endif
         end do
         call MPI_ISEND(buffer,nsend*beads(k)%nloc,MPI_RPREC
     $   ,0,tagmpi,MPI_COMM_WORLD,reqsend(1),ierr)
         call MPI_WAIT(reqsend(1),status,ierr)

         deallocate(buffer)
        enddo
      end if
      
      if(ranktot .eq. 0) then
c       ORDER POSITIONS AND VELOCITES IN pos_full AND vel_full
        if(send_pos) allocate(polymer%pos(3,n,polymer%nbeads))
        if(send_vel) allocate(polymer%vel(3,n,polymer%nbeads))
        if(send_forces) allocate(polymer%forces(3,n,polymer%nbeads))
          
        DO k=1,size(beads)
          DO i=1,beads(k)%nloc
            iglob=beads(k)%glob(i)
            if(send_pos) then
              polymer%pos(1,iglob,k) =beads(k)%x(iglob)
              polymer%pos(2,iglob,k) =beads(k)%y(iglob)
              polymer%pos(3,iglob,k) =beads(k)%z(iglob)
            endif
            if(send_vel) polymer%vel(:,iglob,k) =beads(k)%v(:,iglob)
            if(send_forces) then
              polymer%forces(:,iglob,k)= 
     &             beads(k)%a(:,iglob)*mass(iglob)/convert
            endif
          ENDDO
        ENDDO

        do iproc = 1, nproctot-1
          do k=1,polymer%nbeadscomm(iproc+1)
            ibead = polymer%globbeadcomm(k,iproc+1)
            DO i=1,polymer%nloccomm(k,iproc+1)      
              isend=1   
              
              iglob=nint(indexposcomm(1,i,k,iproc+1))
              polymer%repart_dof_beads(i,k,iproc+1)=iglob
              isend=1
              if(send_pos) then
                DO j=1,3     
                 polymer%pos(j,iglob,ibead)=
     &               indexposcomm(j+isend,i,k,iproc+1)  
                ENDDO
                isend=isend+3
              endif
              if(send_vel) then
                DO j=1,3     
                  polymer%vel(j,iglob,ibead)=
     &               indexposcomm(j+isend,i,k,iproc+1)  
                ENDDO
                isend=isend+3
              endif
              if(send_forces) then
                DO j=1,3
                  polymer%forces(j,iglob,ibead)=
     &               indexposcomm(j+isend,i,k,iproc+1)  
                ENDDO
                isend=isend+3
              endif
            ENDDO 
          enddo
        enddo

        deallocate(indexposcomm)        
      endif

      deallocate(reqsend,reqrec)

      end subroutine gather_polymer

      subroutine broadcast_polymer(polymer,beads, 
     &                send_pos,send_vel,send_forces)
      use domdec
      use mpi
      use atoms
      use atmtyp
      use units
      implicit none
      type(BEAD_TYPE), intent(inout) :: beads(:)
      TYPE(POLYMER_COMM_TYPE), intent(inout) :: polymer
      LOGICAL, intent(in) :: send_pos,send_vel,send_forces
      integer i,j,k,l,iproc,ibead,ierr,iglob
      integer status(MPI_STATUS_SIZE),tagmpi
      real(r_p), allocatable :: buffer(:,:),indexposcomm(:,:,:,:)
      integer, allocatable :: reqrec(:),reqsend(:)
      integer :: nsend,isend,nloc_max

      allocate(reqsend(nproctot))
      allocate(reqrec(nproctot))

      nsend=0
      if(send_pos) nsend = nsend + 3
      if(send_vel) nsend = nsend + 3
      if(send_forces) nsend = nsend + 3
      if(nsend==0 .and. ranktot==0) then
        write(0,*) "Error: broadcast_polymer ",
     &     "was called without requesting any send"
        call fatal
      endif
      
      if(ranktot.eq.0) then
        if(.not.allocated(polymer%repart_dof_beads)) then
          write(0,*) "Error: repart_dof_beads not allocated"
     &     ," in broadcast_polymer"
          call fatal
        endif
c       PUT BACK POSITIONS AND VELOCITES AT CORRECT INDICES
        allocate(indexposcomm(nsend,n,polymer%nbeads,nproctot))
        DO k=1,size(beads)
          DO i=1,beads(k)%nloc 
            iglob=beads(k)%glob(i)
            if(send_pos) then
              beads(k)%x(iglob)=polymer%pos(1,iglob,k)
              beads(k)%y(iglob)=polymer%pos(2,iglob,k)
              beads(k)%z(iglob)=polymer%pos(3,iglob,k)
            endif
            if(send_vel) then
              beads(k)%v(:,iglob)=polymer%vel(:,iglob,k)
            endif
            if(send_forces) then
              beads(k)%a(:,iglob) = 
     &           polymer%forces(:,iglob,k)/mass(iglob)*convert
            endif
          ENDDO
        ENDDO

        do iproc = 1, nproctot-1
          do k=1,polymer%nbeadscomm(iproc+1)
            ibead = polymer%globbeadcomm(k,iproc+1)
            DO i=1,polymer%nloccomm(k,iproc+1)
              iglob=polymer%repart_dof_beads(i,k,iproc+1)
              isend=0
              if(send_pos) then
                DO j=1,3
                  indexposcomm(j+isend,i,k,iproc+1)=
     &               polymer%pos(j,iglob,ibead) 
                ENDDO
                isend=isend+3
              endif
              if(send_vel) then
                DO j=1,3
                  indexposcomm(j+isend,i,k,iproc+1)=
     &               polymer%vel(j,iglob,ibead) 
                ENDDO
                isend=isend+3
              endif
              if(send_forces) then
                DO j=1,3
                  indexposcomm(j+isend,i,k,iproc+1)=
     &               polymer%forces(j,iglob,ibead) 
                ENDDO
                isend=isend+3
              endif
            ENDDO
          enddo     
        enddo   
      endif
c
c     communicate back positions
c
      if (ranktot.eq.0) then
        do i = 1, nproctot-1
          tagmpi = i + 1
          do k=1,polymer%nbeadscomm(i+1)
            call MPI_ISEND(indexposcomm(1,1,k,i+1)
     $     ,nsend*polymer%nloccomm(k,i+1)
     $     ,MPI_RPREC,i,tagmpi,MPI_COMM_WORLD,reqsend(i),ierr)
            call MPI_WAIT(reqsend(i),status,ierr)
          enddo
        end do

        deallocate(indexposcomm)
      else        
        
        tagmpi = ranktot + 1        
        do k = 1, size(beads)
          allocate(buffer(nsend,beads(k)%nloc))
          call MPI_IRECV(buffer,nsend*beads(k)%nloc,MPI_RPREC
     $   ,0,tagmpi,MPI_COMM_WORLD,reqrec(1),ierr)
          call MPI_WAIT(reqrec(1),status,ierr)
          do i = 1, beads(k)%nloc
            iglob = beads(k)%glob(i)
            isend=0
            if(send_pos) then
              beads(k)%x(iglob) = buffer(isend+1,i)
              beads(k)%y(iglob) = buffer(isend+2,i)
              beads(k)%z(iglob) = buffer(isend+3,i)
              isend=isend+3
            endif
            if(send_vel) then
              DO j=1,3
                beads(k)%v(j,iglob) = buffer(j+isend,i)
              ENDDO
              isend=isend+3
            endif
            if(send_forces) then
              DO j=1,3
                beads(k)%a(j,iglob) = buffer(j+isend,i)
     &            /mass(iglob)*convert
              ENDDO
              isend=isend+3
            endif
           ! write(*,*) 'j = ',glob(j),'k = ',k,'x = ',pospi(1,glob(j),k)
          end do
          deallocate(buffer)
        end do
      end if

      deallocate(reqsend,reqrec)

      end subroutine broadcast_polymer

c     -----------------------------------------
c      CONTRACTION SUBROUTINES
      

      subroutine contract_polymer(polymer,polymer_ctr)
        use atoms
        implicit none
        type(POLYMER_COMM_TYPE), intent(in) :: polymer
        type(POLYMER_COMM_TYPE), intent(inout) :: polymer_ctr
        integer :: i,j,k

        if(allocated(polymer_ctr%pos)) 
     &               deallocate(polymer_ctr%pos)
        allocate(polymer_ctr%pos(3,n,nbeads_ctr))

        DO i=1,n ; DO j=1,3
          polymer_ctr%pos(j,i,:)=matmul(contractor_mat
     &                    ,polymer%pos(j,i,:))
        ENDDO ; ENDDO        

        !do k=1,nbeads_ctr
        !  do i=1,n
        !    write(17+k,*) i,polymer_ctr%pos(:,i,k)
        !  enddo
        !  FLUSH(17+k)
        !enddo
        !call fatal

      end subroutine contract_polymer

      subroutine project_forces_contract(polymer,polymer_ctr)
        use atoms
        implicit none
        type(POLYMER_COMM_TYPE),intent(inout) :: polymer
        type(POLYMER_COMM_TYPE),intent(in) :: polymer_ctr
        integer :: i,j

        if(allocated(polymer%forces_slow)) then
          deallocate(polymer%forces_slow)
        endif
        allocate(polymer%forces_slow(3,n,nbeads))
      
        DO i=1,n ; DO j=1,3
          polymer%forces_slow(j,i,:)=matmul(uncontractor_mat
     &         ,polymer_ctr%forces(j,i,:))
        ENDDO ; ENDDO

        if(allocated(polymer%forces)) then
          polymer%forces=polymer%forces+polymer%forces_slow
        endif

       
      end subroutine project_forces_contract

      end module
