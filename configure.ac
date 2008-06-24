AC_INIT([Object Icon],[1.0],[r.parlett@gmail.com],[objecticon])

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

AC_CONFIG_SRCDIR([base/oiconx/imain.r])

CHECK_XLIB()
if test "$ac_cv_lib_X11_main" == yes; then
   CHECK_FREETYPE()
   CHECK_JPEG()
   CHECK_XFT()
   CHECK_XPM()
   if test "$ac_cv_lib_Xft_main" == yes -a "$ac_cv_lib_freetype_main" != yes ; then
        echo "*** Xft needs freetype to work"
        exit 1
   fi
fi
CHECK_ZLIB()
OI_ADD_LIB(m)
if ! test "$ac_cv_lib_m_main" == yes; then
        echo "*** Couldn't find the math library (-lm) - can't compile without it."
        exit 1
fi
OI_ADD_LIB(crypt)
OI_ADD_LIB(dl)

AX_LIB_MYSQL()
AC_CHECK_FUNCS(getrlimit setrlimit strerror vfork)
AC_CHECK_GLOBAL(sys_nerr)
AC_CHECK_GLOBAL(sys_errlist)
AC_VAR_TIMEZONE_EXTERNALS()
AC_STRUCT_TIMEZONE()
AC_CONFIG_COMMANDS(system, [
        case $(uname -om) in
                'i686 GNU/Linux') id=linux_x86 ;;
                *) id=default ;;
        esac
        cp config/system/$id/rswitch.? base/common
	mkdir -p bin
])
AC_CONFIG_FILES([Makedefs:config/files/Makedefs],)
AC_CONFIG_FILES([docs/Makefile:config/files/docs/Makefile])
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
AC_CONFIG_FILES([lib/parser/Makefile:config/files/lib/parser/Makefile])
AC_CONFIG_FILES([lib/Makefile:config/files/lib/Makefile])
AC_CONFIG_FILES([base/common/Makefile:config/files/base/common/Makefile])
AC_CONFIG_FILES([base/rtt/Makefile:config/files/base/rtt/Makefile])
AC_CONFIG_FILES([base/oicont/Makefile:config/files/base/oicont/Makefile])
AC_CONFIG_FILES([base/oiconx/Makefile:config/files/base/oiconx/Makefile])
AC_CONFIG_FILES([base/Makefile:config/files/base/Makefile])
AC_CONFIG_FILES([Makefile:config/files/Makefile])
AC_CONFIG_FILES([base/h/version.h:config/files/base/h/version.h],)
AC_CONFIG_FILES([base/h/define.h:config/files/base/h/define.h],)
AC_CONFIG_HEADERS([base/h/auto.h:config/files/base/h/auto.h],)
AC_OUTPUT
echo "Summary:-"
echo -n "X11 graphics           :"
if test "$ac_cv_lib_X11_main" == yes; then
        echo yes
        echo -n "jpeg library           :"
        if test "$ac_cv_lib_jpeg_main" == yes; then
                echo yes
        else
                echo no
        fi
        echo -n "Xft anti-aliased fonts :"
        if test "$ac_cv_lib_Xft_main" == yes; then
                echo yes
        else
                echo no
        fi
        echo -n "Xpm                    :"
        if test "$ac_cv_lib_Xpm_main" == yes; then
                echo yes
        else
                echo no
        fi
else
        echo no
fi
echo -n "zlib compression       :"
if test "$ac_cv_lib_z_main" == yes; then
        echo yes
else
        echo no
fi
echo -n "dynamic loading        :"
if test "$ac_cv_lib_dl_main" == yes; then
        echo yes
else
        echo no
fi
echo -n "crypt lib              :"
if test "$ac_cv_lib_crypt_main" == yes; then
        echo yes
else
        echo no
fi
