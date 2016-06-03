#include "../h/gsupport.h"

int main(void)
{
    char *oixloc;
    STARTUPINFOW siStartupInfo; 
    PROCESS_INFORMATION piProcessInfo; 
    memset(&siStartupInfo, 0, sizeof(siStartupInfo)); 
    memset(&piProcessInfo, 0, sizeof(piProcessInfo)); 
    siStartupInfo.cb = sizeof(siStartupInfo); 
    oixloc = getenv("OIX");
    if (!oixloc) {
        oixloc = findexe("oix");
        if (!oixloc) {
            fprintf(stderr, "Couldn't find oix on PATH\n");
            exit(EXIT_FAILURE);
        }
    }

    if (!CreateProcessW(utf8_to_wchar(oixloc), GetCommandLineW(), NULL, NULL, TRUE, 0, NULL, NULL, 
		      &siStartupInfo, &piProcessInfo)) {
      fprintf(stderr, "CreateProcess failed GetLastError=%d\n", GetLastError());
      exit(EXIT_FAILURE);
   }
   WaitForSingleObject(piProcessInfo.hProcess, INFINITE);
   CloseHandle( piProcessInfo.hProcess );
   CloseHandle( piProcessInfo.hThread );
   return 0;
}
