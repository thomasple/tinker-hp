c
c     Sorbonne University
c     Washington University in Saint Louis
c     University of Texas at Austin
c
c     ################################################################
c     ##                                                            ##
c     ##  chgpot.i  --  specifics of charge-charge functional form  ##
c     ##                                                            ##
c     ################################################################
c
c
c     electric   energy factor in kcal/mole for current force field
c     dielec     dielectric constant for electrostatic interactions
c     ebuffer    electrostatic buffering constant added to distance
c     c2scale    factor by which 1-2 charge interactions are scaled
c     c3scale    factor by which 1-3 charge interactions are scaled
c     c4scale    factor by which 1-4 charge interactions are scaled
c     c5scale    factor by which 1-5 charge interactions are scaled
c     neutnbr    logical flag governing use of neutral group neighbors
c     neutcut    logical flag governing use of neutral group cutoffs
c
c
      real*8 electric
      real*8 dielec,ebuffer
      real*8 c2scale,c3scale
      real*8 c4scale,c5scale
      logical neutnbr,neutcut
      common /chgpot/ electric,dielec,ebuffer,c2scale,c3scale,c4scale,
     &                c5scale,neutnbr,neutcut
