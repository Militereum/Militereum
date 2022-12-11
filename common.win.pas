unit common.win;

interface

uses
  // Delphi
  WinAPI.Windows;

function activateMainWindow: BOOL;
procedure initialize;
procedure finalize;

implementation

uses
  // Delphi
  System.Classes,
  WinAPI.Messages,
  // project
  main;

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
    if Assigned(FrmMain) and not(FrmMain.Visible) then FrmMain.Show;
end;

function activateMainWindow: BOOL;
begin
  Result := FALSE;
  const msgWindow = FindWindow(PChar(MessageWindowClassName), nil);
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
        if (Msg.lParam = WinAPI.Windows.LPARAM(appWindow)) and (Msg.wParam = 23) then
          activateMainWindow;
    end;
  Result := CallNextHookEx(appHook, Code, WParam, WinAPI.Windows.LPARAM(Msg));
end;

procedure initialize;
begin
  msgWindow := allocateHwnd(MessageWindowClassName, TMessageWindow.Create.WndProc);
  appHook := SetWindowsHookEx(WH_CALLWNDPROC, @callWindowHook, 0, GetCurrentThreadId);
end;

procedure finalize;
begin
  if appHook <> 0 then UnhookWindowsHookEx(appHook);
  if msgWindow <> 0 then DeallocateHwnd(msgWindow);
end;

end.
