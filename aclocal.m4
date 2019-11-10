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

AC_DEFUN([AX_STRUCT_TIMEZONE_GMTOFF],
[
  AC_CACHE_CHECK(for struct tm.tm_gmtoff, ax_cv_member_struct_tm_tm_gmtoff,
  [AC_TRY_COMPILE([#include <time.h>],[struct tm t; t.tm_gmtoff = 3600;],
        [ax_cv_member_struct_tm_tm_gmtoff=yes],
        [ax_cv_member_struct_tm_tm_gmtoff=no])])
  AC_CACHE_CHECK(for struct tm.tm_isdst, ax_cv_member_struct_tm_tm_isdst,
  [AC_TRY_COMPILE([#include <time.h>],[struct tm t; t.tm_isdst = 1;],
        [ax_cv_member_struct_tm_tm_isdst=yes],
        [ax_cv_member_struct_tm_tm_isdst=no])])
  if test "$ax_cv_member_struct_tm_tm_gmtoff" = yes; then
     AC_DEFINE(HAVE_STRUCT_TM_TM_GMTOFF)
  fi
  if test "$ax_cv_member_struct_tm_tm_isdst" = yes; then
     AC_DEFINE(HAVE_STRUCT_TM_TM_ISDST)
  fi
])

AC_DEFUN([AX_VAR_TIMEZONE_EXTERNALS],
[  
   AC_CACHE_CHECK(for timezone external, ax_cv_var_timezone,
   [  AC_TRY_LINK([#include <time.h>], [return (int)timezone;],
         ax_cv_var_timezone=yes,
         ax_cv_var_timezone=no)
   ])
   AC_CACHE_CHECK(for altzone external, ax_cv_var_altzone,
   [  AC_TRY_LINK([#include <time.h>], [return (int)altzone;],
         ax_cv_var_altzone=yes,
         ax_cv_var_altzone=no)
   ])
   AC_CACHE_CHECK(for daylight external, ax_cv_var_daylight,
   [  AC_TRY_LINK([#include <time.h>], [return (int)daylight;],
         ax_cv_var_daylight=yes,
         ax_cv_var_daylight=no)
   ])
   AC_CACHE_CHECK(for tzname external, ax_cv_var_tzname,
   [  AC_TRY_LINK([#include <time.h>], [return (int)tzname;],
         ax_cv_var_tzname=yes,
         ax_cv_var_tzname=no)
   ])
   if test $ax_cv_var_timezone = yes; then
      AC_DEFINE(HAVE_TIMEZONE)
   fi
   if test $ax_cv_var_altzone = yes; then
      AC_DEFINE(HAVE_ALTZONE)
   fi
   if test $ax_cv_var_daylight = yes; then
      AC_DEFINE(HAVE_DAYLIGHT)
   fi
   if test $ax_cv_var_tzname = yes; then
      AC_DEFINE(HAVE_TZNAME)
   fi
])

AC_DEFUN([AX_CHECK_MSG_NOSIGNAL],
[
  AC_CACHE_CHECK(for MSG_NOSIGNAL,  ax_cv_flag_msg_nosignal,
     [AC_TRY_COMPILE([#include <sys/types.h>
                      #include <sys/socket.h>],[int flags = MSG_NOSIGNAL;],
        [ax_cv_flag_msg_nosignal=yes],
        [ax_cv_flag_msg_nosignal=no])])
   if test "$ax_cv_flag_msg_nosignal" = yes ; then
	AC_DEFINE(HAVE_MSG_NOSIGNAL)
   fi
])

AC_DEFUN([AX_CHECK_UNSETENV_RETURNS_INT],
[
   AC_CACHE_CHECK(if unsetenv returns int, ax_cv_flag_unsetenv_int_return,
      [AC_TRY_COMPILE([#include <stdlib.h>], [int x = unsetenv("dummy");],
         [ax_cv_flag_unsetenv_int_return=yes],
         [ax_cv_flag_unsetenv_int_return=no])])
   if test "$ax_cv_flag_unsetenv_int_return" = yes ; then
      AC_DEFINE(HAVE_UNSETENV_INT_RETURN)
   fi
])

AC_DEFUN([AX_CHECK_DOUBLE_HAS_WORD_ALIGNMENT],
[
   AC_CACHE_CHECK(if double has word alignment, ax_cv_flag_double_has_word_alignment,
   [AC_RUN_IFELSE([AC_LANG_PROGRAM([[
                     #include <stdio.h>
                     #include <stddef.h>]],[[
                        struct t { char x; double d; };
                        return (sizeof(double) % sizeof(void*) == 0 &&
                                offsetof(struct t, d) == sizeof(void *)) ? 0:1;
                     ]])],
                   [ax_cv_flag_double_has_word_alignment=yes],
                   [ax_cv_flag_double_has_word_alignment=no])])
   if test "$ax_cv_flag_double_has_word_alignment" = yes ; then
      AC_DEFINE(DOUBLE_HAS_WORD_ALIGNMENT)
   fi
])

AC_DEFUN([AX_CHECK_TIOCSCTTY],
[
   AC_CACHE_CHECK(if TIOCSCTTY is defined, ax_cv_flag_tiocsctty_is_defined,
   [AC_EGREP_CPP(yes,
                 [#include <sys/ioctl.h>
                  #ifdef TIOCSCTTY
                      yes
                  #endif],
                 [ax_cv_flag_tiocsctty_is_defined=yes],
                 [ax_cv_flag_tiocsctty_is_defined=no])])
   if test "$ax_cv_flag_tiocsctty_is_defined" = yes ; then
      AC_DEFINE(HAVE_TIOCSCTTY)
   fi
])

AC_DEFUN([AX_CHECK_NS_FILE_STAT],
[
   AC_CACHE_CHECK(for nanosecond file stat support, ax_cv_flag_have_ns_file_stat,
      [AC_TRY_COMPILE([#include <sys/types.h>
                       #include <sys/stat.h>
                       #include <unistd.h>],
                      [struct stat st;
                       st.st_mtim.tv_nsec = 0;],
         [ax_cv_flag_have_ns_file_stat=yes],
         [ax_cv_flag_have_ns_file_stat=no])])
   if test "$ax_cv_flag_have_ns_file_stat" = yes ; then
      AC_DEFINE(HAVE_NS_FILE_STAT)
   fi
])

AC_DEFUN([AX_CHECK_COMPUTED_GOTO],
[
   AC_CACHE_CHECK(for computed goto support, ax_cv_flag_have_computed_goto,
     [AC_TRY_COMPILE([],
         [ static void *labels[] = {&&label0, &&label1, &&label2};
           unsigned char *pc = 0;
           goto *labels[*pc];
           label0: ;
           label1: ;
           label2: ;
         ], 
         [ax_cv_flag_have_computed_goto=yes],
         [ax_cv_flag_have_computed_goto=no])])
   if test "$ax_cv_flag_have_computed_goto" = yes ; then
      AC_DEFINE(HAVE_COMPUTED_GOTO)
   fi
])

AC_DEFUN(AC_CHECK_GLOBALS,
[for ac_global in $1
do
   ac_tr_global=HAVE_`echo $ac_global | tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'`
   AC_MSG_CHECKING([for global variable ${ac_global}])
   AC_CACHE_VAL(ac_cv_global_$ac_global,
   [
    AC_TRY_LINK(
    [/* no includes */],
    [ extern long int $ac_global;  return (int)$ac_global; ],
    eval "ac_cv_global_${ac_global}=yes",
    eval "ac_cv_global_${ac_global}=no"
    )
   ]
   )
  if eval "test \"`echo '$ac_cv_global_'$ac_global`\" = yes"; then
    AC_MSG_RESULT(yes)
    AC_DEFINE_UNQUOTED($ac_tr_global)
  else
    AC_MSG_RESULT(no)
  fi
done
])

AC_DEFUN([AX_CHECK_DYNAMIC_LINKING],
   [ 
     dnl This shell variable has the same name as the #define value set below; it is used by configure.ac and the
     dnl lib/native Makefile
     unset HAVE_LIBDL
     dnl Save $LIBS since we won't want -ldl if we find we can't use dynamic linking
     my_save_libs=$LIBS
     AC_SEARCH_LIBS(dlopen, [dl dld], 
        [
        dnl library found, check that it resolves symbols correctly
        dnl
        AC_MSG_CHECKING(for symbol resolution)

        dnl Set default compiler options if not set externally
        if test -z "$DYNAMIC_LIB_CFLAGS" ; then
           dnl Flags for compiling source file which is part of a library
           case $host_os in
              *darwin* )
                       dnl No flag needed
                       ;;
              *)
                       DYNAMIC_LIB_CFLAGS="-fPIC"
                       ;;
           esac
        fi
        if test -z "$DYNAMIC_LIB_LDFLAGS" ; then
           dnl Flags for linking a library
           case $host_os in
              *darwin* )
                       DYNAMIC_LIB_LDFLAGS="-dynamiclib -undefined suppress -flat_namespace"
                       ;;
              *solaris* )
                       DYNAMIC_LIB_LDFLAGS="-shared -Wl,-Bdirect"
                       ;;
              *aix* )
                       DYNAMIC_LIB_LDFLAGS="-shared -Wl,-G -Wl,-bsymbolic"
                       ;;
              *)
                       DYNAMIC_LIB_LDFLAGS="-shared -Wl,-Bsymbolic"
                       ;;
           esac
        fi
        if test -z "$DYNAMIC_EXPORT_LDFLAGS" ; then
           dnl Flags for linking the main program so its symbols are accessible to a loaded library
           case $host_os in
              *solaris* )
                       dnl No flag needed
                       ;;
              *darwin* )
                       dnl No flag needed
                       ;;
              *aix* )
                       DYNAMIC_EXPORT_LDFLAGS="-Wl,-brtl -Wl,-bexpall "
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
                             extern int var1;
                             int func2() { return 5; }
                             int var2 = 7;
                             int func3(int x) { return 2*x*var1*var2*func2()*func1(20); }]])]
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
                             #if OS_DARWIN
                             /* On macos, func2() in the library is overridden (gives 19 not 5) */
                             #define RES 1144066
                             #else
                             #define RES 301070
                             #endif
                             int func1(int x) { return 3+x; }
                             int func2() { return 19; }
                             int var1 = 11;
                             int var2 = 13;
                             int main() {
                                 void *handle;
                                 int (*func3)(int);
                                 handle = dlopen("./dloadtest.so", RTLD_LAZY);
                                 if (!handle) exit(1);
                                 *(void **)(&func3) = dlsym(handle, "func3");
                                 if (!func3) exit(1);
                                 if (func3(17) != RES) exit(1);
                                 exit(0);
                             }
                             ]])],
                      [
                      AC_MSG_RESULT(yes)
                      AC_DEFINE(HAVE_LIBDL)
                      HAVE_LIBDL=yes
                      ],
                      [
                      AC_MSG_RESULT(no)
                      unset DYNAMIC_LIB_CFLAGS DYNAMIC_LIB_LDFLAGS DYNAMIC_EXPORT_LDFLAGS
                      LIBS=$my_save_libs
                      ]
   
        )
        LDFLAGS="$my_save_ldflags"
        rm -f ./dloadtest.so
     ],[
        dnl no lib dl found
        unset DYNAMIC_LIB_CFLAGS DYNAMIC_LIB_LDFLAGS DYNAMIC_EXPORT_LDFLAGS
     ])
     AC_SUBST(HAVE_LIBDL)
     AC_SUBST(DYNAMIC_LIB_CFLAGS)
     AC_SUBST(DYNAMIC_LIB_LDFLAGS)
     AC_SUBST(DYNAMIC_EXPORT_LDFLAGS)
])

