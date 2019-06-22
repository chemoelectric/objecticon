AC_INIT([Object Icon],
        m4_esyscmd_s([svnversion | tr : -]),
        [2rparlett@gmail.com],
        [objecticon])

AC_GNU_SOURCE
AC_CANONICAL_HOST
case $host_os in
     *linux*)
        AC_DEFINE(OS_LINUX)
        ;;
     *solaris*)
        AC_DEFINE(OS_SOLARIS)
        ;;
     *aix*)
        AC_DEFINE(OS_AIX)
        ;;
     *bsd*)
        AC_DEFINE(OS_BSD)
        ;;
     *darwin*)
        AC_DEFINE(OS_DARWIN)
        ;;
     *cygwin*)
        AC_DEFINE(OS_CYGWIN)
        ;;
esac


AC_DEFUN([OI_ADD_LIB],[
 AC_CHECK_LIB($1,main)
])

AC_DEFUN([OI_ADD_LIB_DIR],[
  if test "$1" != "/usr/lib" -a -d "$1"; then
    LDFLAGS="$LDFLAGS -L$1"
  fi
])

AC_DEFUN([OI_ADD_INCLUDE_DIR],[
  if test "$1" != "/usr/include" -a -d "$1"; then
    CPPFLAGS="$CPPFLAGS -I$1"
  fi
])

AC_SUBST([CONFIG_DIR])
CONFIG_DIR=$(pwd -P)

AC_SUBST([CONFIG_DATE])
CONFIG_DATE=$(date)

AC_CONFIG_SRCDIR([base/oix/init.r])

AC_PROG_CC
dnl Needed by ancient autoconf for AC_EGREP_CPP to work
AC_PROG_EGREP

CCVER=`$CC --version`
case $CCVER in
    gcc*) CFLAGS="$CFLAGS -Wall -fno-strict-aliasing -Wno-deprecated-declarations" ;;
    pcc*) CFLAGS="$CFLAGS -Wall" ;;
    *clang*) CFLAGS="$CFLAGS -Wall -Wno-unused-const-variable -Wno-parentheses-equality -Wno-tautological-compare -Wno-deprecated-declarations" ;;
esac

AX_LIB_SOCKET_NSL()

AX_CHECK_DYNAMIC_LINKING()

AX_CHECK_X11()
if test "$found_x11" = yes; then
   AX_CHECK_JPEG()
   AX_CHECK_PNG()
   if test "$HAVE_DYNAMIC_LINKING" = yes; then
      AX_CHECK_CAIRO()
   fi
fi

AX_CHECK_TIOCSCTTY()

AX_CHECK_ZLIB()
OI_ADD_LIB(m)
if ! test "$ac_cv_lib_m_main" = yes; then
        AC_MSG_ERROR([*** Couldn't find the math library (-lm) - can't compile without it.])
fi

if test "$HAVE_DYNAMIC_LINKING" = yes; then
   AX_LIB_MYSQL()
   AX_CHECK_OPENSSL()
fi

AC_PROG_LN_S()
AC_PROG_MAKE_SET()

AC_SYS_LARGEFILE()
if test "$enable_largefile" != no; then
        if test "$ac_cv_sys_file_offset_bits" = "64"; then
                CPPFLAGS="$CPPFLAGS -D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE=1"
        fi
        if test "$ac_cv_sys_large_files" = "1"; then
                CPPFLAGS="$CPPFLAGS -D_LARGE_FILES=1"
        fi
fi

AC_FUNC_ALLOCA()
AC_CHECK_FUNCS(gethostent getrlimit setrlimit strerror vfork poll mmap uname truncate pread pwrite utimensat futimens)
AC_CHECK_GLOBALS(sys_nerr sys_errlist _etext)
AX_VAR_TIMEZONE_EXTERNALS()
AC_STRUCT_TIMEZONE()
AX_STRUCT_TIMEZONE_GMTOFF()
AC_CYGWIN()
AC_SUBST([CYGWIN])
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(void*)
AC_CHECK_SIZEOF(double)
AC_CHECK_SIZEOF(long long)

