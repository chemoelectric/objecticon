/*
 * version.h -- version identification
 */

/*
 *  Object Icon version number and date.
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
   
#define UVersion "U2.0.148"
#define IVersion "I2.0.148"


/*
 * This version number is used to ensure compatibility between the oix
 * executable and any dynamically loaded object files (.so or .dll).
 */
#define OixVersion 106