AC_DEFUN([AX_CHECK_CAIRO],
[
    AC_MSG_CHECKING(if cairo is wanted)
    AC_ARG_WITH(cairo,
    [  --with-cairo to enable cairo if available (the default)
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
              AC_MSG_RESULT(no)
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
              OPENSSL_VERSION=`pkg-config --modversion $OPENSSL_CONFIG`
              AC_DEFINE(HAVE_LIBOPENSSL)
              AC_MSG_RESULT(yes)
           else
              AC_MSG_RESULT(no)
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

    unset found_png
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
              AC_MSG_RESULT(no)
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

    unset found_zlib
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
              AC_MSG_RESULT(no)
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

    unset found_x11
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
              AC_MSG_RESULT(no)
              PKGERR=`pkg-config --errors-to-stdout --print-errors $X11_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi
])

AC_DEFUN([AX_CHECK_JPEG],
[
    AC_MSG_CHECKING(if jpeg is wanted)
    AC_ARG_WITH(jpeg,
    [  --with-jpeg to enable jpeg usage if available (the default)
  --without-jpeg to disable jpeg usage completely],
   [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
   [
       with_jpeg=yes
       AC_MSG_RESULT(yes)
   ]
   )

   unset found_jpeg
   if test "$with_jpeg" != "no"; then
           JPEG_CONFIG="libjpeg"
           AC_MSG_CHECKING([for $JPEG_CONFIG])
           if pkg-config $JPEG_CONFIG; then
              CPPFLAGS="$CPPFLAGS `pkg-config --cflags $JPEG_CONFIG`"
              LDFLAGS="$LDFLAGS `pkg-config --libs-only-L $JPEG_CONFIG`"
              LIBS="$LIBS `pkg-config --libs-only-l $JPEG_CONFIG`"
              AC_DEFINE(HAVE_LIBJPEG)
              AC_MSG_RESULT(yes)
              found_jpeg=yes
           else
              AC_MSG_RESULT(no)
              PKGERR=`pkg-config --errors-to-stdout --print-errors $JPEG_CONFIG`
              AC_MSG_RESULT([$PKGERR])
           fi
    fi
])

AC_DEFUN([AX_LIB_MYSQL],
[
    AC_MSG_CHECKING(if mysql is wanted)
    AC_ARG_WITH(mysql,
    [  --with-mysql to enable MySQL if available (the default)
  --without-mysql to disable MySQL usage completely],
    [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
    [
       with_mysql=yes
       AC_MSG_RESULT(yes)
    ]
    )

    unset MYSQL_CPPFLAGS MYSQL_LDFLAGS MYSQL_VERSION MYSQL_LIBS
    if test "$with_mysql" != "no"; then
           MYSQL_CONFIG="mysqlclient >= 1.0"
           AC_MSG_CHECKING([for $MYSQL_CONFIG])
           if pkg-config $MYSQL_CONFIG; then
               MYSQL_CPPFLAGS="`pkg-config --cflags $MYSQL_CONFIG`"
               MYSQL_LDFLAGS="`pkg-config --libs-only-L $MYSQL_CONFIG`"
               MYSQL_LIBS=`pkg-config --libs-only-l $MYSQL_CONFIG`
               MYSQL_VERSION=`pkg-config --modversion $MYSQL_CONFIG`
               AC_DEFINE(HAVE_MYSQL)
               AC_MSG_RESULT(yes)
           else
               AC_MSG_RESULT(no)
               PKGERR=`pkg-config --errors-to-stdout --print-errors $MYSQL_CONFIG`
               AC_MSG_RESULT([$PKGERR])
           fi
    fi

    AC_SUBST(MYSQL_VERSION)
    AC_SUBST(MYSQL_CPPFLAGS)
    AC_SUBST(MYSQL_LDFLAGS)
    AC_SUBST(MYSQL_LIBS)
])
