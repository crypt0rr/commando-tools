//===============================================================================================//
// This is a stub for the actuall functionality of the DLL.
//===============================================================================================//
#include "ReflectiveLoader.h"

// Note: REFLECTIVEDLLINJECTION_VIA_LOADREMOTELIBRARYR and REFLECTIVEDLLINJECTION_CUSTOM_DLLMAIN are
// defined in the project properties (Properties->C++->Preprocessor) so as we can specify our own 
// DllMain and use the LoadRemoteLibraryR() API to inject this DLL.

// You can use this value as a pseudo hinstDLL value (defined and set via ReflectiveLoader.c)
extern HINSTANCE hAppInstance;
//===============================================================================================//

#include <stdio.h>

#pragma comment(lib, "ntdll.lib")

/* It's actually NTSTATUS, not LONG return */
typedef LONG (NTAPI * NtContinue_t)(PCONTEXT /* ctx */, BOOLEAN /* removealert */);

VOID WINAPI SomePayloadFunction()
{
	MessageBoxA(NULL, "Main payload!", "Reflective Restore", MB_OK);
}

BOOL WINAPI DllMain( HINSTANCE hinstDLL, DWORD dwReason, LPVOID lpReserved )
{
    BOOL bReturnValue = TRUE;
	DWORD dwThreadId = 0;
	NtContinue_t pNtContinue;

	switch( dwReason )
    { 
		case DLL_QUERY_HMODULE:
			if( lpReserved != NULL )
				*(HMODULE *)lpReserved = hAppInstance;
			break;
		case DLL_PROCESS_ATTACH:
			hAppInstance = hinstDLL;
			
			// Optional: Create a thread with primary payload
			CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)SomePayloadFunction, NULL, 0, &dwThreadId);
	
			// we don't need to do this in x86, just x64 compiler is more strict
			pNtContinue = (NtContinue_t)GetProcAddress(LoadLibraryA("ntdll.dll"), "NtContinue");

			// Restore the stolen thread execution
			if (!pNtContinue)
			{
				MessageBoxA(NULL, "NtContinue() not found!", "Reflective Restore", MB_OK);
				return FALSE;
			}
			
			pNtContinue((PCONTEXT)lpReserved, FALSE);
			
			// dead code path, if you get here restoration failed horribly!
			MessageBoxA(NULL, "NtContinue() failed", "Reflective Restore", MB_OK);
	
			break;
		case DLL_PROCESS_DETACH:
		case DLL_THREAD_ATTACH:
		case DLL_THREAD_DETACH:
            break;
    }
	return bReturnValue;
}