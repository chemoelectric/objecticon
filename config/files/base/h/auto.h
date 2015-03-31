/* define's for zlib, jpeg, opengl, etc. */

/* define as 1 if using the GNU C library */
#undef _GNU_SOURCE

/* define as 1 if we have Zlib/libz/whatever */
#undef HAVE_LIBZ

/* define as 1 if we have jpeg */
#undef HAVE_LIBJPEG

/* define as 1 if we have png */
#undef HAVE_LIBPNG

/* define as 1 if we have dl */
#undef HAVE_LIBDL

/* define as 1 if we have getrlimit */
#undef HAVE_GETRLIMIT

/* define as 1 if we have setrlimit */
#undef HAVE_SETRLIMIT

/* define as 1 if we have a timezone variable */
#undef HAVE_TIMEZONE

/* define as 1 if we have a daylight variable */
#undef HAVE_DAYLIGHT

/* define as 1 if tzname exists */
#undef HAVE_TZNAME

/* define as 1 if struct tm has a tm_zone field */
#undef HAVE_STRUCT_TM_TM_ZONE

/* define as 1 if struct tm has a tm_gmtoff field */
#undef HAVE_STRUCT_TM_TM_GMTOFF

/* define as 1 if struct tm has a tm_isdst field */
#undef HAVE_STRUCT_TM_TM_ISDST

/* define as 1 if X11 is found */
#undef HAVE_LIBX11

/* define as 1 if strerror exists */
#undef HAVE_STRERROR

/* define as 1 if gethostent exists */
#undef HAVE_GETHOSTENT

/* define as 1 if vfork exists */
#undef HAVE_VFORK

/* define as 1 if sys_nerr exists */
#undef HAVE_SYS_NERR

/* define as 1 if sys_errlist exists */
#undef HAVE_SYS_ERRLIST

/* define as 1 if MSG_NOSIGNAL defined */
#undef HAVE_MSG_NOSIGNAL

/* define as 1 if poll exists */
#undef HAVE_POLL

/* define as 1 if uname exists */
#undef HAVE_UNAME

/* define as 1 if truncate exists */
#undef HAVE_TRUNCATE

/* define as 1 if alloca exists */
#undef HAVE_ALLOCA

/* define as 1 if _etext exists */
#undef HAVE__ETEXT

/* define as 1 if unsetenv exists and returns an int */
#undef HAVE_UNSETENV_INT_RETURN

/* define as 1 if we have computed gotos */
#undef HAVE_COMPUTED_GOTO

/* define as 1 if TIOCSCTTY is defined */
#undef HAVE_TIOCSCTTY

/* define as 1 if nanosecond file stat times are available */
#undef HAVE_NS_FILE_STAT

/* sizes of various fundamental types */
#undef SIZEOF_SHORT
#undef SIZEOF_INT
#undef SIZEOF_LONG
#undef SIZEOF_VOIDP
#undef SIZEOF_DOUBLE
#undef SIZEOF_LONG_LONG

/* double has word alignment test */
#undef DOUBLE_HAS_WORD_ALIGNMENT

/* O/S type */
#undef OS_LINUX
#undef OS_SOLARIS
#undef OS_AIX
#undef OS_BSD
#undef OS_DARWIN
#undef OS_CYGWIN
