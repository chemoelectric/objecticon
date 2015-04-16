#include "../h/gsupport.h"

int mkstemp(char *path)
{
    return _open(_mktemp(path), _O_CREAT | _O_TRUNC | _O_WRONLY |_O_BINARY, _S_IREAD | _S_IWRITE);
}
