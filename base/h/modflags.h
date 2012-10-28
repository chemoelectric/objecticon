/*
 * Class field modifier flags.
 */
#define M_Method            01  /* method */
#define M_Private           02  /* private access */
#define M_Public            04  /* public access */
#define M_Protected        010  /* public access */
#define M_Package          020  /* public access */
#define M_Static           040  /* public access */
#define M_Const           0100  /* const variable */
#define M_Readable        0200  /* readable access */
#define M_Defer           0400  /* deferred method */
#define M_Final          01000  /* final class/method */
#define M_Special        02000  /* special method (new/init) */
#define M_Abstract       04000  /* abstract class/method */
#define M_Native        010000  /* native method */
