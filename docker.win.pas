unit docker.win;

interface

function supported: Boolean;
function installed: Boolean;
function installer: string;
function running: Boolean;
function start: Boolean;
function pull(const image: string): Boolean;
function run(const name, command: string): Boolean;
function getContainerId(const name: string): string;
function stop(const containerId: string): Boolean;

implementation

uses
  // Delphi
  System.Character,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  WinAPI.ShellAPI,
  System.SysUtils,
  WinAPI.Windows,
  // Project
  common;

function supported: Boolean;
type
  TIsWow64Process = function(hProcess: THandle; var bWow64Process: BOOL): BOOL; stdcall;
begin
  Result := False;
  var IsWow64Process: TIsWow64Process;
  @IsWow64Process := GetProcAddress(GetModuleHandle(kernel32), 'IsWow64Process');
  if @IsWow64Process <> nil then
  begin
    var bWow64Process: BOOL;
    IsWow64Process(GetCurrentProcess(), bWow64Process);
    Result := bWow64Process;
  end;
end;

function getExitCode(const aFile, aParameters: string): Boolean;
begin
  var EI: TShellExecuteInfo;
  FillChar(EI, SizeOf(EI), 0);
  EI.cbSize       := SizeOf(EI);
  EI.fMask        := SEE_MASK_NOCLOSEPROCESS + SEE_MASK_FLAG_NO_UI;
  EI.lpVerb       := 'open';
  EI.lpFile       := PChar(aFile);
  EI.lpParameters := PChar(aParameters);
  EI.nShow        := SW_HIDE;
  Result := ShellExecuteEx(@EI);
  if Result then
  begin
    WaitForSingleObject(EI.hProcess, INFINITE);
    var exitCode: DWORD;
    GetExitCodeProcess(EI.hProcess, exitCode);
    Result := exitCode = 0;
  end;
end;

function getStdOutput(aCommandLine: string): string;
const
  BUFFER_SIZE = 4096;
var
  buffer: array[0..BUFFER_SIZE - 1] of AnsiChar;
begin
  Result := '';
  var SA: TSecurityAttributes;
  FillChar(SA, SizeOf(SA), 0);
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  var hRead, hWrite: THandle;
  if CreatePipe(hRead, hWrite, @SA, BUFFER_SIZE) then
  try
    // this structure specifies the StdInput and StdOutput handles for redirection.
    var SI: TStartUpInfo;
    FillChar(SI, SizeOf(SI), 0);
    SI.cb          := SizeOf(SI);
    SI.dwFlags     := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW; // the hStdInput, hStdOutput, hStdError, and wShowWindow members contain additional information.
    SI.hStdInput   := GetStdHandle(STD_INPUT_HANDLE);              // we're not redirecting StdInput; but we still have to give it a valid handle.
    SI.hStdOutput  := hWrite;                                      // we give the writeable handle to the pipe to the child process (please note we read from the readable handle)
    SI.hStdError   := GetStdHandle(STD_ERROR_HANDLE);              // we're not redirecting StdError; but we still have to give it a valid handle.
    SI.wShowWindow := SW_HIDE;
    // this structure receives identification information about the new process.
    var PI: TProcessInformation;
    FillChar(PI, SizeOf(PI), 0);
    // command line cannot be a pointer to read-only memory, or an access violation will occur.
    UniqueString(aCommandLine);
    const created = CreateProcess(nil, PChar(aCommandLine), nil, nil, True, NORMAL_PRIORITY_CLASS, nil, nil, SI, PI);
    // we don't need this handle any more, and keeping it open on this end will cause errors.
    CloseHandle(hWrite);
    if created then
    try
      var done := False;
      while not done do
      begin
        var bytesRead: DWORD;
        if not ReadFile(hRead, buffer, BUFFER_SIZE, bytesRead, nil) then
          done := GetLastError <> ERROR_IO_PENDING;
        if bytesRead > 0 then
          Result := Result + string(Copy(buffer, 0, bytesRead));
      end;
    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  finally
    CloseHandle(hRead);
  end;
end;

function installed: Boolean;
begin
  Result := getExitCode('docker', '--version');
  if Result then
  begin
    const ver = common.ParseSemVer(getStdOutput('docker --version'));
    const min = TSemVer.Create(24, 0, 2);
    Result := ver >= min;
  end;
end;

{$R 'assets\libeay32.res'}
{$R 'assets\ssleay32.res'}

function installer: string;
begin
  const libeay32 = TPath.GetDirectoryName(ParamStr(0)) + TPath.DirectorySeparatorChar + 'libeay32.dll';
  if not TFile.Exists(libeay32) then
  begin
    const RS = TResourceStream.Create(hInstance, 'libeay32', RT_RCDATA);
    try
      const FS = TFileStream.Create(libeay32, fmCreate);
      try
        FS.CopyFrom(RS, RS.Size);
      finally
        FS.Free;
      end;
    finally
      RS.Free;
    end;
  end;

  const ssleay32 = TPath.GetDirectoryName(ParamStr(0)) + TPath.DirectorySeparatorChar + 'ssleay32.dll';
  if not TFile.Exists(ssleay32) then
  begin
    const RS = TResourceStream.Create(hInstance, 'ssleay32', RT_RCDATA);
    try
      const FS = TFileStream.Create(ssleay32, fmCreate);
      try
        FS.CopyFrom(RS, RS.Size);
      finally
        FS.Free;
      end;
    finally
      RS.Free;
    end;
  end;

  Result := 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe';
end;

function running: Boolean;
begin
  Result := getExitCode('docker', 'ps');
end;

function start: Boolean;

  function desktop: string; inline;
  begin
    Result := GetEnvironmentVariable('ProgramW6432');
    if (Result <> '') and (Result[High(Result)] <> '\') then Result := Result + '\';
    Result := Result + 'Docker\Docker\Docker Desktop.exe';
  end;

begin
  Result := ShellExecute(0, 'open', PChar(desktop), nil, nil, SW_SHOW) > 32;
end;

function pull(const image: string): Boolean;
begin
  Result := getExitCode('docker', 'pull ' + image);
end;

function run(const name, command: string): Boolean;
begin
  Result := ShellExecute(0, 'open', 'docker', PChar('run --name ' + name + ' ' + command), nil, SW_HIDE) > 32;
end;

function ps: TDictionary<string, string>; // <container name, container id>
begin
  Result := nil;
  const rows = TStringList.Create;
  try
    rows.Text := getStdOutput('docker ps');
    if rows.Count > 1 then
    begin
      Result := TDictionary<string, string>.Create;
      for var R := 1 to Pred(rows.Count) do
      begin
        var C: Integer;
        // get the value (aka the docker container id)
        var V := rows[R];
        C := Low(V);
        while C <= High(V) do
          if not V[C].IsWhiteSpace then
            Inc(C)
          else
            Delete(V, C, Length(V) - C + 1);
        // get the key (aka the docker container name);
        var K := rows[R];
        C := Length(K);
        repeat
          Dec(C);
        until K[C].IsWhiteSpace;
        Delete(K, Low(K), C - Low(K) + 1);
        // add <name, id>
        Result.Add(K, V);
      end;
    end;
  finally
    rows.Free;
  end;
end;

function getContainerId(const name: string): string;
begin
  Result := '';
  const containers = ps;
  if Assigned(containers) then
  try
    var id: string;
    if containers.TryGetValue(name, id) then Result := id;
  finally
    containers.Free;
  end;
end;

function stop(const containerId: string): Boolean;
begin
  Result := getExitCode('docker', 'stop ' + containerId);
end;

end.
