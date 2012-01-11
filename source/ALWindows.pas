unit ALWindows;

interface

uses Windows,
     sysutils;

type
  _ALMEMORYSTATUSEX = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: Int64;
    ullAvailPhys: Int64;
    ullTotalPageFile: Int64;
    ullAvailPageFile: Int64;
    ullTotalVirtual: Int64;
    ullAvailVirtual: Int64;
    ullAvailExtendedVirtual: Int64;
  end;
  TALMemoryStatusEx = _ALMEMORYSTATUSEX;

function ALGlobalMemoryStatusEx(var lpBuffer : TALMEMORYSTATUSEX): BOOL; stdcall;

Var ALGetTickCount64: function: int64; stdcall;

function ALInterlockedExchange64(var Target: LONGLONG; Value: LONGLONG): LONGLONG; stdcall;

const cALINVALID_SET_FILE_POINTER = DWORD(-1);

implementation

{*****************************************************************************}
function ALGlobalMemoryStatusEx; external kernel32 name 'GlobalMemoryStatusEx';
function ALInterlockedExchange64; external kernel32 name 'InterlockedExchange64';

{******************************************}
function ALGetTickCount64XP: int64; stdcall;
begin
  Result := GetTickCount;
end;

{***************************}
procedure ALInitWindowsFunct;
var kernel32: HModule;
begin
  // Kernel32 is always loaded already, so use GetModuleHandle
  // instead of LoadLibrary
  kernel32 := GetModuleHandle('kernel32');
  if kernel32 = 0 then RaiseLastOSError;
  @ALGetTickCount64 := GetProcAddress(kernel32, 'GetTickCount64');
  if not Assigned(ALGetTickCount64) then ALGetTickCount64 := ALGetTickCount64XP;
end;

initialization
  ALInitWindowsFunct;

end.
