#include "CTRL_OPTIONS.h"

      subroutine ctrl_set_pack_xy(
     &     cunit, ivar, precondScalar,
     &     fname, masktype, weighttype,
     &     lxxadxx, myThid )

c     ==================================================================
c     SUBROUTINE ctrl_set_pack_xy
c     ==================================================================
c
c     o Compress the control vector such that only ocean points are
c       written to file.
c
c     ==================================================================

      implicit none

c     == global variables ==

#include "EEPARAMS.h"
#include "SIZE.h"
#include "PARAMS.h"
#include "GRID.h"

#include "CTRL_SIZE.h"
#include "CTRL.h"
#include "OPTIMCYCLE.h"

c     == routine arguments ==

      integer cunit
      integer ivar
      _RL precondScalar
      character*(MAX_LEN_FNAM) fname
      character*(  9) masktype
      character*(MAX_LEN_FNAM) weighttype
      logical lxxadxx
      integer myThid

#ifndef EXCLUDE_CTRL_PACK
c     == external ==
      integer  ilnblnk
      external ilnblnk

c     == local variables ==
      integer bi,bj
      integer i,j,k
      integer ii, irec
      integer cbuffindex
      real*4 cbuff( sNx*nSx*nPx*sNy*nSy*nPy )
      character*(MAX_LEN_FNAM) cfile2, cfile3
C========================================================================
# ifndef ALLOW_PACKUNPACK_METHOD2
      integer ip,jp
      integer nrec_nl
      integer itlo,ithi
      integer jtlo,jthi
      integer jmin,jmax
      integer imin,imax
      _RL     globmsk  ( sNx,nSx,nPx,sNy,nSy,nPy,Nr )
      _RL     globfld3d( sNx,nSx,nPx,sNy,nSy,nPy,Nr )
      integer reclen, irectrue
      integer cunit2, cunit3
      real*4 globfldtmp2( sNx,nSx,nPx,sNy,nSy,nPy )
      real*4 globfldtmp3( sNx,nSx,nPx,sNy,nSy,nPy )
