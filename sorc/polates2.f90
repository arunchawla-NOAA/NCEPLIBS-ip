 SUBROUTINE POLATES2(IPOPT,GDTNUMI,GDTMPLI,GDTLENI, &
                     GDTNUMO,GDTMPLO,GDTLENO, &
                     MI,MO,KM,IBI,LI,GI,  &
                     NO,RLAT,RLON,IBO,LO,GO,IRET)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  POLATES2   INTERPOLATE SCALAR FIELDS (NEIGHBOR)
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM PERFORMS NEIGHBOR INTERPOLATION
!           FROM ANY GRID TO ANY GRID FOR SCALAR FIELDS.
!           OPTIONS ALLOW CHOOSING THE WIDTH OF THE GRID SQUARE
!           (IPOPT(1)) TO SEARCH FOR VALID DATA, WHICH DEFAULTS TO 1
!           (IF IPOPT(1)=-1).  ODD WIDTH SQUARES ARE CENTERED ON
!           THE NEAREST INPUT GRID POINT; EVEN WIDTH SQUARES ARE
!           CENTERED ON THE NEAREST FOUR INPUT GRID POINTS.
!           SQUARES ARE SEARCHED FOR VALID DATA IN A SPIRAL PATTERN
!           STARTING FROM THE CENTER.  NO SEARCHING IS DONE WHERE
!           THE OUTPUT GRID IS OUTSIDE THE INPUT GRID.
!           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
!           THE CODE RECOGNIZES THE FOLLOWING PROJECTIONS, WHERE
!           "GDTNUMI/O" IS THE GRIB 2 GRID DEFINTION TEMPLATE NUMBER
!           FOR THE INPUT AND OUTPUT GRIDS, RESPECTIVELY:
!             (GDTNUMI/O=00) EQUIDISTANT CYLINDRICAL
!             (GDTNUMI/O=01) ROTATED EQUIDISTANT CYLINDRICAL. "E" AND
!                            NON-"E" STAGGERED
!             (GDTNUMI/O=10) MERCATOR CYLINDRICAL
!             (GDTNUMI/O=20) POLAR STEREOGRAPHIC AZIMUTHAL
!             (GDTNUMI/O=30) LAMBERT CONFORMAL CONICAL
!             (GDTNUMI/O=40) GAUSSIAN CYLINDRICAL
!           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
!           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED.
!           ON THE OTHER HAND, THE OUTPUT CAN BE A SET OF STATION POINTS
!           IF GDTNUMO<0, IN WHICH CASE THE NUMBER OF POINTS
!           AND THEIR LATITUDES AND LONGITUDES MUST BE INPUT.
!           INPUT BITMAPS WILL BE INTERPOLATED TO OUTPUT BITMAPS.
!           OUTPUT BITMAPS WILL ALSO BE CREATED WHEN THE OUTPUT GRID
!           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
!           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
!        
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
! 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO PIECES
! 2001-06-18  IREDELL  INCLUDE SPIRAL SEARCH OPTION
! 2006-01-04  GAYNO    MINOR BUG FIX
! 2007-10-30  IREDELL  SAVE WEIGHTS AND THREAD FOR PERFORMANCE
! 2012-06-26  GAYNO    FIX OUT-OF-BOUNDS ERROR. SEE NCEPLIBS
!                      TICKET #9.
! 2015-07-13  GAYNO    CONVERT TO GRIB 2. REPLACE GRIB 1 KGDS ARRAYS
!                      WITH GRIB 2 GRID DEFINITION TEMPLATE ARRAYS.
!
! USAGE:    CALL POLATES2(IPOPT,GDTNUMI,GDTMPLI,GDTLENI, &
!                         GDTNUMO,GDTMPLO,GDTLENO, &
!                         MI,MO,KM,IBI,LI,GI,  &
!                         NO,RLAT,RLON,IBO,LO,GO,IRET)
!
!   INPUT ARGUMENT LIST:
!     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
!                IPOPT(1) IS WIDTH OF SQUARE TO EXAMINE IN SPIRAL SEARCH
!                (DEFAULTS TO 1 IF IPOPT(1)=-1)
!     GDTNUMI  - INTEGER GRID DEFINITION TEMPLATE NUMBER - INPUT GRID.
!                CORRESPONDS TO THE GFLD%IGDTNUM COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTMPLI  - INTEGER (GDTLENI) GRID DEFINITION TEMPLATE ARRAY -
!                INPUT GRID. CORRESPONDS TO THE GFLD%IGDTMPL COMPONENT
!                OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTLENI  - INTEGER NUMBER OF ELEMENTS OF THE GRID DEFINITION
!                TEMPLATE ARRAY - INPUT GRID.  CORRESPONDS TO THE GFLD%IGDTLEN
!                COMPONENT OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTNUMO  - INTEGER GRID DEFINITION TEMPLATE NUMBER - OUTPUT GRID.
!                CORRESPONDS TO THE GFLD%IGDTNUM COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.  GDTNUMO<0
!                MEANS INTERPOLATE TO RANDOM STATION POINTS.
!     GDTMPLO  - INTEGER (GDTLENO) GRID DEFINITION TEMPLATE ARRAY -
!                OUTPUT GRID. CORRESPONDS TO THE GFLD%IGDTMPL COMPONENT
!                OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTLENO  - INTEGER NUMBER OF ELEMENTS OF THE GRID DEFINITION
!                TEMPLATE ARRAY - OUTPUT GRID.  CORRESPONDS TO THE GFLD%IGDTLEN
!                COMPONENT OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
!     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
!     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
!     IBI      - INTEGER (KM) INPUT BITMAP FLAGS
!     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
!     GI       - REAL (MI,KM) INPUT FIELDS TO INTERPOLATE
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF GDTNUMO<0)
!     RLAT     - REAL (NO) OUTPUT LATITUDES IN DEGREES (IF GDTNUMO<0)
!     RLON     - REAL (NO) OUTPUT LONGITUDES IN DEGREES (IF GDTNUMO<0)
!
!   OUTPUT ARGUMENT LIST:
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF GDTNUMO>=0)
!     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES (IF GDTNUMO>=0)
!     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES (IF GDTNUMO>=0)
!     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
!     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
!     GO       - REAL (MO,KM) OUTPUT FIELDS INTERPOLATED
!     IRET     - INTEGER RETURN CODE
!                0    SUCCESSFUL INTERPOLATION
!                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
!                3    UNRECOGNIZED OUTPUT GRID
!
! SUBPROGRAMS CALLED:
!   GDSWZD       GRID DESCRIPTION SECTION WIZARD
!   IJKGDS0      SET UP PARAMETERS FOR IJKGDS1
!   IJKGDS1      RETURN FIELD POSITION FOR A GIVEN GRID POINT
!   POLFIXS      MAKE MULTIPLE POLE SCALAR VALUES CONSISTENT
!   CHECK_GRIDS2 DETERMINE IF INPUT OR OUTPUT GRIDS HAVE CHANGED
!                BETWEEN CALLS TO THIS ROUTINE.
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,        INTENT(IN   )        :: GDTNUMI, GDTLENI
 INTEGER(KIND=4),INTENT(IN   )        :: GDTMPLI(GDTLENI)
 INTEGER,        INTENT(IN   )        :: GDTNUMO, GDTLENO
 INTEGER(KIND=4),INTENT(IN   )        :: GDTMPLO(GDTLENO)
 INTEGER,               INTENT(IN   ) :: IPOPT(20)
 INTEGER,               INTENT(IN   ) :: MI,MO,KM
 INTEGER,               INTENT(IN   ) :: IBI(KM)
 INTEGER,               INTENT(INOUT) :: NO
 INTEGER,               INTENT(  OUT) :: IRET, IBO(KM)
