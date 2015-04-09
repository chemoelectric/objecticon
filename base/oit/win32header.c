#include "../h/gsupport.h"

int main(void)
{
    char *oixloc;
    STARTUPINFOA siStartupInfo; 
    PROCESS_INFORMATION piProcessInfo; 
    memset(&siStartupInfo, 0, sizeof(siStartupInfo)); 
    memset(&piProcessInfo, 0, sizeof(piProcessInfo)); 
    siStartupInfo.cb = sizeof(siStartupInfo); 
    oixloc = getenv("OIX");
    if (!oixloc) {
        oixloc = findexe("oix");
        if (!oixloc) {
            fprintf(stderr, "Couldn't find oix on PATH");
            exit(1);
        }
    }
   if (!CreateProcess(oixloc, GetCommandLine(), NULL, NULL, TRUE, 0, NULL, NULL, 
		      &siStartupInfo, &piProcessInfo)) {
      fprintf(stderr, "CreateProcess failed GetLastError=%d\n",GetLastError());
      exit(1);
   }
   WaitForSingleObject(piProcessInfo.hProcess, INFINITE);
   CloseHandle( piProcessInfo.hProcess );
   CloseHandle( piProcessInfo.hThread );
   return 0;
}
