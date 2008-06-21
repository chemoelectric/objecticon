/*
 *  This is a dummy co-expression context switch that can be used in
 *  the absence of a working one.
 */  
#include "../h/rt.h"

int coswitch(word *old, word *new, int first)
{
    err_msg(401, NULL);
    return 0; /* Not reached */
}