# else /* ALLOW_PACKUNPACK_METHOD2 */
      integer il
      _RL msk3d     (1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      real*8 msk2d_buf    (sNx,sNy,nSx,nSy)
      real*8 msk2d_buf_glo(Nx,Ny)
      real*8 fld2d_buf    (sNx,sNy,nSx,nSy)
      real*8 fld2d_buf_glo(Nx,Ny)
      _RL fld2dDim  (1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL fld2dNodim(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL dummy
# endif /* ALLOW_PACKUNPACK_METHOD2 */
c     == end of interface ==

# ifndef ALLOW_PACKUNPACK_METHOD2
      jtlo = 1
      jthi = nSy
      itlo = 1
      ithi = nSx
      jmin = 1
      jmax = sNy
      imin = 1
      imax = sNx

      nbuffglobal = nbuffglobal + 1

c     Initialise temporary file
      do k = 1,Nr
       do jp = 1,nPy
        do bj = jtlo,jthi
         do j = jmin,jmax
          do ip = 1,nPx
           do bi = itlo,ithi
            do i = imin,imax
             globfld3d  (i,bi,ip,j,bj,jp,k) = 0. _d 0
             globmsk    (i,bi,ip,j,bj,jp,k) = 0. _d 0
             globfldtmp2(i,bi,ip,j,bj,jp)   = 0. _d 0
             globfldtmp3(i,bi,ip,j,bj,jp)   = 0. _d 0
            enddo
           enddo
          enddo
         enddo
        enddo
       enddo
      enddo

c--   Only the master thread will do I/O.
      _BEGIN_MASTER( myThid )

      if ( doPackDiag ) then
         if ( lxxadxx ) then
            write(cfile2,'(a,I3.3,a,I4.4,a)')
     &           'diag_pack_nonout_ctrl_',
     &           ivar, '_', optimcycle, '.bin'
            write(cfile3,'(a,I3.3,a,I4.4,a)')
     &           'diag_pack_dimout_ctrl_',
     &           ivar, '_', optimcycle, '.bin'
         else
            write(cfile2,'(a,I3.3,a,I4.4,a)')
     &           'diag_pack_nonout_grad_',
     &           ivar, '_', optimcycle, '.bin'
            write(cfile3,'(a,I3.3,a,I4.4,a)')
     &           'diag_pack_dimout_grad_',
     &           ivar, '_', optimcycle, '.bin'
         endif

         reclen = FLOAT(sNx*nSx*nPx*sNy*nSy*nPy*4)
         call mdsfindunit( cunit2, myThid )
         open( cunit2, file=cfile2, status='unknown',
     &        access='direct', recl=reclen )
         call mdsfindunit( cunit3, myThid )
         open( cunit3, file=cfile3, status='unknown',
     &        access='direct', recl=reclen )
      endif

      call MDSREADFIELD_3D_GL(
     &     masktype, ctrlprec, 'RL',
     &     Nr, globmsk, 1, myThid)

      nrec_nl=int(ncvarrecs(ivar)/Nr)
      do irec = 1, nrec_nl

       call MDSREADFIELD_3D_GL( fname, ctrlprec, 'RL',
     &      Nr, globfld3d, irec, myThid)
       do k = 1, Nr
        irectrue = (irec-1)*Nr + k
#ifndef ALLOW_ADMTLM
        write(cunit) ncvarindex(ivar)
        write(cunit) 1
        write(cunit) 1
#endif
        cbuffindex = 0
        do jp = 1,nPy
         do bj = jtlo,jthi
          do j = jmin,jmax
           do ip = 1,nPx
            do bi = itlo,ithi
             do i = imin,imax
              if (globmsk(i,bi,ip,j,bj,jp,1)  .ne. 0. ) then
               cbuffindex = cbuffindex + 1
cph(
               globfldtmp3(i,bi,ip,j,bj,jp) =
     &              globfld3d(i,bi,ip,j,bj,jp,k)
cph)
               if (lxxadxx) then
                cbuff(cbuffindex) =
     &               globfld3d(i,bi,ip,j,bj,jp,k)
     &               / PrecondScalar
               else
                cbuff(cbuffindex) =
     &               globfld3d(i,bi,ip,j,bj,jp,k)
     &               * PrecondScalar
               endif
cph(
               globfldtmp2(i,bi,ip,j,bj,jp) = cbuff(cbuffindex)
cph)
#ifdef ALLOW_ADMTLM
               nveccount = nveccount + 1
               phtmpadmtlm(nveccount) = cbuff(cbuffindex)
#endif
              endif
             enddo
            enddo
           enddo
          enddo
         enddo
        enddo
c           --> check cbuffindex.
        if ( cbuffindex .gt. 0) then
#ifndef ALLOW_ADMTLM
         write(cunit) cbuffindex
         write(cunit) 1
cph#endif
         write(cunit) (cbuff(ii), ii=1,cbuffindex)
#endif
        endif
c
        if ( doPackDiag ) then
         write(cunit2,rec=irectrue) globfldtmp2
         write(cunit3,rec=irectrue) globfldtmp3
        endif
c
       enddo
c
c     -- end of irec loop --
      enddo

      do irec = nrec_nl*Nr+1, ncvarrecs(ivar)

       call MDSREADFIELD_2D_GL( fname, ctrlprec, 'RL',
     &        1, globfld3d(1,1,1,1,1,1,1), irec, myThid)

#ifndef ALLOW_ADMTLM
       write(cunit) ncvarindex(ivar)
       write(cunit) 1
       write(cunit) 1
#endif
       do k = 1, 1
        irectrue = irec
        cbuffindex = 0
        do jp = 1,nPy
         do bj = jtlo,jthi
          do j = jmin,jmax
           do ip = 1,nPx
            do bi = itlo,ithi
             do i = imin,imax
              if (globmsk(i,bi,ip,j,bj,jp,k)  .ne. 0. ) then
               cbuffindex = cbuffindex + 1
cph(
               globfldtmp3(i,bi,ip,j,bj,jp) =
     &              globfld3d(i,bi,ip,j,bj,jp,k)
cph)
               if (lxxadxx) then
                cbuff(cbuffindex) =
     &               globfld3d(i,bi,ip,j,bj,jp,k)
     &               / PrecondScalar
               else
                cbuff(cbuffindex) =
     &               globfld3d(i,bi,ip,j,bj,jp,k)
     &               * PrecondScalar
               endif
cph(
               globfldtmp2(i,bi,ip,j,bj,jp) = cbuff(cbuffindex)
cph)
#ifdef ALLOW_ADMTLM
               nveccount = nveccount + 1
               phtmpadmtlm(nveccount) = cbuff(cbuffindex)
#endif
              endif
             enddo
            enddo
           enddo
          enddo
         enddo
        enddo
c           --> check cbuffindex.
            if ( cbuffindex .gt. 0) then
#ifndef ALLOW_ADMTLM
               write(cunit) cbuffindex
               write(cunit) k
cph#endif
               write(cunit) (cbuff(ii), ii=1,cbuffindex)
#endif
            endif
c
            if ( doPackDiag ) then
               write(cunit2,rec=irectrue) globfldtmp2
               write(cunit3,rec=irectrue) globfldtmp3
            endif
c
         enddo
c
c     -- end of irec loop --
      enddo

      if ( doPackDiag ) then
         close ( cunit2 )
         close ( cunit3 )
      endif

      _END_MASTER( myThid )

# else /* ALLOW_PACKUNPACK_METHOD2 */

c-- part 1: preliminary reads and definitions

#ifdef ALLOW_AUTODIFF
      call active_read_xyz(masktype, msk3d, 1,
     &    .FALSE., .FALSE., 0 , myThid, dummy)
#else
      CALL READ_REC_XYZ_RL( masktype, msk3d, 1, 1, myThid )
#endif

      if ( doPackDiag ) then
         il = ilnblnk( fname )
         if ( lxxadxx ) then
            write(cfile2,'(2a)') fname(1:il),'.pack_ctrl_adim'
            write(cfile3,'(2a)') fname(1:il),'.pack_ctrl_dim'
         else
            write(cfile2,'(2a)') fname(1:il),'.pack_grad_adim'
            write(cfile3,'(2a)') fname(1:il),'.pack_grad_dim'
         endif
      endif

c-- part 2: loop over records

      do irec = 1, ncvarrecs(ivar)

c-- 2.1:
      call READ_REC_3D_RL( fname, ctrlprec,
     &        1, fld2dDim, irec, 0, myThid)

c-- 2.2: normalize field if needed
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
         DO j=1,sNy
          DO i=1,sNx
           if (msk3d(i,j,1,bi,bj).EQ.0. _d 0) then
            fld2dDim(i,j,bi,bj)=0. _d 0
            fld2dNodim(i,j,bi,bj)=0. _d 0
           else
            if (lxxadxx) then
             fld2dNodim(i,j,bi,bj) =
     &            fld2dDim(i,j,bi,bj) / PrecondScalar
            else
             fld2dNodim(i,j,bi,bj) =
     &              fld2dDim(i,j,bi,bj) * PrecondScalar
            endif
           endif
          ENDDO
         ENDDO
       ENDDO
      ENDDO

c-- 2.3:
      if ( doPackDiag ) then
      call WRITE_REC_3D_RL( cfile2, ctrlprec,
     &        1, fld2dNodim, irec, 0, myThid)
      call WRITE_REC_3D_RL( cfile3, ctrlprec,
     &        1, fld2dDim, irec, 0, myThid)
      endif

c-- 2.4: array -> buffer -> global buffer -> global file

#ifndef ALLOW_ADMTLM
      _BEGIN_MASTER( myThid )
      IF ( myProcId .eq. 0 ) THEN
         write(cunit) ncvarindex(ivar)
         write(cunit) 1
         write(cunit) 1
      ENDIF
      _END_MASTER( myThid )
      _BARRIER
#endif

      do k = 1, 1

        CALL MDS_PASS_R8toRL( fld2d_buf, fld2dNodim,
     &                 0, 0, 1, k, 1, 0, 0, .FALSE., myThid )
        CALL BAR2( myThid )
        CALL GATHER_2D_R8( fld2d_buf_glo, fld2d_buf,
     &                       Nx,Ny,.FALSE.,.TRUE.,myThid)
        CALL BAR2( myThid )

        CALL MDS_PASS_R8toRL( msk2d_buf, msk3d,
     &                 0, 0, 1, k, Nr, 0, 0, .FALSE., myThid )
        CALL BAR2( myThid )
        CALL GATHER_2D_R8( msk2d_buf_glo, msk2d_buf,
     &                       Nx,Ny,.FALSE.,.TRUE.,myThid)
        CALL BAR2( myThid )

        _BEGIN_MASTER( myThid )
        cbuffindex = 0
        IF ( myProcId .eq. 0 ) THEN

        DO j=1,Ny
          DO i=1,Nx
            if (msk2d_buf_glo(i,j) .ne. 0. ) then
               cbuffindex = cbuffindex + 1
               cbuff(cbuffindex) = fld2d_buf_glo(i,j)
#ifdef ALLOW_ADMTLM
               nveccount = nveccount + 1
               phtmpadmtlm(nveccount) = cbuff(cbuffindex)
#endif
            endif
          ENDDO
        ENDDO

#ifndef ALLOW_ADMTLM
        if ( cbuffindex .gt. 0) then
          write(cunit) cbuffindex
          write(cunit) k
          write(cunit) (cbuff(ii), ii=1,cbuffindex)
        endif
#endif

        ENDIF
        _END_MASTER( myThid )
        _BARRIER

      enddo
      enddo

# endif /* ALLOW_PACKUNPACK_METHOD2 */
# endif /* EXCLUDE_CTRL_PACK */

      return
      end
