AC_INIT([Object Icon],[1.3],[r.parlett@gmail.com],[objecticon])

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
CONFIG_DIR=$(pwd)

AC_SUBST([CONFIG_DATE])
CONFIG_DATE=$(date)

AC_CONFIG_SRCDIR([base/oix/imain.r])

CHECK_XLIB()
if test "$ac_cv_lib_X11_main" == yes; then
   CHECK_FREETYPE()
   CHECK_JPEG()
   CHECK_XFT()
   CHECK_XPM()
   if test "$ac_cv_lib_Xft_main" == yes -a "$ac_cv_lib_freetype_main" != yes ; then
        AC_MSG_ERROR([*** Xft needs freetype to work])
   fi
fi
CHECK_ZLIB()
OI_ADD_LIB(m)
if ! test "$ac_cv_lib_m_main" == yes; then
        AC_MSG_ERROR([*** Couldn't find the math library (-lm) - can't compile without it.])
fi
OI_ADD_LIB(dl)

AX_LIB_MYSQL()
AC_FLAG_MSG_NOSIGNAL()

AC_PROG_INSTALL()
AC_PROG_LN_S()
AC_PROG_MAKE_SET()

AC_CANONICAL_HOST()
case $host in
     i?86-*-linux*) id=linux_x86 ;;
     i?86-*-cygwin*) id=cygwin_x86 ;;
     *) id=default ;;
esac
export CSWITCH
CSWITCH=config/system/$id/rswitch.?

AC_CHECK_FUNCS(gethostent getrlimit setrlimit strerror vfork poll)
AC_CHECK_GLOBAL(sys_nerr)
AC_CHECK_GLOBAL(sys_errlist)
AC_VAR_TIMEZONE_EXTERNALS()
AC_STRUCT_TIMEZONE_GMTOFF()
CHECK_UNSETENV()

AC_CHECK_SIZEOF(int, 4)
AC_CHECK_SIZEOF(long, 4)
AC_CHECK_SIZEOF(void*, 4)

AC_CONFIG_COMMANDS(system, [
        cp $CSWITCH base/oix
	AS_MKDIR_P(bin)
])
AC_CONFIG_FILES([Makedefs:config/files/Makedefs],)
AC_CONFIG_FILES([test/Makefile:config/files/test/Makefile],)
AC_CONFIG_FILES([apps/ivib/plugins/Makefile:config/files/apps/ivib/plugins/Makefile])
AC_CONFIG_FILES([apps/ivib/Makefile:config/files/apps/ivib/Makefile])
AC_CONFIG_FILES([apps/oidoc/Makefile:config/files/apps/oidoc/Makefile])
AC_CONFIG_FILES([apps/Makefile:config/files/apps/Makefile])
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
AC_CONFIG_FILES([base/Makefile:config/files/base/Makefile])
AC_CONFIG_FILES([Makefile:config/files/Makefile])
AC_CONFIG_FILES([paths.sh:config/files/paths.sh])
AC_CONFIG_FILES([base/h/version.h:config/files/base/h/version.h],)
AC_CONFIG_FILES([base/h/define.h:config/files/base/h/define.h],)
AC_CONFIG_HEADERS([base/h/auto.h:config/files/base/h/auto.h],)
AC_OUTPUT
echo "Summary:-"
echo    "Installation prefix    :" $prefix
echo -n "X11 graphics           : "
if test "$ac_cv_lib_X11_main" == yes; then
        echo yes
        echo -n "jpeg library           : "
        if test "$ac_cv_lib_jpeg_main" == yes; then
                echo yes
        else
                echo no
        fi
        echo -n "Xft anti-aliased fonts : "
        if test "$ac_cv_lib_Xft_main" == yes; then
                echo yes
        else
                echo no
        fi
        echo -n "Xpm                    : "
        if test "$ac_cv_lib_Xpm_main" == yes; then
                echo yes
        else
                echo no
        fi
else
        echo no
fi
echo -n "zlib compression       : "
if test "$ac_cv_lib_z_main" == yes; then
        echo yes
else
        echo no
fi
echo -n "dynamic loading        : "
if test "$ac_cv_lib_dl_main" == yes; then
        echo yes
else
        echo no
fi
echo -n "mysql lib              : "
if test -z "$MYSQL_VERSION"; then
        echo no
else
        echo yes
fi
echo "context switch         :" $CSWITCH
