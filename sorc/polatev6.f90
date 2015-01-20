 SUBROUTINE POLATEV6(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,UI,VI, &
                     NO,RLAT,RLON,CROT,SROT,IBO,LO,UO,VO,IRET)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  POLATEV6   INTERPOLATE VECTOR FIELDS (BUDGET)
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM PERFORMS BUDGET INTERPOLATION
!           FROM ANY GRID TO ANY GRID FOR VECTOR FIELDS.
!           IT REQUIRES A GRID FOR THE OUTPUT FIELDS (KGDSO(1)>=0).
!           THE ALGORITHM SIMPLY COMPUTES (WEIGHTED) AVERAGES
!           OF NEIGHBOR POINTS ARRANGED IN A SQUARE BOX
!           CENTERED AROUND EACH OUTPUT GRID POINT AND STRETCHING
!           NEARLY HALFWAY TO EACH OF THE NEIGHBORING GRID POINTS.
!           OPTIONS ALLOW CHOICES OF NUMBER OF POINTS IN EACH RADIUS
!           FROM THE CENTER POINT (IPOPT(1)) WHICH DEFAULTS TO 2
!           (IF IPOPT(1)=-1) MEANING THAT 25 POINTS WILL BE AVERAGED;
!           FURTHER OPTIONS ARE THE RESPECTIVE WEIGHTS FOR THE RADIUS
!           POINTS STARTING AT THE CENTER POINT (IPOPT(2:2+IPOPT(1))
!           WHICH DEFAULTS TO ALL 1 (IF IPOPT(1)=-1 OR IPOPT(2)=-1).
!           ANOTHER OPTION IS THE MINIMUM PERCENTAGE FOR MASK,
!           I.E. PERCENT VALID INPUT DATA REQUIRED TO MAKE OUTPUT DATA,
!           (IPOPT(3+IPOPT(1)) WHICH DEFAULTS TO 50 (IF -1).
!           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
!           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
!           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
!             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
!             (KGDS(1)=001) MERCATOR CYLINDRICAL
!             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
!             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
!             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
!             (KGDS(1)=203) ROTATED EQUIDISTANT CYLINDRICAL (E-STAGGER)
!             (KGDS(1)=205) ROTATED EQUIDISTANT CYLINDRICAL (B-STAGGER)
!           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
!           THE INPUT AND OUTPUT VECTORS ARE ROTATED SO THAT THEY ARE
!           EITHER RESOLVED RELATIVE TO THE DEFINED GRID
!           IN THE DIRECTION OF INCREASING X AND Y COORDINATES
!           OR RESOLVED RELATIVE TO EASTERLY AND NORTHERLY DIRECTIONS,
!           AS DESIGNATED BY THEIR RESPECTIVE GRID DESCRIPTION SECTIONS.
!           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
!           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED
!           ALONG WITH THEIR VECTOR ROTATION PARAMETERS.
!           INPUT BITMAPS WILL BE INTERPOLATED TO OUTPUT BITMAPS.
!           OUTPUT BITMAPS WILL ALSO BE CREATED WHEN THE OUTPUT GRID
!           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
!           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
!        
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
! 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO PIECES
! 2001-06-18  IREDELL  INCLUDE MINIMUM MASK PERCENTAGE OPTION
! 2002-01-17  IREDELL  SAVE DATA FROM LAST CALL FOR OPTIMIZATION
!
! USAGE:    CALL POLATEV6(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,UI,VI,
!    &                    NO,RLAT,RLON,CROT,SROT,IBO,LO,UO,VO,IRET)
!
!   INPUT ARGUMENT LIST:
!     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
!                IPOPT(1) IS NUMBER OF RADIUS POINTS
!                (DEFAULTS TO 2 IF IPOPT(1)=-1);
!                IPOPT(2:2+IPOPT(1)) ARE RESPECTIVE WEIGHTS
!                (DEFAULTS TO ALL 1 IF IPOPT(1)=-1 OR IPOPT(2)=-1).
!                IPOPT(3+IPOPT(1)) IS MINIMUM PERCENTAGE FOR MASK
!                (DEFAULTS TO 50 IF IPOPT(3+IPOPT(1)=-1)
!     KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
!     KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
!     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
!     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
!     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
!     IBI      - INTEGER (KM) INPUT BITMAP FLAGS
!     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
!     UI       - REAL (MI,KM) INPUT U-COMPONENT FIELDS TO INTERPOLATE
!     VI       - REAL (MI,KM) INPUT V-COMPONENT FIELDS TO INTERPOLATE
!
!   OUTPUT ARGUMENT LIST:
!     NO       - INTEGER NUMBER OF OUTPUT POINTS
!     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES
!     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES
!     CROT     - REAL (NO) VECTOR ROTATION COSINES
!     SROT     - REAL (NO) VECTOR ROTATION SINES
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
!     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
!     UO       - REAL (MO,KM) OUTPUT U-COMPONENT FIELDS INTERPOLATED
!     VO       - REAL (MO,KM) OUTPUT V-COMPONENT FIELDS INTERPOLATED
!     IRET     - INTEGER RETURN CODE
!                0    SUCCESSFUL INTERPOLATION
!                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
!                3    UNRECOGNIZED OUTPUT GRID
!                31   INVALID UNDEFINED OUTPUT GRID
!                32   INVALID BUDGET METHOD PARAMETERS
!
! SUBPROGRAMS CALLED:
!   GDSWIZ       GRID DESCRIPTION SECTION WIZARD
!   IJKGDS0      SET UP PARAMETERS FOR IJKGDS1
!   (IJKGDS1)    RETURN FIELD POSITION FOR A GIVEN GRID POINT
!   (MOVECT)     MOVE A VECTOR ALONG A GREAT CIRCLE
!   POLFIXV      MAKE MULTIPLE POLE VECTOR VALUES CONSISTENT
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
!
 USE GDSWZD_MOD
!
 IMPLICIT NONE
!
 INTEGER,         INTENT(IN   ):: IPOPT(20), IBI(KM)
 INTEGER,         INTENT(IN   ):: KM, MI, MO
 INTEGER,         INTENT(IN   ):: KGDSI(200),KGDSO(200)
 INTEGER,         INTENT(  OUT):: IRET, NO, IBO(KM)
!
 LOGICAL*1,       INTENT(IN   ):: LI(MI,KM)
 LOGICAL*1,       INTENT(  OUT):: LO(MO,KM)
!
 REAL,            INTENT(IN   ):: UI(MI,KM),VI(MI,KM)
 REAL,            INTENT(INOUT):: RLAT(MO),RLON(MO)
 REAL,            INTENT(  OUT):: UO(MO,KM),VO(MO,KM)
 REAL,            INTENT(  OUT):: CROT(MO),SROT(MO)
!
 REAL,            PARAMETER    :: FILL=-9999.
!
 INTEGER                       :: IJKGDS1, N11(MO), IJKGDSA(20)
 INTEGER                       :: IB, JB, I1, J1
 INTEGER                       :: K, LB, LSW, MP, N, NV
 INTEGER,                 SAVE :: MIX=-1,KGDSIX(200)=-1
 INTEGER                       :: NB, NB1, NB2, NB3, NB4
!
 REAL                          :: C11(MO),S11(MO)
 REAL,        ALLOCATABLE,SAVE :: CROI(:),SROI(:)
 REAL                          :: CM11, SM11, PMP
 REAL                          :: U11, V11, UROT, VROT
 REAL                          :: WB, WO(MO,KM), XI, YI
 REAL                          :: RLOB(MO),RLAB(MO)
 REAL,        ALLOCATABLE,SAVE :: RLOI(:),RLAI(:)
 REAL                          :: XPTS(MO),YPTS(MO)
 REAL,        ALLOCATABLE,SAVE :: XPTI(:),YPTI(:)
 REAL                          :: XPTB(MO),YPTB(MO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
 IRET=0
 IF(KGDSO(1).GE.0) THEN
   CALL GDSWZD(KGDSO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT,NO,CROT,SROT)
   IF(NO.EQ.0) IRET=3
 ELSE
   IRET=31
 ENDIF
 IF(ANY(KGDSI.NE.KGDSIX)) THEN
   IF(MIX.NE.MI) THEN
     IF(MIX.GE.0) DEALLOCATE(XPTI,YPTI,RLOI,RLAI,CROI,SROI)
     ALLOCATE(XPTI(MI),YPTI(MI),RLOI(MI),RLAI(MI),CROI(MI),SROI(MI))
     MIX=MI
   ENDIF
   CALL GDSWZD(KGDSI, 0,MI,FILL,XPTI,YPTI,RLOI,RLAI,NV,CROI,SROI)
   KGDSIX=KGDSI
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SET PARAMETERS
 NB1=IPOPT(1)
 IF(NB1.EQ.-1) NB1=2
 IF(IRET.EQ.0.AND.NB1.LT.0) IRET=32
 LSW=1
 IF(IPOPT(1).EQ.-1.OR.IPOPT(2).EQ.-1) LSW=0
 IF(IRET.EQ.0.AND.LSW.EQ.1.AND.NB1.GT.15) IRET=32
 MP=IPOPT(3+IPOPT(1))
 IF(MP.EQ.-1.OR.MP.EQ.0) MP=50
 IF(MP.LT.0.OR.MP.GT.100) IRET=32
 PMP=MP*0.01
 IF(IRET.EQ.0) THEN
   NB2=2*NB1+1
   NB3=NB2*NB2
   NB4=NB3
   IF(LSW.EQ.1) THEN
     NB4=IPOPT(2)
     DO IB=1,NB1
       NB4=NB4+8*IB*IPOPT(2+IB)
     ENDDO
   ENDIF
 ELSE
   NB2=0
   NB3=0
   NB4=0
 ENDIF
 DO K=1,KM
   DO N=1,NO
     UO(N,K)=0
     VO(N,K)=0
     WO(N,K)=0.
   ENDDO
 ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  LOOP OVER SAMPLE POINTS IN OUTPUT GRID BOX
 CALL IJKGDS0(KGDSI,IJKGDSA)
 DO NB=1,NB3
!  LOCATE INPUT POINTS AND COMPUTE THEIR WEIGHTS AND ROTATIONS
   JB=(NB-1)/NB2-NB1
   IB=NB-(JB+NB1)*NB2-NB1-1
   LB=MAX(ABS(IB),ABS(JB))
   WB=1
   IF(LSW.EQ.1) WB=IPOPT(2+LB)
   IF(WB.NE.0) THEN
     DO N=1,NO
       XPTB(N)=XPTS(N)+IB/REAL(NB2)
       YPTB(N)=YPTS(N)+JB/REAL(NB2)
     ENDDO
     CALL GDSWZD(KGDSO, 1,NO,FILL,XPTB,YPTB,RLOB,RLAB,NV)
     CALL GDSWZD(KGDSI,-1,NO,FILL,XPTB,YPTB,RLOB,RLAB,NV)
     IF(IRET.EQ.0.AND.NV.EQ.0.AND.LB.EQ.0) IRET=2
     DO N=1,NO
       XI=XPTB(N)
       YI=YPTB(N)
       IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
         I1=NINT(XI)
         J1=NINT(YI)
         N11(N)=IJKGDS1(I1,J1,IJKGDSA)
         IF(N11(N).GT.0) THEN
           CALL MOVECT(RLAI(N11(N)),RLOI(N11(N)),RLAT(N),RLON(N),CM11,SM11)
           C11(N)=CM11*CROI(N11(N))+SM11*SROI(N11(N))
           S11(N)=SM11*CROI(N11(N))-CM11*SROI(N11(N))
         ENDIF
       ELSE
         N11(N)=0
       ENDIF
     ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  INTERPOLATE WITH OR WITHOUT BITMAPS
     DO K=1,KM
       DO N=1,NO
         IF(N11(N).GT.0) THEN
           IF(IBI(K).EQ.0.OR.LI(N11(N),K)) THEN
             U11=C11(N)*UI(N11(N),K)-S11(N)*VI(N11(N),K)
             V11=S11(N)*UI(N11(N),K)+C11(N)*VI(N11(N),K)
             UO(N,K)=UO(N,K)+WB*U11
             VO(N,K)=VO(N,K)+WB*V11
             WO(N,K)=WO(N,K)+WB
           ENDIF
         ENDIF
       ENDDO
     ENDDO
   ENDIF
 ENDDO  ! NB LOOP
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE OUTPUT BITMAPS AND FIELDS
 DO K=1,KM
   IBO(K)=IBI(K)
   DO N=1,NO
     LO(N,K)=WO(N,K).GE.PMP*NB4
     IF(LO(N,K)) THEN
       UO(N,K)=UO(N,K)/WO(N,K)
       VO(N,K)=VO(N,K)/WO(N,K)
       UROT=CROT(N)*UO(N,K)-SROT(N)*VO(N,K)
       VROT=SROT(N)*UO(N,K)+CROT(N)*VO(N,K)
       UO(N,K)=UROT
       VO(N,K)=VROT
     ELSE
       IBO(K)=1
       UO(N,K)=0.
       VO(N,K)=0.
     ENDIF
   ENDDO
 ENDDO
 IF(KGDSO(1).EQ.0) CALL POLFIXV(NO,MO,KM,RLAT,RLON,IBO,LO,UO,VO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE POLATEV6
