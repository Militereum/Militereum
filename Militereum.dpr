program Militereum;

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF MACOS}
  common.mac in 'common.mac.pas',
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  WinAPI.Windows,
  common.win in 'common.win.pas',
{$ENDIF }
  approve in 'approve.pas' {FrmApprove},
  common in 'common.pas',
  limit in 'limit.pas' {FrmLimit},
  log in 'log.pas' {FrmLog},
  main in 'main.pas' {FrmMain},
  sanctioned in 'sanctioned.pas' {FrmSanctioned},
  server in 'server.pas',
  thread in 'thread.pas',
  transaction in 'transaction.pas',
  unverified in 'unverified.pas' {FrmUnverified};

{$R *.res}

begin
  Application.Initialize;
{$IFDEF MSWINDOWS}
  const mutex = CreateMutex(nil, False, 'MilitereumMutex');
  if (mutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    common.win.activateMainWindow;
    EXIT;
  end;
{$ENDIF MSWINDOWS}
  Application.CreateForm(TFrmMain, FrmMain);
  common.initialize;
  Application.Run;
  common.finalize;
{$IFDEF MSWINDOWS}
  if mutex <> 0 then CloseHandle(mutex);
{$ENDIF MSWINDOWS}
end.
