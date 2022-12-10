program Militereum;

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF MSWINDOWS}
  System.Classes,
  WinAPI.Windows,
{$ENDIF}
  approve in 'approve.pas' {FrmApprove},
  common in 'common.pas',
  log in 'log.pas' {FrmLog},
  main in 'main.pas' {FrmMain},
  server in 'server.pas',
  thread in 'thread.pas',
  transaction in 'transaction.pas';

{$R *.res}

begin
  Application.Initialize;
{$IFDEF MSWINDOWS}
  var window: HWND;
  const MessageWindowClassName = 'MilitereumMessageWindow';
  const mutex = CreateMutex(nil, False, 'MilitereumMutex');
  if (mutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    window := FindWindow(PChar(MessageWindowClassName), nil);
    if window <> 0 then
      SendMessage(window, common.CM_SHOW, 0, 0);
    EXIT;
  end;
{$ENDIF}
  Application.CreateForm(TFrmMain, FrmMain);
{$IFDEF MSWINDOWS}
  window := common.allocateHwnd(MessageWindowClassName, FrmMain.MessageWindowProc);
{$ENDIF}
  Application.Run;
{$IFDEF MSWINDOWS}
  if window <> 0 then DeallocateHwnd(window);
  if mutex <> 0 then CloseHandle(mutex);
{$ENDIF}
end.
