dnl
dnl Run a program, logging the command and output to just the log file.
dnl
AC_DEFUN([AX_RUN_PROG],
[
        _AS_ECHO_LOG([$1])
        $1 >&AS_MESSAGE_LOG_FD 2>&1
])

dnl
dnl Like AC_CHECK_SIZEOF(), but stop if the result is 0 (an error),
dnl rather than ploughing on pointlessly.
dnl
AC_DEFUN([AX_CHECK_SIZEOF],
[
        AC_CHECK_SIZEOF([$1])
        if test "$ac_cv_sizeof_$2" -eq 0; then
           AC_MSG_ERROR([Couldn't calculate sizeof($1) - can't compile without it.
See config.log for possible errors.])
        fi
])

dnl
dnl Check for -lnsl and -lsocket (needed on solaris).
dnl http://www.nongnu.org/autoconf-archive/ax_lib_socket_nsl.html
dnl
AC_DEFUN([AX_LIB_SOCKET_NSL],
[
        AC_SEARCH_LIBS(gethostbyname, nsl)
        AC_SEARCH_LIBS(socket, socket, [], [
                AC_CHECK_LIB(socket, socket, [LIBS="-lsocket -lnsl $LIBS"], [], [-lnsl])])
])

dnl
dnl A simple helper macro to start the check for a package or library,
dnl setting with_$1 to yes or no.
dnl
AC_DEFUN([AX_OPT_HEADER],
[
    AC_MSG_CHECKING([if $1 is wanted])
    m4_define([$0_T],m4_if([$2],,[$1],[$2]))dnl
    AC_ARG_WITH([$1],
    [AS_HELP_STRING([--with-$1], enable $0_T if available [(the default)])
AS_HELP_STRING([--without-$1], disable $0_T usage completely)],
    [
      if test "$withval" != "no"; then
         AC_MSG_RESULT(yes)
      else
         AC_MSG_RESULT(no)
      fi], 
    [
       with_$1=yes
       AC_MSG_RESULT(yes)
    ]
    )
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
  AC_CACHE_CHECK(for MSG_NOSIGNAL, ax_cv_flag_msg_nosignal,
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
                       DYNAMIC_LIB_LDFLAGS="-bundle -undefined suppress -flat_namespace"
                       ;;
              *solaris* )
                       case $CCVER in
                             *Sun\ C*)
                                   DYNAMIC_LIB_LDFLAGS="-G -Wl,-Bdirect"
                                   ;;
                             *)
                                   DYNAMIC_LIB_LDFLAGS="-shared -Wl,-Bdirect"
                                   ;;
                       esac
                       ;;
              *aix* )
                       case $CCVER in
                             *IBM\ XL*)
                                   DYNAMIC_LIB_LDFLAGS="-qmkshrobj -Wl,-G -Wl,-bsymbolic"
                                   ;;
                             *)
                                   DYNAMIC_LIB_LDFLAGS="-shared -Wl,-G -Wl,-bsymbolic"
                                   ;;
                       esac
                       ;;
              *)
                       case $CCVER in
                             *IBM\ XL*)
                                   DYNAMIC_LIB_LDFLAGS="-qmkshrobj -Wl,-Bsymbolic"
                                   ;;
                             *)
                                   DYNAMIC_LIB_LDFLAGS="-shared -Wl,-Bsymbolic"
                                   ;;
                       esac
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
                       DYNAMIC_EXPORT_LDFLAGS="-Wl,-brtl -Wl,-bexpall"
                       ;;
              *)
                       DYNAMIC_EXPORT_LDFLAGS="-Wl,-E"
                       ;;
           esac
        fi

        dnl Create a shared library, dloadtest.so, to use with this test.
        dnl If this fails, the main test will surely fail.
        rm -f ./dloadtest.so ./conftest.o ./conftest.c
        AC_LANG_CONFTEST(
           [AC_LANG_SOURCE([[extern int func1(int); 
                             extern int var1;
                             int func2() { return 5; }
                             int var2 = 7;
                             int func3(int x) { return 2*x*var1*var2*func2()*func1(20); }]])]
         )
        _AS_ECHO_LOG([Trying to create dloadtest.so (2 commands follow)])
        AX_RUN_PROG([$CC $CFLAGS $DYNAMIC_LIB_CFLAGS -c conftest.c -o conftest.o])
        AX_RUN_PROG([$CC $CFLAGS $DYNAMIC_LIB_LDFLAGS -o dloadtest.so conftest.o])
        rm -f ./conftest.o ./conftest.c

        dnl Now try to link a program with the shared library, and have each half call the other.
        my_save_ldflags="$LDFLAGS"
        LDFLAGS="$LDFLAGS $DYNAMIC_EXPORT_LDFLAGS"
        AC_RUN_IFELSE(
           [AC_LANG_SOURCE([[#include <dlfcn.h>
                             #include <stdlib.h>
                             /* Allow two results, depending on whether func2() in the library is overridden
                                (giving 19 not 5).  I have only found this to happen on macos, and even then
                                only if optimizations are off (-O0). */
                             #define RES1 1144066
                             #define RES2 301070
                             int func1(int x) { return 3+x; }
                             int func2() { return 19; }
                             int var1 = 11;
                             int var2 = 13;
                             int main() {
                                 void *handle;
                                 int i;
                                 int (*func3)(int);
                                 handle = dlopen("./dloadtest.so", RTLD_LAZY);
                                 if (!handle) exit(1);
                                 *(void **)(&func3) = dlsym(handle, "func3");
                                 if (!func3) exit(1);
                                 i = func3(17);
                                 if (i != RES1 && i != RES2) exit(1);
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
    AX_OPT_HEADER(cairo)
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
    AX_OPT_HEADER(openssl, OpenSSL)
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
    AX_OPT_HEADER(png)
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
    AX_OPT_HEADER(zlib)
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
    AX_OPT_HEADER(X11, [X11 graphics])
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
   AX_OPT_HEADER(jpeg)
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
    AX_OPT_HEADER(mysql, MySQL)
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


dnl This redefines the _AC_INIT_HELP macro, in order to remove unwanted and
dnl misleading messages, particularly about installation steps.  Apart from
dnl this macro, the help output is also altered by clearing the HELP_CANON and
dnl HELP_ENABLE diversions, at the bottom of configure.ac.
dnl 
m4_define([_AC_INIT_HELP],
[m4_divert_push([HELP_BEGIN])dnl

#
# Report the --help message.
#
if test "$ac_init_help" = "long"; then
  # Omit some internal or obsolete options to make the list less imposing.
  # This message is too long to be a string in the A/UX 3.1 sh.
  cat <<_ACEOF
\`configure' configures m4_ifset([AC_PACKAGE_STRING],
			[AC_PACKAGE_STRING],
			[this package]) to adapt to many kinds of systems.

Usage: $[0] [[OPTION]]... [[VAR=VALUE]]...

[To assign environment variables (e.g., CC, CFLAGS...), specify them as
VAR=VALUE.  See below for descriptions of some of the useful variables.

Defaults for the options are specified in brackets.

Configuration:
  -h, --help              display this help and exit
      --help=short        display options specific to this package
      --help=recursive    display the short help of all the included packages
  -V, --version           display version information and exit
  -q, --quiet, --silent   do not print \`checking ...' messages
      --cache-file=FILE   cache test results in FILE [disabled]
  -C, --config-cache      alias for \`--cache-file=config.cache'
  -n, --no-create         do not create output files
      --srcdir=DIR        find the sources in DIR [configure dir or \`..']

Please note that Object Icon runs from the directory you compile it in (there
is no make install step).][
_ACEOF

  cat <<\_ACEOF]
m4_divert_pop([HELP_BEGIN])dnl
dnl The order of the diversions here is
dnl - HELP_BEGIN
dnl   which may be extended by extra generic options such as with X or
dnl   AC_ARG_PROGRAM.  Displayed only in long --help.
dnl
dnl - HELP_CANON
dnl   Support for cross compilation (--build, --host and --target).
dnl   Display only in long --help.
dnl
dnl - HELP_ENABLE
dnl   which starts with the trailer of the HELP_BEGIN, HELP_CANON section,
dnl   then implements the header of the non generic options.
dnl
dnl - HELP_WITH
dnl
dnl - HELP_VAR
dnl
dnl - HELP_VAR_END
dnl
dnl - HELP_END
dnl   initialized below, in which we dump the trailer (handling of the
dnl   recursion for instance).
m4_divert_push([HELP_ENABLE])dnl
_ACEOF
fi

if test -n "$ac_init_help"; then
m4_ifset([AC_PACKAGE_STRING],
[  case $ac_init_help in
     short | recursive ) echo "Configuration of AC_PACKAGE_STRING:";;
   esac])
  cat <<\_ACEOF
m4_divert_pop([HELP_ENABLE])dnl
m4_divert_push([HELP_END])dnl

Report bugs to m4_ifset([AC_PACKAGE_BUGREPORT], [<AC_PACKAGE_BUGREPORT>],
  [the package provider]).dnl
m4_ifdef([AC_PACKAGE_NAME], [m4_ifset([AC_PACKAGE_URL], [
AC_PACKAGE_NAME home page: <AC_PACKAGE_URL>.])dnl
m4_if(m4_index(m4_defn([AC_PACKAGE_NAME]), [GNU ]), [0], [
General help using GNU software: <http://www.gnu.org/gethelp/>.])])
_ACEOF
ac_status=$?
fi

if test "$ac_init_help" = "recursive"; then
  # If there are subdirs, report their specific --help.
  for ac_dir in : $ac_subdirs_all; do test "x$ac_dir" = x: && continue
    test -d "$ac_dir" ||
      { cd "$srcdir" && ac_pwd=`pwd` && srcdir=. && test -d "$ac_dir"; } ||
      continue
    _AC_SRCDIRS(["$ac_dir"])
    cd "$ac_dir" || { ac_status=$?; continue; }
    # Check for guested configure.
    if test -f "$ac_srcdir/configure.gnu"; then
      echo &&
      $SHELL "$ac_srcdir/configure.gnu" --help=recursive
    elif test -f "$ac_srcdir/configure"; then
      echo &&
      $SHELL "$ac_srcdir/configure" --help=recursive
    else
      AC_MSG_WARN([no configuration information is in $ac_dir])
    fi || ac_status=$?
    cd "$ac_pwd" || { ac_status=$?; break; }
  done
fi

test -n "$ac_init_help" && exit $ac_status
m4_divert_pop([HELP_END])dnl
])# _AC_INIT_HELP
