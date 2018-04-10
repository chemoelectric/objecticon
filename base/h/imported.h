/*
 * This file is included by rtt-generated C files when rtt is given
 * the -x option.  It is needed for loadable libraries which can't
 * access oix's symbols directly.
 */
static struct oisymbols *imported;

#define nulldesc (*(imported->nulldesc))
#define curpstate (*(imported->curpstate))
#define err_msg (*(imported->err_msg))

/* Called by oix when the library is first loaded */
#if MSWIN32
__declspec(dllexport)
#endif
void setimported(struct oisymbols *x)
{
    imported = x;
}
