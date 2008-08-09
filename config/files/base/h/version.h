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
   
#define UVersion "U1.0.02"
   
#if IntBits == 16
     #define IVersion "I1.0.00/16"
#endif				/* IntBits == 16 */

#if IntBits == 32
    #define IVersion "I1.0.00/32"
#endif				/* IntBits == 32 */

#if IntBits == 64
     #define IVersion "I1.0.00/64"
#endif				/* IntBits == 64 */


/*
 * Version number for event monitoring.
 */
#define Eversion "1.0.00"
