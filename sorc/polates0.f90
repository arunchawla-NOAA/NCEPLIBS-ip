 SUBROUTINE POLATES0(IPOPT,GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO,GDTLENO, &
                     MI,MO,KM,IBI,LI,GI, &
                     NO,RLAT,RLON,IBO,LO,GO,IRET)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  POLATES0   INTERPOLATE SCALAR FIELDS (BILINEAR)
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM PERFORMS BILINEAR INTERPOLATION
!           FROM ANY GRID TO ANY GRID FOR SCALAR FIELDS.
!           OPTIONS ALLOW VARYING THE MINIMUM PERCENTAGE FOR MASK,
!           I.E. PERCENT VALID INPUT DATA REQUIRED TO MAKE OUTPUT DATA,
!           (IPOPT(1)) WHICH DEFAULTS TO 50 (IF IPOPT(1)=-1).
!           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
!           IF NO INPUT DATA IS FOUND NEAR THE OUTPUT POINT, A SPIRAL
!           SEARCH MAY BE INVOKED BY SETTING IPOPT(2)> 0.
!           NO SEARCHING IS DONE IF OUTPUT POINT IS OUTSIDE THE INPUT GRID.
!           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
!           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
!             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
!             (KGDS(1)=001) MERCATOR CYLINDRICAL
!             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
!             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
!             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
!             (KGDS(1)=202) ROTATED EQUIDISTANT CYLINDRICAL (ETA NATIVE)
!           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
!           AS AN ADDED BONUS THE NUMBER OF OUTPUT GRID POINTS
!           AND THEIR LATITUDES AND LONGITUDES ARE ALSO RETURNED.
!           ON THE OTHER HAND, THE OUTPUT CAN BE A SET OF STATION POINTS
!           IF KGDSO(1)<0, IN WHICH CASE THE NUMBER OF POINTS
!           AND THEIR LATITUDES AND LONGITUDES MUST BE INPUT.
!           INPUT BITMAPS WILL BE INTERPOLATED TO OUTPUT BITMAPS.
!           OUTPUT BITMAPS WILL ALSO BE CREATED WHEN THE OUTPUT GRID
!           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
!           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
!        
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
! 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO PIECES
! 2001-06-18  IREDELL  INCLUDE MINIMUM MASK PERCENTAGE OPTION
! 2007-05-22  IREDELL  EXTRAPOLATE UP TO HALF A GRID CELL
! 2008-06-04  GAYNO    ADDED SPIRAL SEARCH OPTION
! 2009-10-19  IREDELL  SAVE WEIGHTS AND THREAD FOR PERFORMANCE
! 2012-06-26  GAYNO    FIX OUT-OF-BOUNDS ERROR.  SEE NCEPLIBS
!                      TICKET #9.
!
! USAGE:    CALL POLATES0(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
!    &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
!
!   INPUT ARGUMENT LIST:
!     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
!                IPOPT(1) IS MINIMUM PERCENTAGE FOR MASK
!                (DEFAULTS TO 50 IF IPOPT(1)=-1)
!                IPOPT(2) IS WIDTH OF SQUARE TO EXAMINE IN SPIRAL SEARCH
!                (DEFAULTS TO NO SEARCH IF IPOPT(2)=-1)
!     KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
!     KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
!                (KGDSO(1)<0 IMPLIES RANDOM STATION POINTS)
!     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
!     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
!                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
!     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
!     IBI      - INTEGER (KM) INPUT BITMAP FLAGS
!     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
!     GI       - REAL (MI,KM) INPUT FIELDS TO INTERPOLATE
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)<0)
!     RLAT     - REAL (NO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)<0)
!     RLON     - REAL (NO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)<0)
!
!   OUTPUT ARGUMENT LIST:
!     NO       - INTEGER NUMBER OF OUTPUT POINTS (ONLY IF KGDSO(1)>=0)
!     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES (IF KGDSO(1)>=0)
!     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES (IF KGDSO(1)>=0)
!     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
!     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
!     GO       - REAL (MO,KM) OUTPUT FIELDS INTERPOLATED
!     IRET     - INTEGER RETURN CODE
!                0    SUCCESSFUL INTERPOLATION
!                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
!                3    UNRECOGNIZED OUTPUT GRID
!
! SUBPROGRAMS CALLED:
!   GDSWIZ       GRID DESCRIPTION SECTION WIZARD
!   IJKGDS0      SET UP PARAMETERS FOR IJKGDS1
!   (IJKGDS1)    RETURN FIELD POSITION FOR A GIVEN GRID POINT
!   POLFIXS      MAKE MULTIPLE POLE SCALAR VALUES CONSISTENT
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
 INTEGER,               INTENT(IN   ):: IPOPT(20)
 INTEGER,               INTENT(IN   ):: MI,MO,KM
 INTEGER,               INTENT(IN   ):: IBI(KM)
 INTEGER,               INTENT(INOUT):: NO
 INTEGER,               INTENT(  OUT):: IRET, IBO(KM)