!
 LOGICAL*1,             INTENT(IN   ) :: LI(MI,KM)
 LOGICAL*1,             INTENT(  OUT) :: LO(MO,KM)
!
 REAL,                  INTENT(IN   ) :: GI(MI,KM)
 REAL,                  INTENT(INOUT) :: RLAT(MO),RLON(MO)
 REAL,                  INTENT(  OUT) :: GO(MO,KM)
!
 REAL,                  PARAMETER     :: FILL=-9999.
!
 INTEGER                              :: IJKGDSA(20)
 INTEGER                              :: I1,J1,IXS,JXS
 INTEGER                              :: MSPIRAL,N,K,NK
 INTEGER                              :: NV,IJKGDS1
 INTEGER                              :: MX,KXS,KXT,IX,JX,NX
 INTEGER,                       SAVE  :: NOX=-1,IRETX=-1
 INTEGER,           ALLOCATABLE,SAVE  :: NXY(:)
!
 LOGICAL                              :: SAME_GRIDI, SAME_GRIDO
!
 REAL,              ALLOCATABLE       :: DUM1(:),DUM2(:),DUM3(:),DUM4(:)
 REAL,              ALLOCATABLE       :: DUM5(:),DUM6(:),DUM7(:)
 REAL,              ALLOCATABLE,SAVE  :: RLATX(:),RLONX(:)
 REAL,              ALLOCATABLE,SAVE  :: XPTSX(:),YPTSX(:)
 REAL                                 :: XPTS(MO),YPTS(MO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SET PARAMETERS
 IRET=0
 MSPIRAL=MAX(IPOPT(1),1)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 CALL CHECK_GRIDS2(GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO,GDTLENO, &
                   SAME_GRIDI,SAME_GRIDO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SAVE OR SKIP WEIGHT COMPUTATION
 IF(IRET.EQ.0.AND.(GDTNUMO.LT.0.OR..NOT.SAME_GRIDI.OR..NOT.SAME_GRIDO))THEN
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
   IF(GDTNUMO.GE.0) THEN
     ALLOCATE(DUM1(MO))
     ALLOCATE(DUM2(MO))
     ALLOCATE(DUM3(MO))
     ALLOCATE(DUM4(MO))
     ALLOCATE(DUM5(MO))
     ALLOCATE(DUM6(MO))
     ALLOCATE(DUM7(MO))
     CALL GDSWZD(GDTNUMO,GDTMPLO,GDTLENO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT, &
                 NO,0,DUM1,DUM2,0,DUM3,DUM4,DUM5,DUM6,DUM7)
     DEALLOCATE(DUM1,DUM2,DUM3,DUM4,DUM5,DUM6,DUM7)
     IF(NO.EQ.0) IRET=3
   ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  LOCATE INPUT POINTS
   ALLOCATE(DUM1(NO))
   ALLOCATE(DUM2(NO))
   ALLOCATE(DUM3(NO))
   ALLOCATE(DUM4(NO))
   ALLOCATE(DUM5(NO))
   ALLOCATE(DUM6(NO))
   ALLOCATE(DUM7(NO))
   CALL GDSWZD(GDTNUMI,GDTMPLI,GDTLENI,-1,NO,FILL,XPTS,YPTS,RLON,RLAT, &
               NV,0,DUM1,DUM2,0,DUM3,DUM4,DUM5,DUM6,DUM7)
   DEALLOCATE(DUM1,DUM2,DUM3,DUM4,DUM5,DUM6,DUM7)
   IF(IRET.EQ.0.AND.NV.EQ.0) IRET=2
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  ALLOCATE AND SAVE GRID DATA
   IF(NOX.NE.NO) THEN
     IF(NOX.GE.0) DEALLOCATE(RLATX,RLONX,XPTSX,YPTSX,NXY)
     ALLOCATE(RLATX(NO),RLONX(NO),XPTSX(NO),YPTSX(NO),NXY(NO))
     NOX=NO
   ENDIF
   IRETX=IRET
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE WEIGHTS
   IF(IRET.EQ.0) THEN
     CALL IJKGDS0(GDTNUMI,GDTMPLI,GDTLENI,IJKGDSA)
!$OMP PARALLEL DO PRIVATE(N)
     DO N=1,NO
       RLONX(N)=RLON(N)
       RLATX(N)=RLAT(N)
       XPTSX(N)=XPTS(N)
       YPTSX(N)=YPTS(N)
       IF(XPTS(N).NE.FILL.AND.YPTS(N).NE.FILL) THEN
         NXY(N)=IJKGDS1(NINT(XPTS(N)),NINT(YPTS(N)),IJKGDSA)
       ELSE
         NXY(N)=0
       ENDIF
     ENDDO
   ENDIF
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  INTERPOLATE OVER ALL FIELDS
 IF(IRET.EQ.0.AND.IRETX.EQ.0) THEN
   IF(GDTNUMO.GE.0) THEN
     NO=NOX
     DO N=1,NO
       RLON(N)=RLONX(N)
       RLAT(N)=RLATX(N)
     ENDDO
   ENDIF
   DO N=1,NO
     XPTS(N)=XPTSX(N)
     YPTS(N)=YPTSX(N)
   ENDDO
!$OMP PARALLEL DO PRIVATE(NK,K,N,I1,J1,IXS,JXS,MX,KXS,KXT,IX,JX,NX)
   DO NK=1,NO*KM
     K=(NK-1)/NO+1
     N=NK-NO*(K-1)
     GO(N,K)=0
     LO(N,K)=.FALSE.
     IF(NXY(N).GT.0) THEN
       IF(IBI(K).EQ.0.OR.LI(NXY(N),K)) THEN
         GO(N,K)=GI(NXY(N),K)
         LO(N,K)=.TRUE.
! SPIRAL AROUND UNTIL VALID DATA IS FOUND.
       ELSEIF(MSPIRAL.GT.1) THEN
         I1=NINT(XPTS(N))
         J1=NINT(YPTS(N))
         IXS=SIGN(1.,XPTS(N)-I1)
         JXS=SIGN(1.,YPTS(N)-J1)
         DO MX=2,MSPIRAL**2
           KXS=SQRT(4*MX-2.5)
           KXT=MX-(KXS**2/4+1)
           SELECT CASE(MOD(KXS,4))
           CASE(1)
             IX=I1-IXS*(KXS/4-KXT)
             JX=J1-JXS*KXS/4
           CASE(2)
             IX=I1+IXS*(1+KXS/4)
             JX=J1-JXS*(KXS/4-KXT)
           CASE(3)
             IX=I1+IXS*(1+KXS/4-KXT)
             JX=J1+JXS*(1+KXS/4)
           CASE DEFAULT
             IX=I1-IXS*KXS/4
             JX=J1+JXS*(KXS/4-KXT)
           END SELECT
           NX=IJKGDS1(IX,JX,IJKGDSA)
           IF(NX.GT.0) THEN
             IF(LI(NX,K)) THEN
               GO(N,K)=GI(NX,K)
               LO(N,K)=.TRUE.
               EXIT
             ENDIF
           ENDIF
         ENDDO
       ENDIF
     ENDIF
   ENDDO
   DO K=1,KM
     IBO(K)=IBI(K)
     IF(.NOT.ALL(LO(1:NO,K))) IBO(K)=1
   ENDDO
   IF(GDTNUMO.EQ.0) CALL POLFIXS(NO,MO,KM,RLAT,RLON,IBO,LO,GO)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 ELSE
   IF(IRET.EQ.0) IRET=IRETX
   IF(GDTNUMO.GE.0) NO=0
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE POLATES2
!
 SUBROUTINE CHECK_GRIDS2(GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO,GDTLENO, &
                        SAME_GRIDI, SAME_GRIDO)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  CHECK_GRIDS2   CHECK GRID INFORMATION
!   PRGMMR: GAYNO       ORG: W/NMC23       DATE: 2015-07-13
!
! ABSTRACT: DETERMINE WHETHER THE INPUT OR OUTPUT GRID SPECS
!           HAVE CHANGED.
!
! PROGRAM HISTORY LOG:
! 2015-07-13  GAYNO     INITIAL VERSION
!
! USAGE:  CALL CHECK_GRIDS2(GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO, &
!                           GDTLENO, SAME_GRIDI, SAME_GRIDO)
!
!   INPUT ARGUMENT LIST:
!     GDTNUMI  - INTEGER GRID DEFINITION TEMPLATE NUMBER - INPUT GRID.
!                CORRESPONDS TO THE GFLD%IGDTNUM COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTMPLI  - INTEGER (GDTLENI) GRID DEFINITION TEMPLATE ARRAY -
!                INPUT GRID. CORRESPONDS TO THE GFLD%IGDTMPL COMPONENT
!                OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTLENI  - INTEGER NUMBER OF ELEMENTS OF THE GRID DEFINITION
!                TEMPLATE ARRAY - INPUT GRID.  CORRESPONDS TO THE GFLD%IGDTLEN
!                COMPONENT OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTNUMO  - INTEGER GRID DEFINITION TEMPLATE NUMBER - OUTPUT GRID.
!                CORRESPONDS TO THE GFLD%IGDTNUM COMPONENT OF THE
!                NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTMPLO  - INTEGER (GDTLENO) GRID DEFINITION TEMPLATE ARRAY -
!                OUTPUT GRID. CORRESPONDS TO THE GFLD%IGDTMPL COMPONENT
!                OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!     GDTLENO  - INTEGER NUMBER OF ELEMENTS OF THE GRID DEFINITION
!                TEMPLATE ARRAY - OUTPUT GRID.  CORRESPONDS TO THE GFLD%IGDTLEN
!                COMPONENT OF THE NCEP G2 LIBRARY GRIDMOD DATA STRUCTURE.
!
!   OUTPUT ARGUMENT LIST:
!     SAME_GRIDI  - WHEN TRUE, THE INPUT GRID HAS NOT CHANGED BETWEEN CALLS.
!     SAME_GRIDO  - WHEN TRUE, THE OUTPUT GRID HAS NOT CHANGED BETWEEN CALLS.
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,        INTENT(IN   ) :: GDTNUMI, GDTLENI
 INTEGER(KIND=4),INTENT(IN   ) :: GDTMPLI(GDTLENI)
 INTEGER,        INTENT(IN   ) :: GDTNUMO, GDTLENO
 INTEGER(KIND=4),INTENT(IN   ) :: GDTMPLO(GDTLENO)
!
 LOGICAL,        INTENT(  OUT) :: SAME_GRIDI, SAME_GRIDO
!
 INTEGER, SAVE                 :: GDTNUMI_SAVE=-9999
 INTEGER, SAVE                 :: GDTLENI_SAVE=-9999
 INTEGER, SAVE                 :: GDTMPLI_SAVE(1000)=-9999
 INTEGER, SAVE                 :: GDTNUMO_SAVE=-9999
 INTEGER, SAVE                 :: GDTLENO_SAVE=-9999
 INTEGER, SAVE                 :: GDTMPLO_SAVE(1000)=-9999
!
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 SAME_GRIDI=.FALSE.
 IF(GDTNUMI==GDTNUMI_SAVE)THEN
   IF(GDTLENI==GDTLENI_SAVE)THEN
     IF(ALL(GDTMPLI==GDTMPLI_SAVE(1:GDTLENI)))THEN
       SAME_GRIDI=.TRUE.
     ENDIF
   ENDIF
 ENDIF
!
 GDTNUMI_SAVE=GDTNUMI
 GDTLENI_SAVE=GDTLENI
 GDTMPLI_SAVE(1:GDTLENI)=GDTMPLI
 GDTMPLI_SAVE(GDTLENI+1:1000)=-9999
!
 SAME_GRIDO=.FALSE.
 IF(GDTNUMO==GDTNUMO_SAVE)THEN
   IF(GDTLENO==GDTLENO_SAVE)THEN
     IF(ALL(GDTMPLO==GDTMPLO_SAVE(1:GDTLENO)))THEN
       SAME_GRIDO=.TRUE.
     ENDIF
   ENDIF
 ENDIF
!
 GDTNUMO_SAVE=GDTNUMO
 GDTLENO_SAVE=GDTLENO
 GDTMPLO_SAVE(1:GDTLENO)=GDTMPLO
 GDTMPLO_SAVE(GDTLENO+1:1000)=-9999
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE CHECK_GRIDS2
