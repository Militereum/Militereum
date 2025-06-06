unit common.win;

interface

uses
  // Delphi
  WinAPI.Windows;

function autoRunEnabled: Boolean;
procedure enableAutoRun;
procedure disableAutoRun;

function systemIsDarkMode: Boolean;
procedure enableDarkMode;
procedure disableDarkMode;

function appVersion: string;
function activateMainWindow: BOOL;

procedure initialize;
procedure finalize;

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.Win.Registry,
  WinAPI.Messages,
  // FireMonkey
  FMX.Platform.Win,
  FMX.Styles,
  // project
  common,
  main,
  thread;

function autoRunEnabled: Boolean;
begin
  const R = TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False) then
    try
      Result := R.ValueExists('Militereum');
      if Result then
      begin
        var S := R.ReadString('Militereum').TrimLeft(['"']);
        const I = S.LastIndexOf('"');
        if I >= Low(S) then S := S.Remove(I);
        Result := SameText(S, ParamStr(0));
      end;
      EXIT;
    finally
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
  Result := False;
end;

procedure enableAutoRun;
begin
  const R = TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False) then
    try
      R.WriteString('Militereum', System.SysUtils.Format('"%s" -autorun', [ParamStr(0)]));
    finally
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

procedure disableAutoRun;
begin
  const R = TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', False) then
    try
      R.DeleteValue('Militereum');
    finally
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

function systemIsDarkMode: Boolean;
begin
  const R = TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', False) then
    try
      Result := R.ReadInteger('AppsUseLightTheme') = 0;
      EXIT;
    finally
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
  Result := False;
end;

{$R 'assets\nero_win.res'}

procedure enableDarkMode;
begin
  TStyleManager.TrySetStyleFromResource('nero_win');
end;

procedure disableDarkMode;
begin
  TStyleManager.SetStyle(TStyleStreaming.LoadFromResource(hInstance, 'win10style', RT_RCDATA));
end;

function appVersion: string;
var
  major, minor, patch: Cardinal;
begin
  if GetProductVersion(ParamStr(0), major, minor, patch) then
    Result := System.SysUtils.Format('%d.%d.%d', [major, minor, patch])
  else
    Result := string.Empty;
end;

const
  CM_SHOW_MAIN_WINDOW    = WM_APP + 1;
  MessageWindowClassName = 'MilitereumMessageWindow';

type
  TMessageWindow = class
  public
    procedure WndProc(var Msg: TMessage);
  end;

procedure TMessageWindow.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = CM_SHOW_MAIN_WINDOW then
    thread.synchronize(procedure
    begin
      if Assigned(FrmMain) and not(FrmMain.Visible) then
      begin
        FrmMain.Show;
        const hWnd = FormToHWND(FrmMain);
        if hWnd <> 0 then
        begin
          var input: TInput;
          ZeroMemory(@input, SizeOf(input));
          SendInput(1, input, SizeOf(input));
          SetForegroundWindow(hWnd);
        end;
      end;
    end);
end;

function activateMainWindow: BOOL;
begin
  Result := FALSE;
  const msgWindow = WinAPI.Windows.FindWindow(PChar(MessageWindowClassName), nil);
  if msgWindow <> 0 then
    Result := PostMessage(msgWindow, CM_SHOW_MAIN_WINDOW, 0, 0);
end;

var
  appHook: HHOOK = 0;
  appWindow: HWND = 0;
  msgWindow: HWND = 0;
  aWindowClass: TWndClass = (
    style: 0;
    lpfnWndProc: @DefWindowProc;
    cbClsExtra: 0;
    cbWndExtra: 0;
    hInstance: 0;
    hIcon: 0;
    hCursor: 0;
    hbrBackground: 0;
    lpszMenuName: nil;
    lpszClassName: nil);

function allocateHwnd(const aClassName: string; const aMethod: TWndMethod): HWND;
begin
  aWindowClass.hInstance := HInstance;
  aWindowClass.lpszClassName := PChar(aClassName);
  var tempClass: TWndClass;
  const classRegistered = GetClassInfo(HInstance, aWindowClass.lpszClassName, tempClass);
  if not(classRegistered) or (tempClass.lpfnWndProc <> @DefWindowProc) then
  begin
    if classRegistered then WinAPI.Windows.UnregisterClass(aWindowClass.lpszClassName, HInstance);
    WinAPI.Windows.RegisterClass(aWindowClass);
  end;
  Result := CreateWindowEx(WS_EX_TOOLWINDOW, aWindowClass.lpszClassName, '', WS_POPUP, 0, 0, 0, 0, 0, 0, HInstance, nil);
  if Assigned(aMethod) then SetWindowLongPtr(Result, GWL_WNDPROC, IntPtr(MakeObjectInstance(aMethod)));
end;

function callWindowHook(Code: Integer; wparam: WPARAM; Msg: PCWPStruct): Longint; stdcall;
begin
  if Code = HC_ACTION then
    case Msg.message of
      WM_CREATE:
        if (appWindow = 0) and (PCREATESTRUCT(Msg.lParam)^.lpszClass = 'TFMAppClass') then
          appWindow := Msg.hwnd;
      $0287:
        if (Msg.lParam = WinAPI.Windows.LPARAM(appWindow)) and (Msg.wParam = 23) and not(common.Debug) then
          activateMainWindow;
    end;
  Result := CallNextHookEx(appHook, Code, WParam, WinAPI.Windows.LPARAM(Msg));
end;

procedure initialize;
begin
{$WARN SYMBOL_PLATFORM OFF}
  if FindCmdLineSwitch('autorun') then System.CmdShow := SW_SHOWMINNOACTIVE;
{$WARN SYMBOL_PLATFORM ON}
  msgWindow := allocateHwnd(MessageWindowClassName, TMessageWindow.Create.WndProc);
  appHook := SetWindowsHookEx(WH_CALLWNDPROC, @callWindowHook, 0, GetCurrentThreadId);
end;

procedure finalize;
begin
  if appHook <> 0 then UnhookWindowsHookEx(appHook);
  if msgWindow <> 0 then DeallocateHwnd(msgWindow);
end;

end.
