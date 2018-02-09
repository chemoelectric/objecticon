/*
 * version.h -- version identification
 */

#undef Version
#undef UVersion
#undef IVersion

/*
 *  Icon version number and date.
 *  These are the only two entries that change any more.
 */
#define VersionNumber "@PACKAGE_VERSION@"
#define VersionDate "@CONFIG_DATE@"

/*
 *  &version
 */
#define Version  "Object Icon Version " VersionNumber ".  " VersionDate
   
/*
 * Version numbers to be sure ucode is compatible with the linker
 * and icode is compatible with the run-time system.
 */
   
#define UVersion "U2.0.126"
#define IVersion "I2.0.126"