AX_CHECK_UNSETENV_RETURNS_INT()
AX_CHECK_DOUBLE_HAS_WORD_ALIGNMENT()
AX_CHECK_COMPUTED_GOTO()
AX_CHECK_NS_FILE_STAT()
AX_CHECK_MSG_NOSIGNAL()

AC_CONFIG_COMMANDS(system, [
	AS_MKDIR_P(bin)
	AS_MKDIR_P(examples/bin)
])

AC_CONFIG_FILES([Makedefs:config/files/Makedefs])
AC_CONFIG_FILES([apps/ivib/plugins/Makefile:config/files/apps/ivib/plugins/Makefile])
AC_CONFIG_FILES([apps/ivib/Makefile:config/files/apps/ivib/Makefile])
AC_CONFIG_FILES([apps/oidoc/Makefile:config/files/apps/oidoc/Makefile])
AC_CONFIG_FILES([apps/Makefile:config/files/apps/Makefile])
AC_CONFIG_FILES([examples/Makefile:config/files/examples/Makefile])
AC_CONFIG_FILES([lib/xml/Makefile:config/files/lib/xml/Makefile])
AC_CONFIG_FILES([lib/gui/Makefile:config/files/lib/gui/Makefile])
AC_CONFIG_FILES([lib/main/Makefile:config/files/lib/main/Makefile])
AC_CONFIG_FILES([lib/ipl/Makefile:config/files/lib/ipl/Makefile])
AC_CONFIG_FILES([lib/native/Makefile:config/files/lib/native/Makefile])
AC_CONFIG_FILES([lib/iyacc/test/Makefile:config/files/lib/iyacc/test/Makefile])
AC_CONFIG_FILES([lib/iyacc/Makefile:config/files/lib/iyacc/Makefile])
AC_CONFIG_FILES([lib/incl/Makefile:config/files/lib/incl/Makefile])
AC_CONFIG_FILES([lib/parser/Makefile:config/files/lib/parser/Makefile])
AC_CONFIG_FILES([lib/Makefile:config/files/lib/Makefile])
AC_CONFIG_FILES([base/common/Makefile:config/files/base/common/Makefile])
AC_CONFIG_FILES([base/rtt/Makefile:config/files/base/rtt/Makefile])
AC_CONFIG_FILES([base/oit/Makefile:config/files/base/oit/Makefile])
AC_CONFIG_FILES([base/oix/Makefile:config/files/base/oix/Makefile])
AC_CONFIG_FILES([base/h/Makefile:config/files/base/h/Makefile])
AC_CONFIG_FILES([base/Makefile:config/files/base/Makefile])
AC_CONFIG_FILES([Makefile:config/files/Makefile])
AC_CONFIG_FILES([paths.sh:config/files/paths.sh])
AC_CONFIG_FILES([base/h/version.h:config/files/base/h/version.h])
if test -f base/h/define.h ; then
echo base/h/define.h already exists and is left untouched
else
AC_CONFIG_FILES([base/h/define.h:config/files/base/h/define.h])
fi
AC_CONFIG_HEADERS([base/h/auto.h:config/files/base/h/auto.h])
AC_OUTPUT
echo "Summary:-"
if test "$found_x11" = yes; then
        echo "X11 graphics           : yes"
        if test "$ac_cv_lib_jpeg_main" = yes; then
                echo "jpeg library           : yes"
        else
                echo "jpeg library           : no"
        fi
        if test -z "$found_png"; then
                echo "png library            : no"
        else
                echo "png library            : yes"
        fi
else
        echo "X11 graphics           : no"
fi
if test "$found_zlib" = yes; then
        echo "zlib compression       : yes"
else
        echo "zlib compression       : no"
fi
if test "$HAVE_DYNAMIC_LINKING" = yes; then
        echo "dynamic linking        : yes"
        if test -z "$MYSQL_VERSION"; then 
                echo "mysql lib              : no"
        else
                echo "mysql lib              : yes"
        fi
        if test -z "$CAIRO_VERSION"; then
                echo "cairo lib              : no"
        else
                echo "cairo lib              : yes"
        fi
        if test -z "$OPENSSL_VERSION"; then
                echo "ssl lib                : no"
        else
                echo "ssl lib                : yes"
        fi
else
        echo "dynamic linking        : no"
fi
echo
echo "When reconfiguring, please remember to run 'make clean' before 'make'."