!
 LOGICAL*1,             INTENT(IN   ):: LI(MI,KM)
 LOGICAL*1,             INTENT(  OUT):: LO(MO,KM)
!
 REAL,                  INTENT(IN   ):: GI(MI,KM)
 REAL,                  INTENT(INOUT):: RLAT(MO),RLON(MO)
 REAL,                  INTENT(  OUT):: GO(MO,KM)
!
 REAL,                  PARAMETER    :: FILL=-9999.
!
 INTEGER                             :: IJKGDSA(20)
 INTEGER                             :: IJX(2),IJY(2)
 INTEGER                             :: MP,N,I,J,K
 INTEGER                             :: NK,NV,IJKGDS1
 INTEGER                             :: MSPIRAL,I1,J1,IXS,JXS
 INTEGER                             :: MX,KXS,KXT,IX,JX,NX
 INTEGER,ALLOCATABLE,SAVE            :: NXY(:,:,:)
 INTEGER,SAVE                        :: NOX=-1,IRETX=-1
!
 LOGICAL                             :: SAME_GRIDI, SAME_GRIDO
!
 REAL,ALLOCATABLE                    :: CROT(:),SROT(:)
 REAL,ALLOCATABLE                    :: XLON(:),XLAT(:),YLON(:),YLAT(:),AREA(:)
 REAL                                :: WX(2),WY(2)
 REAL                                :: XPTS(MO),YPTS(MO)
 REAL                                :: PMP,XIJ,YIJ,XF,YF,G,W
 REAL,ALLOCATABLE,SAVE               :: RLATX(:),RLONX(:),WXY(:,:,:)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SET PARAMETERS
 IRET=0
 MP=IPOPT(1)
 IF(MP.EQ.-1.OR.MP.EQ.0) MP=50
 IF(MP.LT.0.OR.MP.GT.100) IRET=32
 PMP=MP*0.01
 MSPIRAL=MAX(IPOPT(2),0)
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 CALL CHECK_GRIDS0(GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO,GDTLENO, &
                   SAME_GRIDI,SAME_GRIDO) 
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  SAVE OR SKIP WEIGHT COMPUTATION
 IF(IRET==0.AND.(GDTNUMO<0.OR..NOT.SAME_GRIDI.OR..NOT.SAME_GRIDO))THEN
   print*,'compute weights'
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
   IF(GDTNUMO.GE.0) THEN
     ALLOCATE (CROT(MO))
     ALLOCATE (SROT(MO))
     ALLOCATE (XLON(MO))
     ALLOCATE (XLAT(MO))
     ALLOCATE (YLON(MO))
     ALLOCATE (YLAT(MO))
     ALLOCATE (AREA(MO))
     CALL GDSWZD(GDTNUMO,GDTMPLO,GDTLENO, 0,MO,FILL,XPTS,YPTS, &
                 RLON,RLAT,NO,0,CROT,SROT,0,XLON,XLAT,YLON,YLAT,AREA)
     DEALLOCATE (CROT,SROT,XLON,XLAT,YLON,YLAT,AREA)
     IF(NO.EQ.0) IRET=3
   ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  LOCATE INPUT POINTS
   ALLOCATE (CROT(NO))
   ALLOCATE (SROT(NO))
   ALLOCATE (XLON(MO))
   ALLOCATE (XLAT(MO))
   ALLOCATE (YLON(MO))
   ALLOCATE (YLAT(MO))
   ALLOCATE (AREA(MO))
   CALL GDSWZD(GDTNUMI,GDTMPLI,GDTLENI,-1,NO,FILL,XPTS,YPTS,RLON,RLAT,NV, &
               0,CROT,SROT,0,XLON,XLAT,YLON,YLAT,AREA)
   DEALLOCATE (CROT,SROT,XLON,XLAT,YLON,YLAT,AREA)
   IF(IRET.EQ.0.AND.NV.EQ.0) IRET=2
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  ALLOCATE AND SAVE GRID DATA
   IF(NOX.NE.NO) THEN
     IF(NOX.GE.0) DEALLOCATE(RLATX,RLONX,NXY,WXY)
     ALLOCATE(RLATX(NO),RLONX(NO),NXY(2,2,NO),WXY(2,2,NO))
     NOX=NO
   ENDIF
   IRETX=IRET
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  COMPUTE WEIGHTS
   IF(IRET.EQ.0) THEN
     CALL IJKGDS0(GDTNUMI,GDTMPLI,GDTLENI,IJKGDSA)
