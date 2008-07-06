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

AC_DEFUN([AC_VAR_TIMEZONE_EXTERNALS],
[  AC_REQUIRE([AC_STRUCT_TIMEZONE])dnl
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
    AC_ARG_WITH([mysql],
        AC_HELP_STRING([--with-mysql=@<:@ARG@:>@],
            [use MySQL client library @<:@default=yes@:>@, optionally specify path to mysql_config]
        ),
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
            AC_MSG_RESULT([no])
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
