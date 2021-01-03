#include "../h/gsupport.h"

static char embed[] = "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
                      "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
                      "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$";

static char *find_oixloc(void)
{
    char *s;

    s = getenv_nn("OIX");
    if (s && !access(s, 0))
        return s;

    if (!access(embed, 0))
        return embed;

    return findexe("oix");
}

int main(void)
{
    char *oixloc;
    STARTUPINFOW si; 
    PROCESS_INFORMATION pi; 
    DWORD r;
    StructClear(si); 
    StructClear(pi); 
    si.cb = sizeof(si); 
    oixloc = find_oixloc();
    if (!oixloc) {
        fprintf(stderr, "Couldn't find oix on PATH\n");
        exit(EXIT_FAILURE);
    }

    if (!CreateProcessW(utf8_to_wchar(oixloc), GetCommandLineW(),
                        NULL, NULL, TRUE, 0, NULL, NULL, 
                        &si, &pi)) {
      fprintf(stderr, "CreateProcess failed GetLastError=%d\n", GetLastError());
      exit(EXIT_FAILURE);
   }
   WaitForSingleObject(pi.hProcess, INFINITE);
   r = 0;
   GetExitCodeProcess(pi.hProcess, &r);
   CloseHandle(pi.hProcess);
   CloseHandle(pi.hThread);
   return r;
}
