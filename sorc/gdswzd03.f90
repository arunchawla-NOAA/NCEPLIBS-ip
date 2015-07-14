 SUBROUTINE GDSWZD03(IGDTNUM,IGDTMPL,IGDTLEN,IOPT,NPTS,FILL, &
                     XPTS,YPTS,RLON,RLAT,NRET, &
                     LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD03   GDS WIZARD FOR LAMBERT CONFORMAL CONICAL
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM DECODES THE GRIB 2 GRID DEFINITION
!           TEMPLATE (PASSED IN INTEGER FROM AS DECODED BY THE
!           NCEP G2 LIBRARY) AND RETURNS ONE OF THE FOLLOWING:
!             (IOPT=+1) EARTH COORDINATES OF SELECTED GRID COORDINATES
!             (IOPT=-1) GRID COORDINATES OF SELECTED EARTH COORDINATES
!           FOR LAMBERT CONFORMAL CONICAL PROJECTIONS.
!           IF THE SELECTED COORDINATES ARE MORE THAN ONE GRIDPOINT
!           BEYOND THE THE EDGES OF THE GRID DOMAIN, THEN THE RELEVANT
!           OUTPUT ELEMENTS ARE SET TO FILL VALUES.
!           THE ACTUAL NUMBER OF VALID POINTS COMPUTED IS RETURNED TOO.
!           OPTIONALLY, THE VECTOR ROTATIONS AND THE MAP JACOBIANS
!           FOR THIS GRID MAY BE RETURNED AS WELL.
!
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
!   96-10-01  IREDELL   PROTECTED AGAINST UNRESOLVABLE POINTS
!   97-10-20  IREDELL   INCLUDE MAP OPTIONS
! 1999-04-27  GILBERT   CORRECTED MINOR ERROR CALCULATING VARIABLE AN
!                       FOR THE SECANT PROJECTION CASE (RLATI1.NE.RLATI2).
! 2012-08-14  GAYNO     FIX PROBLEM WITH SH GRIDS.  ENSURE GRID BOX
!                       AREA ALWAYS POSITIVE.
! 2015-07-13  GAYNO     CONVERT TO GRIB 2. REPLACE GRIB 1 KGDS ARRAY
!                       WITH GRIB 2 GRID DEFINITION TEMPLATE ARRAY.
!
! USAGE:   CALL GDSWZD03(IGDTNUM,IGDTMPL,IGDTLEN,IOPT,NPTS,FILL, &
!                    XPTS,YPTS,RLON,RLAT,NRET, &
!                    LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
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
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT<0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT<0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT>0
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT>0
!     NRET     - INTEGER NUMBER OF VALID POINTS COMPUTED
!     CROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION COSINES IF LROT=1
!     SROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION SINES IF LROT=1
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!     XLON     - REAL (NPTS) DX/DLON IN 1/DEGREES IF LMAP=1
!     XLAT     - REAL (NPTS) DX/DLAT IN 1/DEGREES IF LMAP=1
!     YLON     - REAL (NPTS) DY/DLON IN 1/DEGREES IF LMAP=1
!     YLAT     - REAL (NPTS) DY/DLAT IN 1/DEGREES IF LMAP=1
!     AREA     - REAL (NPTS) AREA WEIGHTS IN M**2 IF LMAP=1
!                (PROPORTIONAL TO THE SQUARE OF THE MAP FACTOR)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,        INTENT(IN   ) :: IGDTNUM, IGDTLEN
 INTEGER(KIND=4),INTENT(IN   ) :: IGDTMPL(IGDTLEN)
 INTEGER,        INTENT(IN   ) :: IOPT
 INTEGER,        INTENT(IN   ) :: LMAP, LROT, NPTS
 INTEGER,        INTENT(  OUT) :: NRET
!
 REAL,           INTENT(IN   ) :: FILL
 REAL,           INTENT(INOUT) :: RLON(NPTS),RLAT(NPTS)
 REAL,           INTENT(INOUT) :: XPTS(NPTS),YPTS(NPTS)
 REAL,           INTENT(  OUT) :: CROT(NPTS),SROT(NPTS)
 REAL,           INTENT(  OUT) :: XLON(NPTS),XLAT(NPTS)
 REAL,           INTENT(  OUT) :: YLON(NPTS),YLAT(NPTS),AREA(NPTS)
!
 REAL,           PARAMETER     :: PI=3.14159265358979
 REAL,           PARAMETER     :: DPR=180./PI
!
 INTEGER                       :: IM, JM, IPROJ, N
 INTEGER                       :: IROT, ISCAN, JSCAN
!
 REAL                          :: AN, ANTR, CLAT, DI, DJ
 REAL                          :: DX, DY, DXS, DYS, DLON, DLON1
 REAL                          :: DE, DE2, DR, DR2
 REAL                          :: H, HI, HJ, RERTH, ECCEN_SQUARED
 REAL                          :: ORIENT, RLAT1, RLON1
 REAL                          :: RLATI1, RLATI2
 REAL                          :: XMAX, XMIN, YMAX, YMIN, XP, YP
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! IS THIS A LAMBERT CONFORMAL GRID?
 IF(IGDTNUM/=30)THEN
   CALL GDSWZD03_ERROR(IOPT,FILL,RLAT,RLON,XPTS,YPTS,NPTS)
   RETURN
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 CALL EARTH_RADIUS(IGDTMPL,IGDTLEN,RERTH,ECCEN_SQUARED)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
! ROUTINE ONLY WORKS FOR SPHERICAL EARTHS.
 IF(RERTH<0..OR.ECCEN_SQUARED/=0.0) THEN
   CALL GDSWZD03_ERROR(IOPT,FILL,RLAT,RLON,XPTS,YPTS,NPTS)
   RETURN
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 IM=IGDTMPL(8)
 JM=IGDTMPL(9)
 RLAT1=FLOAT(IGDTMPL(10))*1.0E-6
 RLON1=FLOAT(IGDTMPL(11))*1.0E-6
 IROT=MOD(IGDTMPL(12)/8,2)
 ORIENT=FLOAT(IGDTMPL(14))*1.0E-6
 DX=FLOAT(IGDTMPL(15))*1.0E-3
 DY=FLOAT(IGDTMPL(16))*1.0E-3
 IPROJ=MOD(IGDTMPL(17)/128,2)
 ISCAN=MOD(IGDTMPL(18)/128,2)
 JSCAN=MOD(IGDTMPL(18)/64,2)
 RLATI1=FLOAT(IGDTMPL(19))*1.0E-6
 RLATI2=FLOAT(IGDTMPL(20))*1.0E-6
 H=(-1.)**IPROJ
 HI=(-1.)**ISCAN
 HJ=(-1.)**(1-JSCAN)
 DXS=DX*HI
 DYS=DY*HJ
 IF(RLATI1.EQ.RLATI2) THEN
   AN=SIN(RLATI1/DPR)
 ELSE
   AN=LOG(COS(RLATI1/DPR)/COS(RLATI2/DPR))/ &
      LOG(TAN((90-RLATI1)/2/DPR)/TAN((90-RLATI2)/2/DPR))
 ENDIF
 DE=RERTH*COS(RLATI1/DPR)*TAN((RLATI1+90)/2/DPR)**AN/AN
 IF(H*RLAT1.EQ.90) THEN
   XP=1
   YP=1
 ELSE
   DR=DE/TAN((RLAT1+90)/2/DPR)**AN
   DLON1=MOD(RLON1-ORIENT+180+3600,360.)-180
   XP=1-SIN(AN*DLON1/DPR)*DR/DXS
   YP=1+COS(AN*DLON1/DPR)*DR/DYS
 ENDIF
 ANTR=1/(2*AN)
 DE2=DE**2
 XMIN=0
 XMAX=IM+1
 YMIN=0
 YMAX=JM+1
 NRET=0
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE GRID COORDINATES TO EARTH COORDINATES
 IF(IOPT.EQ.0.OR.IOPT.EQ.1) THEN
   DO N=1,NPTS
     IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
        YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
       DI=H*(XPTS(N)-XP)*DXS
       DJ=H*(YPTS(N)-YP)*DYS
       DR2=DI**2+DJ**2
       IF(DR2.LT.DE2*1.E-6) THEN
         RLON(N)=0.
         RLAT(N)=H*90.
       ELSE
         RLON(N)=MOD(ORIENT+1./AN*DPR*ATAN2(DI,-DJ)+3600,360.)
         RLAT(N)=(2*DPR*ATAN((DE2/DR2)**ANTR)-90)
       ENDIF
       NRET=NRET+1
       IF(LROT.EQ.1) THEN
         IF(IROT.EQ.1) THEN
           DLON=MOD(RLON(N)-ORIENT+180+3600,360.)-180
           CROT(N)=COS(AN*DLON/DPR)
           SROT(N)=SIN(AN*DLON/DPR)
         ELSE
           CROT(N)=1
           SROT(N)=0
         ENDIF
       ENDIF
       IF(LMAP.EQ.1) THEN
         DR=SQRT(DR2)
         DLON=MOD(RLON(N)-ORIENT+180+3600,360.)-180
         CLAT=COS(RLAT(N)/DPR)
         IF(CLAT.LE.0.OR.DR.LE.0) THEN
           XLON(N)=FILL
           XLAT(N)=FILL
           YLON(N)=FILL
           YLAT(N)=FILL
           AREA(N)=FILL
         ELSE
           XLON(N)=H*COS(AN*DLON/DPR)*AN/DPR*DR/DXS
           XLAT(N)=-H*SIN(AN*DLON/DPR)*AN/DPR*DR/DXS/CLAT
           YLON(N)=H*SIN(AN*DLON/DPR)*AN/DPR*DR/DYS
           YLAT(N)=H*COS(AN*DLON/DPR)*AN/DPR*DR/DYS/CLAT
           AREA(N)=RERTH**2*CLAT**2*ABS(DXS)*ABS(DYS)/(AN*DR)**2
         ENDIF
       ENDIF
     ELSE
       RLON(N)=FILL
       RLAT(N)=FILL
     ENDIF
   ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE EARTH COORDINATES TO GRID COORDINATES
 ELSEIF(IOPT.EQ.-1) THEN
   DO N=1,NPTS
     IF(ABS(RLON(N)).LE.360.AND.ABS(RLAT(N)).LE.90.AND. &
                                    H*RLAT(N).NE.-90) THEN
       DR=H*DE*TAN((90-RLAT(N))/2/DPR)**AN
       DLON=MOD(RLON(N)-ORIENT+180+3600,360.)-180
       XPTS(N)=XP+H*SIN(AN*DLON/DPR)*DR/DXS
       YPTS(N)=YP-H*COS(AN*DLON/DPR)*DR/DYS
       IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
          YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
         NRET=NRET+1
         IF(LROT.EQ.1) THEN
           IF(IROT.EQ.1) THEN
             CROT(N)=COS(AN*DLON/DPR)
             SROT(N)=SIN(AN*DLON/DPR)
           ELSE
             CROT(N)=1
             SROT(N)=0
           ENDIF
         ENDIF
         IF(LMAP.EQ.1) THEN
           CLAT=COS(RLAT(N)/DPR)
           IF(CLAT.LE.0.OR.DR.LE.0) THEN
             XLON(N)=FILL
             XLAT(N)=FILL
             YLON(N)=FILL
             YLAT(N)=FILL
             AREA(N)=FILL
           ELSE
             XLON(N)=H*COS(AN*DLON/DPR)*AN/DPR*DR/DXS
             XLAT(N)=-H*SIN(AN*DLON/DPR)*AN/DPR*DR/DXS/CLAT
             YLON(N)=H*SIN(AN*DLON/DPR)*AN/DPR*DR/DYS
             YLAT(N)=H*COS(AN*DLON/DPR)*AN/DPR*DR/DYS/CLAT
             AREA(N)=RERTH**2*CLAT**2*ABS(DXS)*ABS(DYS)/(AN*DR)**2
           ENDIF
         ENDIF
       ELSE
         XPTS(N)=FILL
         YPTS(N)=FILL
       ENDIF
     ELSE
       XPTS(N)=FILL
       YPTS(N)=FILL
     ENDIF
   ENDDO
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE GDSWZD03
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 SUBROUTINE GDSWZD03_ERROR(IOPT,FILL,RLAT,RLON,XPTS,YPTS,NPTS)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD03_ERROR   GDSWZD03 ERROR HANDLER
!   PRGMMR: GAYNO       ORG: W/NMC23       DATE: 2015-07-13
!
! ABSTRACT: UPON AN ERROR, THIS SUBPROGRAM ASSIGNS
!           A "FILL" VALUE TO THE OUTPUT FIELDS.

! PROGRAM HISTORY LOG:
! 2015-07-13  GAYNO     INITIAL VERSION
!
! USAGE:    CALL GDSWZD03_ERROR(IOPT,FILL,RLAT,RLON,XPTS,YPTS,NPTS)
!
!   INPUT ARGUMENT LIST:
!     IOPT     - INTEGER OPTION FLAG
!                (+1 TO COMPUTE EARTH COORDS OF SELECTED GRID COORDS)
!                (-1 TO COMPUTE GRID COORDS OF SELECTED EARTH COORDS)
!     NPTS     - INTEGER MAXIMUM NUMBER OF COORDINATES
!     FILL     - REAL FILL VALUE TO SET INVALID OUTPUT DATA
!                (MUST BE IMPOSSIBLE VALUE; SUGGESTED VALUE: -9999.)
!   OUTPUT ARGUMENT LIST:
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT<0
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT<0
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT>0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT>0
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER, INTENT(IN   ) :: IOPT, NPTS
!
 REAL,    INTENT(IN   ) :: FILL
 REAL,    INTENT(  OUT) :: RLAT(NPTS),RLON(NPTS)
 REAL,    INTENT(  OUT) :: XPTS(NPTS),YPTS(NPTS)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 IF(IOPT>=0) THEN
   RLON=FILL
   RLAT=FILL
 ENDIF
 IF(IOPT<=0) THEN
   XPTS=FILL
   YPTS=FILL
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE GDSWZD03_ERROR
