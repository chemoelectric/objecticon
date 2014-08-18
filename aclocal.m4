#
# Check for -lnsl and -lsocket (needed on solaris).
# http://www.nongnu.org/autoconf-archive/ax_lib_socket_nsl.html
#
AC_DEFUN([AX_LIB_SOCKET_NSL],
[
        AC_SEARCH_LIBS([gethostbyname], [nsl])
        AC_SEARCH_LIBS([socket], [socket], [], [
                AC_CHECK_LIB([socket], [socket], [LIBS="-lsocket -lnsl $LIBS"], [], [-lnsl])])
])


AC_DEFUN([AX_CHECK_JPEG],
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
        JPEG_OLD_CPPFLAGS=$CPPFLAGS
        OI_ADD_LIB_DIR(${JPEG_HOME}/lib)
        OI_ADD_INCLUDE_DIR(${JPEG_HOME}/include)
        AC_CHECK_LIB(jpeg, jpeg_destroy_decompress, [jpeg_cv_libjpeg=yes], [jpeg_cv_libjpeg=no])
        AC_CHECK_HEADER(jpeglib.h, [jpeg_cv_jpeglib_h=yes], [jpeg_cv_jpeglib_h=no])
        AC_CHECK_HEADER(jerror.h, [jpeg_cv_jerror_h=yes], [jpeg_cv_jerror_h=no])
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

    unset MYSQL_CFLAGS MYSQL_LDFLAGS MYSQL_VERSION
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


AC_DEFUN([CHECK_DYNAMIC_LINKING],
   [ 
     dnl Save $LIBS since we won't want -ldl if we find we can't use dynamic linking
     my_save_libs=$LIBS
     AC_CHECK_LIB(dl,main)
     AC_MSG_CHECKING(for dynamic linking)

     dnl Set default compiler options if not set externally
     if test -z "$DYNAMIC_LIB_CFLAGS" ; then
        dnl Flags for compiling source file which is part of a library
        DYNAMIC_LIB_CFLAGS="-fPIC"
     fi
     if test -z "$DYNAMIC_LIB_LDFLAGS" ; then
        dnl Flags for linking a library
        DYNAMIC_LIB_LDFLAGS="-shared"
     fi
     if test -z "$DYNAMIC_EXPORT_LDFLAGS" ; then
        dnl Flags for linking the main program so its symbols are accessible to a loaded library
        case $host_os in
           solaris* )
                    dnl No flag needed
                    ;;
           *)
                    DYNAMIC_EXPORT_LDFLAGS="-Wl,-E"
                    ;;
        esac
     fi

     dnl Create a shared library, dloadtest.so, to use with this test.
     dnl If this fails, the main test will surely fail.
     rm -f ./dloadtest.so ./conftest.o
     AC_LANG_CONFTEST(
        [AC_LANG_SOURCE([[extern int func1(int); 
                          int func2(int x) { return 2*x*func1(3); }]])]
      )
     $ac_ct_CC -c $DYNAMIC_LIB_CFLAGS -o conftest.o conftest.c
     $ac_ct_CC $DYNAMIC_LIB_LDFLAGS -o dloadtest.so conftest.o
     rm -f ./conftest.o

     dnl Now try to link a program with the shared library, and have each half call the other.
     my_save_ldflags="$LDFLAGS"
     LDFLAGS="$LDFLAGS $DYNAMIC_EXPORT_LDFLAGS"
     AC_RUN_IFELSE(
        [AC_LANG_SOURCE([[#include <dlfcn.h>
                          #include <stdlib.h>
                          int func1(int x) { return 3*x; }
                          int main() {
                              void *handle;
                              int (*func2)(int);
                              handle = dlopen("./dloadtest.so", RTLD_LAZY);
                              if (!handle) exit(1);
                              *(void **)(&func2) = dlsym(handle, "func2");
                              if (!func2) exit(1);
                              if (func2(13) != 234) exit(1);
                              exit(0);
                          }
                          ]])],
                   [
                   AC_MSG_RESULT(yes)
                   HAVE_DYNAMIC_LINKING=yes
                   ],
                   [
                   AC_MSG_RESULT(no)
                   LIBS=$my_save_libs
                   HAVE_DYNAMIC_LINKING=no
                   DYNAMIC_LIB_CFLAGS=""
                   DYNAMIC_LIB_LDFLAGS=""
                   DYNAMIC_EXPORT_LDFLAGS=""
                   ]

     )
     LDFLAGS="$my_save_ldflags"
     rm -f ./dloadtest.so
     AC_SUBST(DYNAMIC_LIB_CFLAGS)
     AC_SUBST(DYNAMIC_LIB_LDFLAGS)
     AC_SUBST(DYNAMIC_EXPORT_LDFLAGS)
     AC_SUBST(HAVE_DYNAMIC_LINKING)
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





AC_DEFUN([AX_CHECK_CAIRO],
[
    AC_MSG_CHECKING(if cairo is wanted)
    AC_ARG_WITH(cairo,
[ --with-cairo to enable cairo if available (the default)
  --without-cairo to disable cairo usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_cairo=yes
       AC_MSG_RESULT(yes)
   ]
)
    unset CAIRO_VERSION CAIRO_CPPFLAGS CAIRO_LDFLAGS CAIRO_LIBS
    if test "$with_cairo" != "no"; then
           CAIRO_CONFIG="cairo >= 1.13 pangocairo >= 1.36 librsvg-2.0 >= 2.40"
           AC_MSG_CHECKING([for $CAIRO_CONFIG])
           if pkg-config $CAIRO_CONFIG; then
              CAIRO_CPPFLAGS=`pkg-config --cflags $CAIRO_CONFIG`
              CAIRO_LDFLAGS=`pkg-config --libs-only-L $CAIRO_CONFIG`
              CAIRO_LIBS=`pkg-config --libs-only-l $CAIRO_CONFIG`
              CAIRO_VERSION=`pkg-config --modversion cairo`
              AC_DEFINE(HAVE_LIBCAIRO)
              AC_MSG_RESULT(yes)
           else
              AC_MSG_RESULT([no])
              PKGERR=`pkg-config --errors-to-stdout --print-errors $CAIRO_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi

    AC_SUBST(CAIRO_VERSION)
    AC_SUBST(CAIRO_LDFLAGS)
    AC_SUBST(CAIRO_CPPFLAGS)
    AC_SUBST(CAIRO_LIBS)

])

AC_DEFUN([AX_CHECK_OPENSSL],
[
    AC_MSG_CHECKING(if OpenSSL is wanted)
    AC_ARG_WITH(openssl,
        [  --with-openssl to enable OpenSSL if available (the default)
  --without-openssl to disable OpenSSL usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_openssl=yes
       AC_MSG_RESULT(yes)
   ]
)
    unset OPENSSL_VERSION OPENSSL_CPPFLAGS OPENSSL_LDFLAGS OPENSSL_LIBS
    if test "$with_openssl" != "no"; then
           OPENSSL_CONFIG="openssl >= 1.0"
           AC_MSG_CHECKING([for $OPENSSL_CONFIG])
           if pkg-config $OPENSSL_CONFIG; then
              OPENSSL_CPPFLAGS=`pkg-config --cflags $OPENSSL_CONFIG`
              OPENSSL_LDFLAGS=`pkg-config --libs-only-L $OPENSSL_CONFIG`
              OPENSSL_LIBS=`pkg-config --libs-only-l $OPENSSL_CONFIG`
              OPENSSL_VERSION=`pkg-config --version $OPENSSL_CONFIG`
              AC_DEFINE(HAVE_LIBOPENSSL)
              AC_MSG_RESULT(yes)
           else
              AC_MSG_RESULT([no])
              PKGERR=`pkg-config --errors-to-stdout --print-errors $OPENSSL_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi

    AC_SUBST(OPENSSL_VERSION)
    AC_SUBST(OPENSSL_LDFLAGS)
    AC_SUBST(OPENSSL_CPPFLAGS)
    AC_SUBST(OPENSSL_LIBS)
])



AC_DEFUN([AX_CHECK_PNG],
[
    AC_MSG_CHECKING(if png is wanted)
    AC_ARG_WITH(png,
[  --with-png to enable png usage if available (the default)
  --without-png to disable png usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_png=yes
       AC_MSG_RESULT(yes)
   ]
)

    if test "$with_png" != "no"; then
           PNG_CONFIG="libpng >= 1.2.37"
           AC_MSG_CHECKING([for $PNG_CONFIG])
           if pkg-config $PNG_CONFIG; then
              CPPFLAGS="$CPPFLAGS `pkg-config --cflags $PNG_CONFIG`"
              LDFLAGS="$LDFLAGS `pkg-config --libs-only-L $PNG_CONFIG`"
              LIBS="$LIBS `pkg-config --libs-only-l $PNG_CONFIG`"
              AC_DEFINE(HAVE_LIBPNG)
              AC_MSG_RESULT(yes)
              found_png=yes
           else
              AC_MSG_RESULT([no])
              PKGERR=`pkg-config --errors-to-stdout --print-errors $PNG_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi
])


AC_DEFUN([AX_CHECK_ZLIB],
[
    AC_MSG_CHECKING(if zlib is wanted)
    AC_ARG_WITH(zlib,
[  --with-zlib to enable zlib usage if available (the default)
  --without-zlib to disable zlib usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_zlib=yes
       AC_MSG_RESULT(yes)
   ]
)

    if test "$with_zlib" != "no"; then
           ZLIB_CONFIG="zlib >= 1.2.7"
           AC_MSG_CHECKING([for $ZLIB_CONFIG])
           if pkg-config $ZLIB_CONFIG; then
              CPPFLAGS="$CPPFLAGS `pkg-config --cflags $ZLIB_CONFIG`"
              LDFLAGS="$LDFLAGS `pkg-config --libs-only-L $ZLIB_CONFIG`"
              LIBS="$LIBS `pkg-config --libs-only-l $ZLIB_CONFIG`"
              AC_DEFINE(HAVE_LIBZ)
              AC_MSG_RESULT(yes)
              found_zlib=yes
           else
              AC_MSG_RESULT([no])
              PKGERR=`pkg-config --errors-to-stdout --print-errors $ZLIB_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi
])




AC_DEFUN([AX_CHECK_X11],
[
    AC_MSG_CHECKING(if X11 graphics are wanted)
    AC_ARG_WITH(X11,
[  --with-X11 to enable X11 usage if available (the default)
  --without-X11 to disable X11 usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_X11=yes
       AC_MSG_RESULT(yes)
   ]
)

    if test "$with_X11" != "no"; then
           X11_CONFIG="x11 >= 1.5 xrender >= 0.9.7 xft >= 2.3.1 fontconfig >= 2.8.0 freetype2 >= 14.1.8"
           AC_MSG_CHECKING([for $X11_CONFIG])
           if pkg-config $X11_CONFIG; then
              CPPFLAGS="$CPPFLAGS `pkg-config --cflags $X11_CONFIG`"
              LDFLAGS="$LDFLAGS `pkg-config --libs-only-L $X11_CONFIG`"
              LIBS="$LIBS `pkg-config --libs-only-l $X11_CONFIG`"
              AC_DEFINE(HAVE_LIBX11)
              AC_MSG_RESULT(yes)
              found_x11=yes
           else
              AC_MSG_RESULT([no])
              PKGERR=`pkg-config --errors-to-stdout --print-errors $X11_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi
])
