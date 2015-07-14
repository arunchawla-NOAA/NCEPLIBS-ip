 SUBROUTINE GDSWZD(IGDTNUM,IGDTMPL,IGDTLEN,IOPT,NPTS, &
                   FILL,XPTS,YPTS,RLON,RLAT,NRET, &
                   LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD     GRID DEFINITION SECTION WIZARD
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM DECODES THE GRIB 2 GRID DEFINITION
!           TEMPLATE (PASSED IN INTEGER FROM AS DECODED BY THE
!           NCEP G2 LIBRARY) AND RETURNS ONE OF THE FOLLOWING:
!             (IOPT= 0) GRID AND EARTH COORDINATES OF ALL GRID POINTS
!             (IOPT=+1) EARTH COORDINATES OF SELECTED GRID COORDINATES
!             (IOPT=-1) GRID COORDINATES OF SELECTED EARTH COORDINATES
!           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS,
!           WHERE "IGDTNUM" IS THE GRID DEFINTION TEMPLATE NUMBER:
!             (IGDTNUM=00) EQUIDISTANT CYLINDRICAL
!             (IGDTNUM=01) ROTATED EQUIDISTANT CYLINDRICAL. "E" AND
!                          NON-"E" STAGGERED
!             (IGDTNUM=10) MERCATOR CYLINDRICAL
!             (IGDTNUM=20) POLAR STEREOGRAPHIC AZIMUTHAL
!             (IGDTNUM=30) LAMBERT CONFORMAL CONICAL
!             (IGDTNUM=40) GAUSSIAN CYLINDRICAL
!           IF THE SELECTED COORDINATES ARE MORE THAN ONE GRIDPOINT
!           BEYOND THE THE EDGES OF THE GRID DOMAIN, THEN THE RELEVANT
!           OUTPUT ELEMENTS ARE SET TO FILL VALUES.  ALSO IF IOPT=0,
!           IF THE NUMBER OF GRID POINTS EXCEEDS THE NUMBER ALLOTTED,
!           THEN ALL THE OUTPUT ELEMENTS ARE SET TO FILL VALUES.
!           THE ACTUAL NUMBER OF VALID POINTS COMPUTED IS RETURNED TOO.
!           OPTIONALLY, THE VECTOR ROTATIONS AND THE MAP JACOBIANS
!           FOR THIS GRID MAY BE RETURNED AS WELL.
!
! PROGRAM HISTORY LOG:
! 1996-04-10  IREDELL
! 1997-10-20  IREDELL  INCLUDE MAP OPTIONS
! 1998-08-20  BALDWIN  ADD TYPE 203 2-D ETA GRIDS
! 2008-04-11  GAYNO    ADD TYPE 205 - ROT LAT/LON B-STAGGER
! 2012-08-02  GAYNO    FIX COMPUTATION OF I/J FOR 203 GRIDS WITH
!                      NSCAN /= 0.
! 2015-07-13  GAYNO    CONVERT TO GRIB 2. REPLACE GRIB 1 KGDS ARRAY
!                      WITH GRIB 2 GRID DEFINITION TEMPLATE ARRAY.
!                      REMOVED CALLS TO ROUTINES GDSWZDC9 AND
!                      GDSWZDCA.  THESE ROUTINES WORKED FOR
!                      ROTATED LAT/LON GRIDS THAT ARE NOW
!                      OBSOLETE UNDER THE GRIB 2 STANDARD.
!
! USAGE:  CALL GDSWZD(IGDTNUM,IGDTMPL,IGDTLEN,IOPT,NPTS,FILL, &
!                  XPTS,YPTS,RLON,RLAT,NRET, &
!                  LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
!
!   INPUT ARGUMENT LIST:
!     IGDTNUM  - INTEGER GRID DEFINITION TEMPLATE NUMBER.  
!                CORRESPONDS TO THE GFLD%IGDTNUM COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     IGDTMPL  - INTEGER (IGDTLEN) GRID DEFINITION TEMPLATE ARRAY.
!                CORRESPONDS TO THE GFLD%IGDTMPL COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     IGDTLEN  - INTEGER NUMBER OF ELEMENTS OF THE GRID DEFINITION
!                TEMPLATE ARRAY.  CORRESPONDS TO THE GFLD%IGDTLEN
!                COMPONENT OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     IOPT     - INTEGER OPTION FLAG
!                ( 0 TO COMPUTE EARTH COORDS OF ALL THE GRID POINTS)
!                (+1 TO COMPUTE EARTH COORDS OF SELECTED GRID COORDS)
!                (-1 TO COMPUTE GRID COORDS OF SELECTED EARTH COORDS)
!     NPTS     - INTEGER MAXIMUM NUMBER OF COORDINATES
!     FILL     - REAL FILL VALUE TO SET INVALID OUTPUT DATA
!                (MUST BE IMPOSSIBLE VALUE; SUGGESTED VALUE: -9999.)
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT>0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT>0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT<0
!                (ACCEPTABLE RANGE: -360. TO 360.)
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT<0
!                (ACCEPTABLE RANGE: -90. TO 90.)
!     LROT     - INTEGER FLAG TO RETURN VECTOR ROTATIONS IF 1
!     LMAP     - INTEGER FLAG TO RETURN MAP JACOBIANS IF 1
!
!   OUTPUT ARGUMENT LIST:
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT<=0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT<=0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT>=0
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT>=0
!     NRET     - INTEGER NUMBER OF VALID POINTS COMPUTED
!                (-1 IF PROJECTION UNRECOGNIZED)
!     CROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION COSINES IF LROT=1
!     SROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION SINES IF LROT=1
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!     XLON     - REAL (NPTS) DX/DLON IN 1/DEGREES IF LMAP=1
!     XLAT     - REAL (NPTS) DX/DLAT IN 1/DEGREES IF LMAP=1
!     YLON     - REAL (NPTS) DY/DLON IN 1/DEGREES IF LMAP=1
!     YLAT     - REAL (NPTS) DY/DLAT IN 1/DEGREES IF LMAP=1
!     AREA     - REAL (NPTS) AREA WEIGHTS IN M**2 IF LMAP=1
!                (PROPORTIONAL TO THE SQUARE OF THE MAP FACTOR
!                 IN THE CASE OF CONFORMAL PROJECTIONS)
!
! SUBPROGRAMS CALLED:
!   GDSWZD00     GDS WIZARD FOR EQUIDISTANT CYLINDRICAL
!   GDSWZD01     GDS WIZARD FOR MERCATOR CYLINDRICAL
!   GDSWZD03     GDS WIZARD FOR LAMBERT CONFORMAL CONICAL
!   GDSWZD04     GDS WIZARD FOR GAUSSIAN CYLINDRICAL
!   GDSWZD05     GDS WIZARD FOR POLAR STEREOGRAPHIC AZIMUTHAL
!   GDSWZDCB     GDS WIZARD FOR ROTATED EQUIDISTANT CYLINDRICAL 2-D
!   GDSWZDCD     GDS WIZARD FOR ROTATED EQUIDISTANT CYLINDRICAL 2-D
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,        INTENT(IN   ) :: IGDTNUM, IGDTLEN
 INTEGER(KIND=4),INTENT(IN   ) :: IGDTMPL(IGDTLEN)
 INTEGER,        INTENT(IN   ) :: IOPT, LMAP, LROT, NPTS
 INTEGER,        INTENT(  OUT) :: NRET
!
 REAL,           INTENT(IN   ) :: FILL
 REAL,           INTENT(INOUT) :: RLON(NPTS),RLAT(NPTS)
 REAL,           INTENT(INOUT) :: XPTS(NPTS),YPTS(NPTS)
 REAL,           INTENT(  OUT) :: CROT(NPTS),SROT(NPTS)
 REAL,           INTENT(  OUT) :: XLON(NPTS),XLAT(NPTS)
 REAL,           INTENT(  OUT) :: YLON(NPTS),YLAT(NPTS),AREA(NPTS)
!
 INTEGER                       :: IS1, IM, JM, NM, KSCAN, NSCAN, N
 INTEGER                       :: IOPF, NN, I, J
 INTEGER                       :: I_OFFSET_ODD, I_OFFSET_EVEN
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE GRID COORDINATES FOR ALL GRID POINTS
 IF(IOPT.EQ.0) THEN
   IF(IGDTNUM==0) THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     NSCAN=MOD(IGDTMPL(19)/32,2)
   ELSEIF(IGDTNUM==1) THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     I_OFFSET_ODD=MOD(IGDTMPL(19)/8,2)
     I_OFFSET_EVEN=MOD(IGDTMPL(19)/4,2)
     IF(I_OFFSET_ODD/=I_OFFSET_EVEN)THEN
       IF(I_OFFSET_ODD==0) THEN
         IS1=(JM+1)/2
       ELSE
         IS1=JM/2
       ENDIF
     ENDIF
     NSCAN=MOD(IGDTMPL(19)/32,2)
   ELSEIF(IGDTNUM==10) THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     NSCAN=MOD(IGDTMPL(16)/32,2)
   ELSEIF(IGDTNUM==20) THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     NSCAN=MOD(IGDTMPL(18)/32,2)
   ELSEIF(IGDTNUM==30) THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     NSCAN=MOD(IGDTMPL(18)/32,2)
   ELSEIF(IGDTNUM==40)THEN
     IM=IGDTMPL(8)
     JM=IGDTMPL(9)
     NM=IM*JM
     NSCAN=MOD(IGDTMPL(19)/32,2)
   ELSE ! PROJECTION NOT RECOGNIZED
     RLAT=FILL
     RLON=FILL
     XPTS=FILL
     YPTS=FILL
     RETURN
   ENDIF
   IF(NM.LE.NPTS) THEN
     IF(IGDTNUM==1.AND.(I_OFFSET_ODD/=I_OFFSET_EVEN)) THEN
       KSCAN=I_OFFSET_ODD
       DO N=1,NM
         IF(NSCAN.EQ.0) THEN
           J=(N-1)/IM+1
           I=(N-IM*(J-1))*2-MOD(J+KSCAN,2)
         ELSE
           NN=(N*2)-1+KSCAN
           I = (NN-1)/JM + 1
           J = MOD(NN-1,JM) + 1
           IF (MOD(JM,2)==0.AND.MOD(I,2)==0.AND.KSCAN==0) J = J + 1
           IF (MOD(JM,2)==0.AND.MOD(I,2)==0.AND.KSCAN==1) J = J - 1
         ENDIF
         XPTS(N)=IS1+(I-(J-KSCAN))/2
         YPTS(N)=(I+(J-KSCAN))/2
       ENDDO
     ELSE
       DO N=1,NM
         IF(NSCAN.EQ.0) THEN
           J=(N-1)/IM+1
           I=N-IM*(J-1)
         ELSE
           I=(N-1)/JM+1
           J=N-JM*(I-1)
         ENDIF
         XPTS(N)=I
         YPTS(N)=J
       ENDDO
     ENDIF
     DO N=NM+1,NPTS
       XPTS(N)=FILL
       YPTS(N)=FILL
     ENDDO
   ELSE  ! NM > NPTS
     RLAT=FILL
     RLON=FILL
     XPTS=FILL
     YPTS=FILL
     RETURN
   ENDIF
   IOPF=1
 ELSE  ! IOPT /= 0
   IOPF=IOPT
   IF(IGDTNUM==1) THEN
     I_OFFSET_ODD=MOD(IGDTMPL(19)/8,2)
     I_OFFSET_EVEN=MOD(IGDTMPL(19)/4,2)
   ENDIF
 ENDIF ! IOPT CHECK
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  EQUIDISTANT CYLINDRICAL
 IF(IGDTNUM==0) THEN
   CALL GDSWZD00(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  MERCATOR CYLINDRICAL
 ELSEIF(IGDTNUM==10) THEN
   CALL GDSWZD01(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  LAMBERT CONFORMAL CONICAL
 ELSEIF(IGDTNUM==30) THEN
   CALL GDSWZD03(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  GAUSSIAN CYLINDRICAL
 ELSEIF(IGDTNUM==40) THEN
   CALL GDSWZD04(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  POLAR STEREOGRAPHIC AZIMUTHAL
 ELSEIF(IGDTNUM==20) THEN
   CALL GDSWZD05(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  2-D E-STAGGERED ROTATED EQUIDISTANT CYLINDRICAL
 ELSEIF(IGDTNUM==1.AND.(I_OFFSET_ODD/=I_OFFSET_EVEN)) THEN
   CALL GDSWZDCB(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL,  &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  2-D B-STAGGERED ROTATED EQUIDISTANT CYLINDRICAL
 ELSEIF(IGDTNUM==1) THEN
   CALL GDSWZDCD(IGDTNUM,IGDTMPL,IGDTLEN,IOPF,NPTS,FILL, &
                 XPTS,YPTS,RLON,RLAT,NRET, &
                 LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  PROJECTION UNRECOGNIZED
 ELSE
   IF(IOPT.GE.0) THEN
     RLON=FILL
     RLAT=FILL
   ENDIF
   IF(IOPT.LE.0) THEN
     XPTS=FILL
     YPTS=FILL
   ENDIF
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE GDSWZD
