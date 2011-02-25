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




AC_DEFUN([CHECK_PNG],
[
    AC_MSG_CHECKING(if png is wanted)
    AC_ARG_WITH(png,
[  --with-png=path of libpng-config program
  --without-png to disable png usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
         PNG_CONFIG="$withval"
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       AC_MSG_RESULT(yes)
       AC_PATH_PROG([PNG_CONFIG], [libpng-config], [])
   ]
)

    if test -n "$PNG_CONFIG"; then
           AC_MSG_CHECKING([for libpng library])

           PNG_VERSION=""
           PNG_VERSION=`$PNG_CONFIG --version`
           if test -n "$PNG_VERSION"; then
               AX_COMPARE_VERSION([$PNG_VERSION],[ge],[1.2.37], [ver_ok=yes], [ver_ok=no])
               if test "$ver_ok" = "yes"; then
                    AC_MSG_RESULT([yes])
                    OI_ADD_LIB(png12)
                    PNG_LIB_DIR=`$PNG_CONFIG --libdir`
                    OI_ADD_LIB_DIR($PNG_LIB_DIR)
                    PNG_INCLUDE_DIR=`$PNG_CONFIG --I_opts`
                    if test "$PNG_INCLUDE_DIR" != "-I/usr/include"; then
                       CPPFLAGS="$CPPFLAGS $PNG_INCLUDE_DIR"
                    fi
                    AC_DEFINE(HAVE_LIBPNG)
               else
                    AC_MSG_RESULT([no])
                    echo "*** At least version 1.2.37 of libpng is required for png support (currently have $PNG_VERSION)"
                    PNG_VERSION=""
               fi
           else
               AC_MSG_RESULT([no])
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
    AC_MSG_CHECKING(if mysql is wanted)
    AC_ARG_WITH(mysql,
[  --with-mysql=path of mysql_config program
  --without-mysql to disable mysql usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
         MYSQL_CONFIG="$withval"
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       AC_MSG_RESULT(yes)
       AC_PATH_PROG([MYSQL_CONFIG], [mysql_config], [])
   ]
)

    MYSQL_CFLAGS=""
    MYSQL_LDFLAGS=""
    MYSQL_VERSION=""
    if test -n "$MYSQL_CONFIG"; then
            AC_MSG_CHECKING([for MySQL libraries])

            MYSQL_VERSION=`$MYSQL_CONFIG --version`

           if test -n "$MYSQL_VERSION"; then
               MYSQL_CFLAGS="`$MYSQL_CONFIG --cflags`"
               MYSQL_LDFLAGS="`$MYSQL_CONFIG --libs`"
               AC_DEFINE(HAVE_MYSQL)
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

AC_DEFUN([CHECK_COMPUTED_GOTO],
   [ AC_MSG_CHECKING(for computed goto support)
     AC_COMPILE_IFELSE(
         [AC_LANG_PROGRAM([[]], [[
             static void *labels[] = {&&label0, &&label1, &&label2};
             unsigned char *pc = 0;
             goto *labels[*pc];
             label0: ;
             label1: ;
             label2: ;
             ]])], 
        [
          AC_MSG_RESULT(yes)
          AC_DEFINE(HAVE_COMPUTED_GOTO)
                   ],
                   [
                   AC_MSG_RESULT(no)
                   ])
])





dnl @synopsis AX_COMPARE_VERSION(VERSION_A, OP, VERSION_B, [ACTION-IF-TRUE], [ACTION-IF-FALSE])
dnl
dnl This macro compares two version strings. It is used heavily in the
dnl macro _AX_PATH_BDB for library checking. Due to the various number
dnl of minor-version numbers that can exist, and the fact that string
dnl comparisons are not compatible with numeric comparisons, this is
dnl not necessarily trivial to do in a autoconf script. This macro
dnl makes doing these comparisons easy.
dnl
dnl The six basic comparisons are available, as well as checking
dnl equality limited to a certain number of minor-version levels.
dnl
dnl The operator OP determines what type of comparison to do, and can
dnl be one of:
dnl
dnl  eq  - equal (test A == B)
dnl  ne  - not equal (test A != B)
dnl  le  - less than or equal (test A <= B)
dnl  ge  - greater than or equal (test A >= B)
dnl  lt  - less than (test A < B)
dnl  gt  - greater than (test A > B)
dnl
dnl Additionally, the eq and ne operator can have a number after it to
dnl limit the test to that number of minor versions.
dnl
dnl  eq0 - equal up to the length of the shorter version
dnl  ne0 - not equal up to the length of the shorter version
dnl  eqN - equal up to N sub-version levels
dnl  neN - not equal up to N sub-version levels
dnl
dnl When the condition is true, shell commands ACTION-IF-TRUE are run,
dnl otherwise shell commands ACTION-IF-FALSE are run. The environment
dnl variable 'ax_compare_version' is always set to either 'true' or
dnl 'false' as well.
dnl
dnl Examples:
dnl
dnl   AX_COMPARE_VERSION([3.15.7],[lt],[3.15.8])
dnl   AX_COMPARE_VERSION([3.15],[lt],[3.15.8])
dnl
dnl would both be true.
dnl
dnl   AX_COMPARE_VERSION([3.15.7],[eq],[3.15.8])
dnl   AX_COMPARE_VERSION([3.15],[gt],[3.15.8])
dnl
dnl would both be false.
dnl
dnl   AX_COMPARE_VERSION([3.15.7],[eq2],[3.15.8])
dnl
dnl would be true because it is only comparing two minor versions.
dnl
dnl   AX_COMPARE_VERSION([3.15.7],[eq0],[3.15])
dnl
dnl would be true because it is only comparing the lesser number of
dnl minor versions of the two values.
dnl
dnl Note: The characters that separate the version numbers do not
dnl matter. An empty string is the same as version 0. OP is evaluated
dnl by autoconf, not configure, so must be a string, not a variable.
dnl
dnl The author would like to acknowledge Guido Draheim whose advice
dnl about the m4_case and m4_ifvaln functions make this macro only
dnl include the portions necessary to perform the specific comparison
dnl specified by the OP argument in the final configure script.
dnl
dnl @category Misc
dnl @author Tim Toolan <toolan@ele.uri.edu>
dnl @version 2004-03-01
dnl @license GPLWithACException

dnl #########################################################################
AC_DEFUN([AX_COMPARE_VERSION], [
  # Used to indicate true or false condition
  ax_compare_version=false

  # Convert the two version strings to be compared into a format that
  # allows a simple string comparison.  The end result is that a version
  # string of the form 1.12.5-r617 will be converted to the form
  # 0001001200050617.  In other words, each number is zero padded to four
  # digits, and non digits are removed.
  AS_VAR_PUSHDEF([A],[ax_compare_version_A])
  A=`echo "$1" | sed -e 's/\([[0-9]]*\)/Z\1Z/g' \
                     -e 's/Z\([[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/Z\([[0-9]][[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/Z\([[0-9]][[0-9]][[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/[[^0-9]]//g'`

  AS_VAR_PUSHDEF([B],[ax_compare_version_B])
  B=`echo "$3" | sed -e 's/\([[0-9]]*\)/Z\1Z/g' \
                     -e 's/Z\([[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/Z\([[0-9]][[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/Z\([[0-9]][[0-9]][[0-9]]\)Z/Z0\1Z/g' \
                     -e 's/[[^0-9]]//g'`

  dnl # In the case of le, ge, lt, and gt, the strings are sorted as necessary
  dnl # then the first line is used to determine if the condition is true.
  dnl # The sed right after the echo is to remove any indented white space.
  m4_case(m4_tolower($2),
  [lt],[
    ax_compare_version=`echo "x$A
x$B" | sed 's/^ *//' | sort -r | sed "s/x${A}/false/;s/x${B}/true/;1q"`
  ],
  [gt],[
    ax_compare_version=`echo "x$A
x$B" | sed 's/^ *//' | sort | sed "s/x${A}/false/;s/x${B}/true/;1q"`
  ],
  [le],[
    ax_compare_version=`echo "x$A
x$B" | sed 's/^ *//' | sort | sed "s/x${A}/true/;s/x${B}/false/;1q"`
  ],
  [ge],[
    ax_compare_version=`echo "x$A
x$B" | sed 's/^ *//' | sort -r | sed "s/x${A}/true/;s/x${B}/false/;1q"`
  ],[
    dnl Split the operator from the subversion count if present.
    m4_bmatch(m4_substr($2,2),
    [0],[
      # A count of zero means use the length of the shorter version.
      # Determine the number of characters in A and B.
      ax_compare_version_len_A=`echo "$A" | awk '{print(length)}'`
      ax_compare_version_len_B=`echo "$B" | awk '{print(length)}'`

      # Set A to no more than B's length and B to no more than A's length.
      A=`echo "$A" | sed "s/\(.\{$ax_compare_version_len_B\}\).*/\1/"`
      B=`echo "$B" | sed "s/\(.\{$ax_compare_version_len_A\}\).*/\1/"`
    ],
    [[0-9]+],[
      # A count greater than zero means use only that many subversions
      A=`echo "$A" | sed "s/\(\([[0-9]]\{4\}\)\{m4_substr($2,2)\}\).*/\1/"`
      B=`echo "$B" | sed "s/\(\([[0-9]]\{4\}\)\{m4_substr($2,2)\}\).*/\1/"`
    ],
    [.+],[
      AC_WARNING(
        [illegal OP numeric parameter: $2])
    ],[])

    # Pad zeros at end of numbers to make same length.
    ax_compare_version_tmp_A="$A`echo $B | sed 's/./0/g'`"
    B="$B`echo $A | sed 's/./0/g'`"
    A="$ax_compare_version_tmp_A"

    # Check for equality or inequality as necessary.
    m4_case(m4_tolower(m4_substr($2,0,2)),
    [eq],[
      test "x$A" = "x$B" && ax_compare_version=true
    ],
    [ne],[
      test "x$A" != "x$B" && ax_compare_version=true
    ],[
      AC_WARNING([illegal OP parameter: $2])
    ])
  ])

  AS_VAR_POPDEF([A])dnl
  AS_VAR_POPDEF([B])dnl

  dnl # Execute ACTION-IF-TRUE / ACTION-IF-FALSE.
  if test "$ax_compare_version" = "true" ; then
    m4_ifvaln([$4],[$4],[:])dnl
    m4_ifvaln([$5],[else $5])dnl
  fi
]) dnl AX_COMPARE_VERSION





# ===========================================================================
#     http://www.gnu.org/software/autoconf-archive/ax_check_openssl.html
# ===========================================================================
#
# SYNOPSIS
#
#   AX_CHECK_OPENSSL([action-if-found[, action-if-not-found]])
#
# DESCRIPTION
#
#   Look for OpenSSL in a number of default spots, or in a user-selected
#   spot (via --with-openssl).  Sets
#
#     OPENSSL_INCLUDES to the include directives required
#     OPENSSL_LIBS to the -l directives required
#     OPENSSL_LDFLAGS to the -L or -R flags required
#
#   and calls ACTION-IF-FOUND or ACTION-IF-NOT-FOUND appropriately
#
#   This macro sets OPENSSL_INCLUDES such that source files should use the
#   openssl/ directory in include directives:
#
#     #include <openssl/hmac.h>
#
# LICENSE
#
#   Copyright (c) 2009,2010 Zmanda Inc. <http://www.zmanda.com/>
#   Copyright (c) 2009,2010 Dustin J. Mitchell <dustin@zmanda.com>
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved. This file is offered as-is, without any
#   warranty.

#serial 7

AC_DEFUN([AX_CHECK_OPENSSL], [
    found=false
    AC_MSG_CHECKING(if OpenSSL is wanted)
    AC_ARG_WITH(openssl,
        [  --with-openssl=DIR root of the OpenSSL directory
  --without-openssl to disable OpenSSL usage completely],

[if test "$withval" != no ; then
  AC_MSG_RESULT(yes)
  ssldirs="$withval"
else
  AC_MSG_RESULT(no)
fi], 
       [
AC_MSG_RESULT(yes)
            # if pkg-config is installed and openssl has installed a .pc file,
            # then use that information and don't search ssldirs
            AC_PATH_PROG(PKG_CONFIG, pkg-config)
            if test x"$PKG_CONFIG" != x""; then
                OPENSSL_LDFLAGS=`$PKG_CONFIG openssl --libs-only-L 2>/dev/null`
                if test $? = 0; then
                    OPENSSL_LIBS=`$PKG_CONFIG openssl --libs-only-l 2>/dev/null`
                    OPENSSL_INCLUDES=`$PKG_CONFIG openssl --cflags-only-I 2>/dev/null`
                    found=true
                fi
            fi

            # no such luck; use some default ssldirs
            if ! $found; then
                ssldirs="/usr/local/ssl /usr/lib/ssl /usr/ssl /usr/pkg /usr/local /usr"
            fi
        ]
        )


    # note that we #include <openssl/foo.h>, so the OpenSSL headers have to be in
    # an 'openssl' subdirectory
if test "$withval" != no ; then

    if ! $found; then
        OPENSSL_INCLUDES=
        for ssldir in $ssldirs; do
            AC_MSG_CHECKING([for openssl/ssl.h in $ssldir])
            if test -f "$ssldir/include/openssl/ssl.h"; then
                OPENSSL_INCLUDES="-I$ssldir/include"
                OPENSSL_LDFLAGS="-L$ssldir/lib"
                OPENSSL_LIBS="-lssl -lcrypto"
                found=true
                AC_MSG_RESULT([yes])
                break
            else
                AC_MSG_RESULT([no])
            fi
        done

        # if the file wasn't found, well, go ahead and try the link anyway -- maybe
        # it will just work!
    fi

    # try the preprocessor and linker with our new flags,
    # being careful not to pollute the global LIBS, LDFLAGS, and CPPFLAGS

    AC_MSG_CHECKING([whether compiling and linking against OpenSSL works])
    echo "Trying link with OPENSSL_LDFLAGS=$OPENSSL_LDFLAGS;" \
        "OPENSSL_LIBS=$OPENSSL_LIBS; OPENSSL_INCLUDES=$OPENSSL_INCLUDES" >&AS_MESSAGE_LOG_FD

    save_LIBS="$LIBS"
    save_LDFLAGS="$LDFLAGS"
    save_CPPFLAGS="$CPPFLAGS"
    LDFLAGS="$LDFLAGS $OPENSSL_LDFLAGS"
    LIBS="$OPENSSL_LIBS $LIBS"
    CPPFLAGS="$OPENSSL_INCLUDES $CPPFLAGS"
    AC_LINK_IFELSE(
        AC_LANG_PROGRAM([#include <openssl/ssl.h>], [SSL_new(NULL)]),
        [
            AC_DEFINE(HAVE_LIBOPENSSL)
            AC_MSG_RESULT([yes])
            found_openssl=yes
        ], [
            AC_MSG_RESULT([no])
            CPPFLAGS="$save_CPPFLAGS"
            LDFLAGS="$save_LDFLAGS"
            LIBS="$save_LIBS"
        ])

fi
])