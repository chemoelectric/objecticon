AC_DEFUN([CHECK_ZLIB],
#
# Handle user hints
#
[AC_MSG_CHECKING(if zlib is wanted)
AC_ARG_WITH(zlib,
[  --with-zlib=DIR root directory path of zlib installation [defaults to
                    /usr/local or /usr if not found in /usr/local]
  --without-zlib to disable zlib usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  ZLIB_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], [
AC_MSG_RESULT(yes)
ZLIB_HOME=/usr/local
if test ! -f "${ZLIB_HOME}/include/zlib.h"
then
        ZLIB_HOME=/usr
fi
])

#
# Locate zlib, if wanted
#
if test -n "${ZLIB_HOME}"
then
        ZLIB_OLD_LDFLAGS=$LDFLAGS
        ZLIB_OLD_CPPFLAGS=$CPPFLAGS
        OI_ADD_LIB_DIR(${ZLIB_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${ZLIB_HOME}/include)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(z, inflateEnd, [zlib_cv_libz=yes], [zlib_cv_libz=no])
        AC_CHECK_HEADER(zlib.h, [zlib_cv_zlib_h=yes], [zlib_cv_zlib_h=no])
        AC_LANG_RESTORE
        if test "$zlib_cv_libz" = "yes" -a "$zlib_cv_zlib_h" = "yes"
        then
                #
                # If both library and header were found, use them
                #
                OI_ADD_LIB(z)
                AC_MSG_CHECKING(zlib in ${ZLIB_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(zlib in ${ZLIB_HOME})
                LDFLAGS="$ZLIB_OLD_LDFLAGS"
                CPPFLAGS="$ZLIB_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])


AC_DEFUN([CHECK_FREETYPE],
#
# Handle user hints
#
[AC_MSG_CHECKING(if freetype is wanted)
AC_ARG_WITH(freetype,
[  --with-freetype=DIR root directory path of freetype installation
  --without-freetype to disable freetype usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  FREETYPE_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], 
[
AC_MSG_RESULT(yes)
for i in /usr /usr/local ; do
    if test -f "$i/include/freetype2/freetype/freetype.h"; then
          FREETYPE_HOME="$i"
    fi
done
])
#
# Locate freetype, if wanted
#
if test -n "${FREETYPE_HOME}"
then
	FREETYPE_OLD_LDFLAGS=$LDFLAGS
	FREETYPE_OLD_CPPFLAGS=$CPPFLAGS
        OI_ADD_LIB_DIR(${FREETYPE_HOME}/lib64)
        OI_ADD_LIB_DIR(${FREETYPE_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${FREETYPE_HOME}/include/freetype2)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(freetype, FT_Open_Face, [freetype_cv_libfreetype=yes], [freetype_cv_libfreetype=no])
        AC_CHECK_HEADER(freetype/config/ftheader.h, [freetype_cv_ftheader_h=yes], [freetype_cv_ftheader_h=no])
        AC_LANG_RESTORE
        if test "$freetype_cv_libfreetype" = "yes" -a "$freetype_cv_ftheader_h" = "yes"
        then
                #
                # If both library and header were found, use them
                #
                OI_ADD_LIB(freetype)
                AC_MSG_CHECKING(freetype in ${FREETYPE_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(freetype in ${FREETYPE_HOME})
		LDFLAGS="$FREETYPE_OLD_LDFLAGS"
		CPPFLAGS="$FREETYPE_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])

AC_DEFUN([CHECK_XLIB],
#
# Handle user hints
#
[AC_MSG_CHECKING(if xlib is wanted)
AC_ARG_WITH(xlib,
[  --with-xlib=DIR root directory path of xlib installation [defaults to
          /usr/X11 or /usr/X11R6 or /usr/openwin if not found in /usr/X11]
  --without-xlib to disable xlib usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  XLIB_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], [
AC_MSG_RESULT(yes)
XLIB_HOME=/usr/X11
if test ! -f "${XLIB_HOME}/include/X11/Xlib.h"
then
        XLIB_HOME=/usr/X11R6
	if test ! -f "${XLIB_HOME}/include/X11/Xlib.h"
	then
	        XLIB_HOME=/usr/openwin
	fi
fi
])

#
# Locate Xlib, if wanted
#
if test -n "${XLIB_HOME}"
then
        XLIB_OLD_LDFLAGS=$LDFLAGS
        XLIB_OLD_CPPFLAGS=$LDFLAGS
        OI_ADD_LIB_DIR(${XLIB_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${XLIB_HOME}/include)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(X11, XAllocColorCells, [xlib_cv_libx=yes], [xlib_cv_libx=no])
        AC_CHECK_HEADER(X11/Xlib.h, [xlib_cv_xlib_h=yes], [xlib_cv_xlib_h=no])
        AC_CHECK_HEADER(X11/Xos.h, [xlib_cv_xos_h=yes], [xlib_cv_xos_h=no])
        AC_CHECK_HEADER(X11/Xutil.h, [xlib_cv_xutil_h=yes], [xlib_cv_xutil_h=no])
        AC_CHECK_HEADER(X11/Xatom.h, [xlib_cv_xatom_h=yes], [xlib_cv_xatom_h=no])
        AC_LANG_RESTORE
        if test "$xlib_cv_libx" = "yes" -a "$xlib_cv_xlib_h" = "yes" -a "$xlib_cv_xos_h" = "yes" -a "$xlib_cv_xutil_h" = "yes" -a "$xlib_cv_xatom_h" = "yes"
        then
                #
                # If both library and header were found, use them
                #
                OI_ADD_LIB(X11)
                AC_MSG_CHECKING(xlib in ${XLIB_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(xlib in ${XLIB_HOME})
                LDFLAGS="$XLIB_OLD_LDFLAGS"
                CPPFLAGS="$XLIB_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])


AC_DEFUN([CHECK_JPEG],
#
# Handle user hints
#
[AC_MSG_CHECKING(if jpeg is wanted)
AC_ARG_WITH(jpeg,
[  --with-jpeg=DIR root directory path of jpeg installation [defaults to
                    /usr/local or /usr if not found in /usr/local]
  --without-jpeg to disable jpeg usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  JPEG_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], [
AC_MSG_RESULT(yes)
JPEG_HOME=/usr/local
if test ! -f "${JPEG_HOME}/include/jpeglib.h"
then
        JPEG_HOME=/usr
fi
])

#
# Locate JPEG, if wanted
#
if test -n "${JPEG_HOME}"
then
        JPEG_OLD_LDFLAGS=$LDFLAGS
        JPEG_OLD_CPPFLAGS=$LDFLAGS
        OI_ADD_LIB_DIR(${JPEG_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${JPEG_HOME}/include)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(jpeg, jpeg_destroy_decompress, [jpeg_cv_libjpeg=yes], [jpeg_cv_libjpeg=no])
        AC_CHECK_HEADER(jpeglib.h, [jpeg_cv_jpeglib_h=yes], [jpeg_cv_jpeglib_h=no])
        AC_CHECK_HEADER(jerror.h, [jpeg_cv_jerror_h=yes], [jpeg_cv_jerror_h=no])
        AC_LANG_RESTORE
        if test "$jpeg_cv_libjpeg" = "yes" -a "$jpeg_cv_jpeglib_h" = "yes" -a "$jpeg_cv_jerror_h" = "yes"
        then
                #
                # If both library and headers were found, use them
                #
                OI_ADD_LIB(jpeg)
                AC_MSG_CHECKING(jpeg in ${JPEG_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(jpeg in ${JPEG_HOME})
                LDFLAGS="$JPEG_OLD_LDFLAGS"
                CPPFLAGS="$JPEG_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])

AC_DEFUN([AC_STRUCT_TIMEZONE_GMTOFF],
[ AC_REQUIRE([AC_STRUCT_TIMEZONE])dnl
  AC_CACHE_CHECK(for struct tm.tm_gmtoff, rb_cv_member_struct_tm_tm_gmtoff,
  [AC_TRY_COMPILE([#include <time.h>],[struct tm t; t.tm_gmtoff = 3600;],
        [rb_cv_member_struct_tm_tm_gmtoff=yes],
        [rb_cv_member_struct_tm_tm_gmtoff=no])])
  AC_CACHE_CHECK(for struct tm.tm_isdst, rb_cv_member_struct_tm_tm_isdst,
  [AC_TRY_COMPILE([#include <time.h>],[struct tm t; t.tm_isdst = 1;],
        [rb_cv_member_struct_tm_tm_isdst=yes],
        [rb_cv_member_struct_tm_tm_isdst=no])])
  if test "$rb_cv_member_struct_tm_tm_gmtoff" = yes; then
     AC_DEFINE(HAVE_STRUCT_TM_TM_GMTOFF)
  fi
  if test "$rb_cv_member_struct_tm_tm_isdst" = yes; then
     AC_DEFINE(HAVE_STRUCT_TM_TM_ISDST)
  fi
])

AC_DEFUN([AC_VAR_TIMEZONE_EXTERNALS],
[  
   AC_CACHE_CHECK(for timezone external, mb_cv_var_timezone,
   [  AC_TRY_LINK([#include <time.h>], [return (int)timezone;],
         mb_cv_var_timezone=yes,
         mb_cv_var_timezone=no)
   ])
   AC_CACHE_CHECK(for altzone external, mb_cv_var_altzone,
   [  AC_TRY_LINK([#include <time.h>], [return (int)altzone;],
         mb_cv_var_altzone=yes,
         mb_cv_var_altzone=no)
   ])
   AC_CACHE_CHECK(for daylight external, mb_cv_var_daylight,
   [  AC_TRY_LINK([#include <time.h>], [return (int)daylight;],
         mb_cv_var_daylight=yes,
         mb_cv_var_daylight=no)
   ])
   AC_CACHE_CHECK(for tzname external, mb_cv_var_tzname,
   [  AC_TRY_LINK([#include <time.h>], [return (int)tzname;],
         mb_cv_var_tzname=yes,
         mb_cv_var_tzname=no)
   ])
   if test $mb_cv_var_timezone = yes; then
      AC_DEFINE([HAVE_TIMEZONE], 1,
              [Define if you have the external `timezone' variable.])
   fi
   if test $mb_cv_var_altzone = yes; then
      AC_DEFINE([HAVE_ALTZONE], 1,
              [Define if you have the external `altzone' variable.])
   fi
   if test $mb_cv_var_daylight = yes; then
      AC_DEFINE([HAVE_DAYLIGHT], 1,
              [Define if you have the external `daylight' variable.])
   fi
   if test $mb_cv_var_tzname = yes; then
      AC_DEFINE([HAVE_TZNAME], 1,
              [Define if you have the external `tzname' variable.])
   fi
])

AC_DEFUN(AC_CHECK_GLOBAL,
[for ac_global in $1
do
   ac_tr_global=HAVE_`echo $ac_global | tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'`
   AC_MSG_CHECKING([for global variable ${ac_global}])
   AC_CACHE_VAL(ac_cv_global_$ac_global,
   [
    AC_TRY_LINK(dnl
    [/* no includes */],
    [ extern long int $ac_global;  exit((int)$ac_global)],
    eval "ac_cv_global_${ac_global}=yes",
    eval "ac_cv_global_${ac_global}=no"
    )
dnl   ]
   )
  if eval "test \"`echo '$ac_cv_global_'$ac_global`\" = yes"; then
    AC_MSG_RESULT(yes)
    AC_DEFINE_UNQUOTED($ac_tr_global)
  else
    AC_MSG_RESULT(no)
  fi
done
])

AC_DEFUN([CHECK_XFT],
#
# Handle user hints
#
[AC_MSG_CHECKING(if xft is wanted)
AC_ARG_WITH(xft,
[  --with-xft=DIR root directory path of Xft installation
  --without-xft to disable xft usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  XFT_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], [
AC_MSG_RESULT(yes)
XFT_HOME=/usr/local
if test ! -f "${XFT_HOME}/include/X11/Xft/Xft.h"
then
        XFT_HOME=/usr
fi
])
#
# Locate XFT, if wanted
#
if test -n "${XFT_HOME}"
then
	XFT_OLD_LDFLAGS=$LDFLAGS
	XFT_OLD_CPPFLAGS=$CPPFLAGS
        OI_ADD_LIB_DIR(${XFT_HOME}/lib64)
        OI_ADD_LIB_DIR(${XFT_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${XFT_HOME}/include)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(Xft, FcPatternCreate, [xft_cv_libxft=yes], [xft_cv_libxft=no])
        AC_CHECK_HEADER(X11/Xft/Xft.h, [xft_cv_xft_h=yes], [xft_cv_xft_h=no])
        AC_LANG_RESTORE
        if test "$xft_cv_libxft" = "yes" -a "$xft_cv_xft_h" = "yes"
        then
                #
                # If both library and header were found, use them
                #
                OI_ADD_LIB(Xft)
                AC_MSG_CHECKING(XFT in ${XFT_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(XFT in ${XFT_HOME})
		LDFLAGS="$XFT_OLD_LDFLAGS"
		CPPFLAGS="$XFT_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])







AC_DEFUN([CHECK_XPM],
#
# Handle user hints
#
[AC_MSG_CHECKING(if xpm is wanted)
AC_ARG_WITH(xpm,
[  --with-xpm=DIR root directory path of Xpm installation
  --without-xpm to disable xpm usage completely],
[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  XPM_HOME="$withval"
else
  AC_MSG_RESULT(no)
fi], [
AC_MSG_RESULT(yes)
XPM_HOME=/usr/local
if test ! -f "${XPM_HOME}/include/X11/xpm.h"
then
        XPM_HOME=/usr
fi
])
#
# Locate XPM, if wanted
#
if test -n "${XPM_HOME}"
then
	XPM_OLD_LDFLAGS=$LDFLAGS
	XPM_OLD_CPPFLAGS=$CPPFLAGS
        OI_ADD_LIB_DIR(${XPM_HOME}/lib64)
        OI_ADD_LIB_DIR(${XPM_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${XPM_HOME}/include)
        AC_LANG_SAVE
        AC_LANG_C
        AC_CHECK_LIB(Xpm, XpmReadFileToPixmap, [xpm_rf_libxpm=yes], [xpm_rf_libxpm=no])
        AC_CHECK_HEADER(X11/xpm.h, [xpm_rf_xpm_h=yes], [xpm_rf_xpm_h=no])
        AC_LANG_RESTORE
        if test "$xpm_rf_libxpm" = "yes" -a "$xpm_rf_xpm_h" = "yes"
        then
                #
                # If both library and header were found, use them
                #
                OI_ADD_LIB(Xpm)
                AC_MSG_CHECKING(XPM in ${XPM_HOME})
                AC_MSG_RESULT(ok)
        else
                #
                # If either header or library was not found, revert and bomb
                #
                AC_MSG_CHECKING(XPM in ${XPM_HOME})
		LDFLAGS="$XPM_OLD_LDFLAGS"
		CPPFLAGS="$XPM_OLD_CPPFLAGS"
                AC_MSG_RESULT(failed)
        fi
fi

])





AC_DEFUN([AX_LIB_MYSQL],
[
    AC_ARG_WITH(mysql,
[  --with-mysql=DIR root directory path of Mysql installation
  --without-mysql to disable mysql usage completely],
        [
        if test "$withval" = "no"; then
            want_mysql="no"
        elif test "$withval" = "yes"; then
            want_mysql="yes"
        else
            want_mysql="yes"
            MYSQL_CONFIG="$withval"
        fi
        ],
        [want_mysql="yes"]
    )

    MYSQL_CFLAGS=""
    MYSQL_LDFLAGS=""
    MYSQL_VERSION=""

    dnl
    dnl Check MySQL libraries (libpq)
    dnl

    if test "$want_mysql" = "yes"; then

        if test -z "$MYSQL_CONFIG" -o test; then
            AC_PATH_PROG([MYSQL_CONFIG], [mysql_config], [no])
        fi

        if test "$MYSQL_CONFIG" != "no"; then
            AC_MSG_CHECKING([for MySQL libraries])

            MYSQL_CFLAGS="`$MYSQL_CONFIG --cflags`"
            MYSQL_LDFLAGS="`$MYSQL_CONFIG --libs`"

            MYSQL_VERSION=`$MYSQL_CONFIG --version`

            AC_DEFINE([HAVE_MYSQL], [1],
                [Define to 1 if MySQL libraries are available])

            found_mysql="yes"
            AC_MSG_RESULT([yes])
        else
            found_mysql="no"
        fi
    fi

    dnl
    dnl Check if required version of MySQL is available
    dnl


    mysql_version_req=ifelse([$1], [], [], [$1])

    if test "$found_mysql" = "yes" -a -n "$mysql_version_req"; then

        AC_MSG_CHECKING([if MySQL version is >= $mysql_version_req])

        dnl Decompose required version string of MySQL
        dnl and calculate its number representation
        mysql_version_req_major=`expr $mysql_version_req : '\([[0-9]]*\)'`
        mysql_version_req_minor=`expr $mysql_version_req : '[[0-9]]*\.\([[0-9]]*\)'`
        mysql_version_req_micro=`expr $mysql_version_req : '[[0-9]]*\.[[0-9]]*\.\([[0-9]]*\)'`
        if test "x$mysql_version_req_micro" = "x"; then
            mysql_version_req_micro="0"
        fi

        mysql_version_req_number=`expr $mysql_version_req_major \* 1000000 \
                                   \+ $mysql_version_req_minor \* 1000 \
                                   \+ $mysql_version_req_micro`

        dnl Decompose version string of installed MySQL
        dnl and calculate its number representation
        mysql_version_major=`expr $MYSQL_VERSION : '\([[0-9]]*\)'`
        mysql_version_minor=`expr $MYSQL_VERSION : '[[0-9]]*\.\([[0-9]]*\)'`
        mysql_version_micro=`expr $MYSQL_VERSION : '[[0-9]]*\.[[0-9]]*\.\([[0-9]]*\)'`
        if test "x$mysql_version_micro" = "x"; then
            mysql_version_micro="0"
        fi

        mysql_version_number=`expr $mysql_version_major \* 1000000 \
                                   \+ $mysql_version_minor \* 1000 \
                                   \+ $mysql_version_micro`

        mysql_version_check=`expr $mysql_version_number \>\= $mysql_version_req_number`
        if test "$mysql_version_check" = "1"; then
            AC_MSG_RESULT([yes])
        else
            AC_MSG_RESULT([no])
        fi
    fi

    AC_SUBST([MYSQL_VERSION])
    AC_SUBST([MYSQL_CFLAGS])
    AC_SUBST([MYSQL_LDFLAGS])
])



dnl ======================================================================
dnl Check for MSG_NOSIGNAL flag
dnl ======================================================================
AC_DEFUN([AC_FLAG_MSG_NOSIGNAL], [
AC_REQUIRE([AC_PROG_CC])
AC_CACHE_CHECK([for MSG_NOSIGNAL], 
  ac_cv_flag_msg_nosignal, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <sys/types.h>
#include <sys/socket.h>]], [[
  int flags = MSG_NOSIGNAL;
]])],[ac_cv_flag_msg_nosignal=yes],[ac_cv_flag_msg_nosignal=no])])
if test "$ac_cv_flag_msg_nosignal" = yes ; then
	AC_DEFINE([HAVE_MSG_NOSIGNAL], 1,
		[Define to 1 if you have MSG_NOSIGNAL flag for send()]) 
fi
])dnl

dnl ======================================================================
dnl Check for unsetenv returning an int
dnl ======================================================================
AC_DEFUN([CHECK_UNSETENV], [
AC_REQUIRE([AC_PROG_CC])
AC_CACHE_CHECK([if unsetenv returns int], 
  ac_cv_flag_unsetenv_int_return, [
AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
#include <stdlib.h>
]], [[
  int x = unsetenv("dummy");
]])],[ac_cv_flag_unsetenv_int_return=yes],[ac_cv_flag_unsetenv_int_return=no])])
if test "$ac_cv_flag_unsetenv_int_return" = yes ; then
	AC_DEFINE([HAVE_UNSETENV_INT_RETURN], 1,
		[Define to 1 if unsetenv returns an int]) 
fi
])dnl


dnl @synopsis ACX_PTHREAD([ACTION-IF-FOUND[, ACTION-IF-NOT-FOUND]])
dnl
dnl @summary figure out how to build C programs using POSIX threads
dnl
dnl This macro figures out how to build C programs using POSIX threads.
dnl It sets the PTHREAD_LIBS output variable to the threads library and
dnl linker flags, and the PTHREAD_CFLAGS output variable to any special
dnl C compiler flags that are needed. (The user can also force certain
dnl compiler flags/libs to be tested by setting these environment
dnl variables.)
dnl
dnl Also sets PTHREAD_CC to any special C compiler that is needed for
dnl multi-threaded programs (defaults to the value of CC otherwise).
dnl (This is necessary on AIX to use the special cc_r compiler alias.)
dnl
dnl NOTE: You are assumed to not only compile your program with these
dnl flags, but also link it with them as well. e.g. you should link
dnl with $PTHREAD_CC $CFLAGS $PTHREAD_CFLAGS $LDFLAGS ... $PTHREAD_LIBS
dnl $LIBS
dnl
dnl If you are only building threads programs, you may wish to use
dnl these variables in your default LIBS, CFLAGS, and CC:
dnl
dnl        LIBS="$PTHREAD_LIBS $LIBS"
dnl        CFLAGS="$CFLAGS $PTHREAD_CFLAGS"
dnl        CC="$PTHREAD_CC"
dnl
dnl In addition, if the PTHREAD_CREATE_JOINABLE thread-attribute
dnl constant has a nonstandard name, defines PTHREAD_CREATE_JOINABLE to
dnl that name (e.g. PTHREAD_CREATE_UNDETACHED on AIX).
dnl
dnl ACTION-IF-FOUND is a list of shell commands to run if a threads
dnl library is found, and ACTION-IF-NOT-FOUND is a list of commands to
dnl run it if it is not found. If ACTION-IF-FOUND is not specified, the
dnl default action will define HAVE_PTHREAD.
dnl
dnl Please let the authors know if this macro fails on any platform, or
dnl if you have any other suggestions or comments. This macro was based
dnl on work by SGJ on autoconf scripts for FFTW (www.fftw.org) (with
dnl help from M. Frigo), as well as ac_pthread and hb_pthread macros
dnl posted by Alejandro Forero Cuervo to the autoconf macro repository.
dnl We are also grateful for the helpful feedback of numerous users.
dnl
dnl @category InstalledPackages
dnl @author Steven G. Johnson <stevenj@alum.mit.edu>
dnl @version 2006-05-29
dnl @license GPLWithACException

AC_DEFUN([ACX_PTHREAD], [
AC_REQUIRE([AC_CANONICAL_HOST])
AC_LANG_SAVE
AC_LANG_C
acx_pthread_ok=no

# We used to check for pthread.h first, but this fails if pthread.h
# requires special compiler flags (e.g. on True64 or Sequent).
# It gets checked for in the link test anyway.

# First of all, check if the user has set any of the PTHREAD_LIBS,
# etcetera environment variables, and if threads linking works using
# them:
if test x"$PTHREAD_LIBS$PTHREAD_CFLAGS" != x; then
        save_CFLAGS="$CFLAGS"
        CFLAGS="$CFLAGS $PTHREAD_CFLAGS"
        save_LIBS="$LIBS"
        LIBS="$PTHREAD_LIBS $LIBS"
        AC_MSG_CHECKING([for pthread_join in LIBS=$PTHREAD_LIBS with CFLAGS=$PTHREAD_CFLAGS])
        AC_TRY_LINK_FUNC(pthread_join, acx_pthread_ok=yes)
        AC_MSG_RESULT($acx_pthread_ok)
        if test x"$acx_pthread_ok" = xno; then
                PTHREAD_LIBS=""
                PTHREAD_CFLAGS=""
        fi
        LIBS="$save_LIBS"
        CFLAGS="$save_CFLAGS"
fi

# We must check for the threads library under a number of different
# names; the ordering is very important because some systems
# (e.g. DEC) have both -lpthread and -lpthreads, where one of the
# libraries is broken (non-POSIX).

# Create a list of thread flags to try.  Items starting with a "-" are
# C compiler flags, and other items are library names, except for "none"
# which indicates that we try without any flags at all, and "pthread-config"
# which is a program returning the flags for the Pth emulation library.

acx_pthread_flags="pthreads none -Kthread -kthread lthread -pthread -pthreads -mthreads pthread --thread-safe -mt pthread-config"

# The ordering *is* (sometimes) important.  Some notes on the
# individual items follow:

# pthreads: AIX (must check this before -lpthread)
# none: in case threads are in libc; should be tried before -Kthread and
#       other compiler flags to prevent continual compiler warnings
# -Kthread: Sequent (threads in libc, but -Kthread needed for pthread.h)
# -kthread: FreeBSD kernel threads (preferred to -pthread since SMP-able)
# lthread: LinuxThreads port on FreeBSD (also preferred to -pthread)
# -pthread: Linux/gcc (kernel threads), BSD/gcc (userland threads)
# -pthreads: Solaris/gcc
# -mthreads: Mingw32/gcc, Lynx/gcc
# -mt: Sun Workshop C (may only link SunOS threads [-lthread], but it
#      doesn't hurt to check since this sometimes defines pthreads too;
#      also defines -D_REENTRANT)
#      ... -mt is also the pthreads flag for HP/aCC
# pthread: Linux, etcetera
# --thread-safe: KAI C++
# pthread-config: use pthread-config program (for GNU Pth library)

case "${host_cpu}-${host_os}" in
        *solaris*)

        # On Solaris (at least, for some versions), libc contains stubbed
        # (non-functional) versions of the pthreads routines, so link-based
        # tests will erroneously succeed.  (We need to link with -pthreads/-mt/
        # -lpthread.)  (The stubs are missing pthread_cleanup_push, or rather
        # a function called by this macro, so we could check for that, but
        # who knows whether they'll stub that too in a future libc.)  So,
        # we'll just look for -pthreads and -lpthread first:

        acx_pthread_flags="-pthreads pthread -mt -pthread $acx_pthread_flags"
        ;;
esac

if test x"$acx_pthread_ok" = xno; then
for flag in $acx_pthread_flags; do
        case $flag in
                none)
                AC_MSG_CHECKING([whether pthreads work without any flags])
                ;;

                -*)
                AC_MSG_CHECKING([whether pthreads work with $flag])
                PTHREAD_CFLAGS="$flag"
                ;;

		pthread-config)
		AC_CHECK_PROG(acx_pthread_config, pthread-config, yes, no)
		if test x"$acx_pthread_config" = xno; then continue; fi
		PTHREAD_CFLAGS="`pthread-config --cflags`"
		PTHREAD_LIBS="`pthread-config --ldflags` `pthread-config --libs`"
		;;

                *)
                AC_MSG_CHECKING([for the pthreads library -l$flag])
                PTHREAD_LIBS="-l$flag"
                ;;
        esac

        save_LIBS="$LIBS"
        save_CFLAGS="$CFLAGS"
        LIBS="$PTHREAD_LIBS $LIBS"
        CFLAGS="$CFLAGS $PTHREAD_CFLAGS"

        # Check for various functions.  We must include pthread.h,
        # since some functions may be macros.  (On the Sequent, we
        # need a special flag -Kthread to make this header compile.)
        # We check for pthread_join because it is in -lpthread on IRIX
        # while pthread_create is in libc.  We check for pthread_attr_init
        # due to DEC craziness with -lpthreads.  We check for
        # pthread_cleanup_push because it is one of the few pthread
        # functions on Solaris that doesn't have a non-functional libc stub.
        # We try pthread_create on general principles.
        AC_TRY_LINK([#include <pthread.h>],
                    [pthread_t th; pthread_join(th, 0);
                     pthread_attr_init(0); pthread_cleanup_push(0, 0);
                     pthread_create(0,0,0,0); pthread_cleanup_pop(0); ],
                    [acx_pthread_ok=yes])

        LIBS="$save_LIBS"
        CFLAGS="$save_CFLAGS"

        AC_MSG_RESULT($acx_pthread_ok)
        if test "x$acx_pthread_ok" = xyes; then
                break;
        fi

        PTHREAD_LIBS=""
        PTHREAD_CFLAGS=""
done
fi

# Various other checks:
if test "x$acx_pthread_ok" = xyes; then
        save_LIBS="$LIBS"
        LIBS="$PTHREAD_LIBS $LIBS"
        save_CFLAGS="$CFLAGS"
        CFLAGS="$CFLAGS $PTHREAD_CFLAGS"

        # Detect AIX lossage: JOINABLE attribute is called UNDETACHED.
	AC_MSG_CHECKING([for joinable pthread attribute])
	attr_name=unknown
	for attr in PTHREAD_CREATE_JOINABLE PTHREAD_CREATE_UNDETACHED; do
	    AC_TRY_LINK([#include <pthread.h>], [int attr=$attr; return attr;],
                        [attr_name=$attr; break])
	done
        AC_MSG_RESULT($attr_name)
        if test "$attr_name" != PTHREAD_CREATE_JOINABLE; then
            AC_DEFINE_UNQUOTED(PTHREAD_CREATE_JOINABLE, $attr_name,
                               [Define to necessary symbol if this constant
                                uses a non-standard name on your system.])
        fi

        AC_MSG_CHECKING([if more special flags are required for pthreads])
        flag=no
        case "${host_cpu}-${host_os}" in
            *-aix* | *-freebsd* | *-darwin*) flag="-D_THREAD_SAFE";;
            *solaris* | *-osf* | *-hpux*) flag="-D_REENTRANT";;
        esac
        AC_MSG_RESULT(${flag})
        if test "x$flag" != xno; then
            PTHREAD_CFLAGS="$flag $PTHREAD_CFLAGS"
        fi

        LIBS="$save_LIBS"
        CFLAGS="$save_CFLAGS"

        # More AIX lossage: must compile with xlc_r or cc_r
	if test x"$GCC" != xyes; then
          AC_CHECK_PROGS(PTHREAD_CC, xlc_r cc_r, ${CC})
        else
          PTHREAD_CC=$CC
	fi
else
        PTHREAD_CC="$CC"
fi

AC_SUBST(PTHREAD_LIBS)
AC_SUBST(PTHREAD_CFLAGS)
AC_SUBST(PTHREAD_CC)

# Finally, execute ACTION-IF-FOUND/ACTION-IF-NOT-FOUND:
if test x"$acx_pthread_ok" = xyes; then
        ifelse([$1],,AC_DEFINE(HAVE_PTHREAD,1,[Define if you have POSIX threads libraries and header files.]),[$1])
        :
else
        acx_pthread_ok=no
        $2
fi
AC_LANG_RESTORE
])dnl ACX_PTHREAD


AC_DEFUN([CHECK_STACK_ALIGN],
   [ AC_MSG_CHECKING(stack alignment)
     AC_ARG_WITH(stack-align,
        [  --with-stack-align=N stack alignment in bytes ],
        [
             case "$withval" in
                        @<:@0-9@:>@*)
                                ac_stack_align_bytes=$withval
                                ;;
                        *)
                                AC_MSG_ERROR(not an integer: $withval)
                                ;;
             esac
        ])

     if test -z "$ac_stack_align_bytes"; then
         case $host in
           sparc64-*-linux-*) ac_stack_align_bytes=64 ;;
           *) (( ac_stack_align_bytes=2 * $ac_cv_sizeof_voidp )) ;;
         esac
     fi

     AC_MSG_RESULT([$ac_stack_align_bytes bytes])
     AC_DEFINE_UNQUOTED(STACK_ALIGN_BYTES, $ac_stack_align_bytes)
   ]
)

AC_DEFUN([CHECK_DOUBLE_HAS_WORD_ALIGNMENT],
   [ AC_MSG_CHECKING(if double has word alignment)
     AC_RUN_IFELSE(
                   [AC_LANG_PROGRAM([[
                     #include <stdio.h>
                     #include <stddef.h>]],[[
                        struct t { char x; double d; };
                        return (sizeof(double) % sizeof(void*) == 0 &&
                                offsetof(struct t, d) == sizeof(void *)) ? 0:1;
                     ]])],
                   [
                   AC_MSG_RESULT(yes)
                   AC_DEFINE(DOUBLE_HAS_WORD_ALIGNMENT)
                   ],
                   [
                   AC_MSG_RESULT(no)
                   ])
])

AC_DEFUN([ACX_UCONTEXT],
  [
  acx_ucontext_ok=yes
  AC_CHECK_HEADER(ucontext.h, [], [acx_ucontext_ok=no])
  AC_CHECK_FUNC(makecontext, [], [acx_ucontext_ok=no])
  AC_CHECK_FUNC(swapcontext, [], [acx_ucontext_ok=no])
  AC_CHECK_FUNC(getcontext, [], [acx_ucontext_ok=no])
  ]
)

AC_DEFUN([ACX_CONTEXT_SWITCH],
  [
AC_ARG_WITH(context-switch,
  [  --with-context-switch=ucontext/pthread/pth use given context-switch],
  [
        acx_context_switch="$withval"
        if test ! -d config/system/$withval ; then
                AC_ERROR([Unknown context-switch type])
        fi
        if test "$withval" = pth ; then
                dnl Find libpth - very basic check at present.
                OI_ADD_LIB(pth)
                if ! test "$ac_cv_lib_pth_main" = yes; then
                        AC_MSG_ERROR([*** Couldn't find libpth library (-lpth) - can't use pth context-switch.])
                fi
        fi
        if test "$withval" = pthread ; then
                dnl detect and add pthread libs if they can be found
                dnl
                ACX_PTHREAD()
                if test "$acx_pthread_ok" = yes; then
                      LIBS="$PTHREAD_LIBS $LIBS"
                      CFLAGS="$CFLAGS $PTHREAD_CFLAGS"
                      CC="$PTHREAD_CC"
                      AC_DEFINE(HAVE_CUSTOM_C_STACKS,1)
                else
                      AC_MSG_ERROR([*** Couldn't find pthreads - can't use pthread context-switch.])
                fi
        fi
  ],
  [
        AC_CANONICAL_HOST()
        case $host in
             i?86-*-linux*) acx_context_switch=linux_x86 ;;
             x86_64-*-linux*) acx_context_switch=linux_x86_64;;
             powerpc-*-linux*) acx_context_switch=linux_powerpc;;
             *) 
                ACX_UCONTEXT()
                if test "$acx_ucontext_ok" = yes; then
                        acx_context_switch=ucontext
                else
                        ACX_PTHREAD()
                        if test "$acx_pthread_ok" = yes; then
                                acx_context_switch=pthread
                                LIBS="$PTHREAD_LIBS $LIBS"
                                CFLAGS="$CFLAGS $PTHREAD_CFLAGS"
                                CC="$PTHREAD_CC"
                                AC_DEFINE(HAVE_CUSTOM_C_STACKS,1)
                        else
                                acx_context_switch=default
                        fi
                fi
                ;;
        esac
     ])

     if test "$acx_context_switch" = pthread -o "$acx_context_switch" = ucontext \
             -o "$acx_context_switch" = pth; then
             AC_DEFINE(HAVE_COCLEAN,1)
     fi
  ]
)