!$OMP PARALLEL DO PRIVATE(N,XIJ,YIJ,IJX,IJY,XF,YF,J,I,WX,WY)
     DO N=1,NO
       RLONX(N)=RLON(N)
       RLATX(N)=RLAT(N)
       XIJ=XPTS(N)
       YIJ=YPTS(N)
       IF(XIJ.NE.FILL.AND.YIJ.NE.FILL) THEN
         IJX(1:2)=FLOOR(XIJ)+(/0,1/)
         IJY(1:2)=FLOOR(YIJ)+(/0,1/)
         XF=XIJ-IJX(1)
         YF=YIJ-IJY(1)
         WX(1)=(1-XF)
         WX(2)=XF
         WY(1)=(1-YF)
         WY(2)=YF
         DO J=1,2
           DO I=1,2
             NXY(I,J,N)=IJKGDS1(IJX(I),IJY(J),IJKGDSA)
             WXY(I,J,N)=WX(I)*WY(J)
           ENDDO
         ENDDO
       ELSE
         NXY(:,:,N)=0
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
!$OMP PARALLEL DO &
!$OMP PRIVATE(NK,K,N,G,W,J,I) &
!$OMP PRIVATE(I1,J1,IXS,JXS,MX,KXS,KXT,IX,JX,NX)
   DO NK=1,NO*KM
     K=(NK-1)/NO+1
     N=NK-NO*(K-1)
     G=0
     W=0
     DO J=1,2
     DO I=1,2
       IF(NXY(I,J,N).GT.0)THEN
         IF(IBI(K).EQ.0.OR.LI(NXY(I,J,N),K)) THEN
           G=G+WXY(I,J,N)*GI(NXY(I,J,N),K)
           W=W+WXY(I,J,N)
         ENDIF
       ENDIF
     ENDDO
     ENDDO
     LO(N,K)=W.GE.PMP
     IF(LO(N,K)) THEN
       GO(N,K)=G/W
     ELSEIF(MSPIRAL.GT.0.AND.XPTS(N).NE.FILL.AND.YPTS(N).NE.FILL) THEN
       I1=NINT(XPTS(N))
       J1=NINT(YPTS(N))
       IXS=SIGN(1.,XPTS(N)-I1)
       JXS=SIGN(1.,YPTS(N)-J1)
       SPIRAL : DO MX=1,MSPIRAL**2
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
         IF(NX.GT.0.)THEN
           IF(LI(NX,K).OR.IBI(K).EQ.0)THEN
             GO(N,K)=GI(NX,K)
             LO(N,K)=.TRUE.
             EXIT SPIRAL
           ENDIF
         ENDIF
       ENDDO SPIRAL
       IF(.NOT.LO(N,K))THEN
         IBO(K)=1
         GO(N,K)=0.
       ENDIF
     ELSE
       GO(N,K)=0.
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
 END SUBROUTINE POLATES0
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 SUBROUTINE CHECK_GRIDS0(GDTNUMI,GDTMPLI,GDTLENI,GDTNUMO,GDTMPLO,GDTLENO, &
                         SAME_GRIDI, SAME_GRIDO) 

 IMPLICIT NONE

 INTEGER,        INTENT(IN   ) :: GDTNUMI, GDTLENI
 INTEGER(KIND=4),INTENT(IN   ) :: GDTMPLI(GDTLENI)
 INTEGER,        INTENT(IN   ) :: GDTNUMO, GDTLENO
 INTEGER(KIND=4),INTENT(IN   ) :: GDTMPLO(GDTLENO)

 INTEGER, SAVE                 :: GDTNUMI_SAVE=-9999 
 INTEGER, SAVE                 :: GDTLENI_SAVE=-9999
 INTEGER, SAVE                 :: GDTMPLI_SAVE(1000)=-9999
 INTEGER, SAVE                 :: GDTNUMO_SAVE=-9999 
 INTEGER, SAVE                 :: GDTLENO_SAVE=-9999
 INTEGER, SAVE                 :: GDTMPLO_SAVE(1000)=-9999

 LOGICAL,        INTENT(  OUT) :: SAME_GRIDI, SAME_GRIDO

 SAME_GRIDI=.FALSE.
 IF(GDTNUMI==GDTNUMI_SAVE)THEN
   IF(GDTLENI==GDTLENI_SAVE)THEN
     IF(ALL(GDTMPLI==GDTMPLI_SAVE(1:GDTLENI)))THEN
       SAME_GRIDI=.TRUE.
     ENDIF
   ENDIF
 ENDIF

 GDTNUMI_SAVE=GDTNUMI
 GDTLENI_SAVE=GDTLENI
 GDTMPLI_SAVE(1:GDTLENI)=GDTMPLI
 GDTMPLI_SAVE(GDTLENI+1:1000)=-9999

 SAME_GRIDO=.FALSE.
 IF(GDTNUMO==GDTNUMO_SAVE)THEN
   IF(GDTLENO==GDTLENO_SAVE)THEN
     IF(ALL(GDTMPLO==GDTMPLO_SAVE(1:GDTLENO)))THEN
       SAME_GRIDO=.TRUE.
     ENDIF
   ENDIF
 ENDIF

 GDTNUMO_SAVE=GDTNUMO
 GDTLENO_SAVE=GDTLENO
 GDTMPLO_SAVE(1:GDTLENO)=GDTMPLO
 GDTMPLO_SAVE(GDTLENO+1:1000)=-9999

 END SUBROUTINE CHECK_GRIDS0
