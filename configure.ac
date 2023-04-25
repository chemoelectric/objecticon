AC_INIT([Object Icon],[chemoelectric-development],,[objecticon])

AC_USE_SYSTEM_EXTENSIONS
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

AC_SUBST([CONFIG_DIR])
CONFIG_DIR=$(pwd -P)

AC_SUBST([CONFIG_DATE])
CONFIG_DATE=$(date)

AC_CONFIG_SRCDIR([base/oix/init.r])

AC_PROG_CC
dnl Needed by ancient autoconf for AC_EGREP_CPP to work
AC_PROG_EGREP

dnl Try to identify the C compiler
unset CCVER
for x in --version -v -V -qversion; do
    y=`$CC $x 2>&1`
    if test "$?" = 0; then
        CCVER=$y
        break
    fi
done
unset x
unset y

dnl Set compiler-specific flags
case $CCVER in
    gcc*) CFLAGS="$CFLAGS -Wall -fno-strict-aliasing -Wno-deprecated-declarations" ;;
    pcc*) CFLAGS="$CFLAGS -Wall" ;;
    *clang*) CFLAGS="$CFLAGS -Wall -Wno-unknown-warning-option -Wno-unused-const-variable -Wno-parentheses-equality -Wno-tautological-compare -Wno-deprecated-declarations -Wno-misleading-indentation" ;;
    *Sun\ C*) CFLAGS="$CFLAGS -errtags=yes -erroff=E_STATEMENT_NOT_REACHED -erroff=E_INVALID_CAST_EXPRESSION -erroff=E_ASSIGNMENT_TYPE_MISMATCH" ;;
    *IBM\ XL*) if test "$CFLAGS" = "-g -O2" ; then CFLAGS=-g ; fi
               CFLAGS="$CFLAGS -O0" ;;
esac

AX_LIB_SOCKET_NSL()

AX_CHECK_DYNAMIC_LINKING()

AX_CHECK_X11()
if test "$found_x11" = yes; then
   AX_CHECK_JPEG()
   AX_CHECK_PNG()
   if test "$HAVE_LIBDL" = yes; then
      AX_CHECK_CAIRO()
   fi
fi

AX_CHECK_TIOCSCTTY()

AX_CHECK_ZLIB()
AC_SEARCH_LIBS(sin, [m],,
   [
    AC_MSG_ERROR([Couldn't find the math library - can't compile without it.])
   ])

if test "$HAVE_LIBDL" = yes; then
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
AC_CHECK_FUNCS(gethostent getrlimit setrlimit strerror vfork mmap uname truncate pread pwrite utimensat futimens)
AC_CHECK_GLOBALS(sys_nerr sys_errlist _etext)
AC_CHECK_SIZEOF([clock_t], [], [[#include <time.h>]])
AX_VAR_TIMEZONE_EXTERNALS()
AC_STRUCT_TIMEZONE()
AX_STRUCT_TIMEZONE_GMTOFF()
AX_CHECK_SIZEOF(short, short)
AX_CHECK_SIZEOF(int, int)
AX_CHECK_SIZEOF(long, long)
AX_CHECK_SIZEOF(void*, voidp)
AX_CHECK_SIZEOF(double, double)
AX_CHECK_SIZEOF(long long, long_long)

AX_CHECK_UNSETENV_RETURNS_INT()
AX_CHECK_DOUBLE_HAS_WORD_ALIGNMENT()
AX_CHECK_COMPUTED_GOTO()
AX_CHECK_NS_FILE_STAT()
AX_CHECK_MSG_NOSIGNAL()
AX_CHECK_SYSV_IPC()

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
AC_MSG_NOTICE([base/h/define.h already exists and is left untouched])
else
AC_CONFIG_FILES([base/h/define.h:config/files/base/h/define.h])
fi
AC_CONFIG_HEADERS([base/h/auto.h:config/files/base/h/auto.h])
AC_OUTPUT
AC_MSG_NOTICE([Summary:-])
if test "$found_x11" = yes; then
        AC_MSG_NOTICE([X11 graphics           : yes])
        if test "$found_jpeg" = yes; then
                AC_MSG_NOTICE([jpeg library           : yes])
        else
                AC_MSG_NOTICE([jpeg library           : no])
        fi
        if test -z "$found_png"; then
                AC_MSG_NOTICE([png library            : no])
        else
                AC_MSG_NOTICE([png library            : yes])
        fi
else
        AC_MSG_NOTICE([X11 graphics           : no])
fi
if test "$found_zlib" = yes; then
        AC_MSG_NOTICE([zlib compression       : yes])
else
        AC_MSG_NOTICE([zlib compression       : no])
fi
if test "$HAVE_LIBDL" = yes; then
        AC_MSG_NOTICE([dynamic linking        : yes])
        if test -z "$HAVE_SYSV_IPC"; then 
                AC_MSG_NOTICE([sys v ipc lib          : no])
        else
                AC_MSG_NOTICE([sys v ipc lib          : yes])
        fi
        if test -z "$MYSQL_VERSION"; then 
                AC_MSG_NOTICE([mysql lib              : no])
        else
                AC_MSG_NOTICE([mysql lib              : yes])
        fi
        if test -z "$CAIRO_VERSION"; then
                AC_MSG_NOTICE([cairo lib              : no])
        else
                AC_MSG_NOTICE([cairo lib              : yes])
        fi
        if test -z "$OPENSSL_VERSION"; then
                AC_MSG_NOTICE([ssl lib                : no])
        else
                AC_MSG_NOTICE([ssl lib                : yes])
        fi
else
        AC_MSG_NOTICE([dynamic linking        : no])
fi
AC_MSG_NOTICE([When reconfiguring, please remember to run 'make clean' before 'make'.])
m4_cleardivert([HELP_CANON])dnl
m4_cleardivert([HELP_ENABLE])dnl
