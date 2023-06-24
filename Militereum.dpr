program Militereum;

uses
  System.StartUpCopy,
  FMX.Forms,
{$IFDEF MACOS}
  common.mac in 'common.mac.pas',
  docker.mac in 'docker.mac.pas',
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  WinAPI.Windows,
  common.win in 'common.win.pas',
  docker.win in 'docker.win.pas',
{$ENDIF}
  airdrop in 'airdrop.pas' {FrmAirdrop},
  asset in 'asset.pas' {FrmAsset},
  base in 'base.pas' {FrmBase},
  checks in 'checks.pas',
  common in 'common.pas',
  docker in 'docker.pas' {FrmDocker},
  firsttime in 'firsttime.pas' {FrmFirstTime},
  honeypot in 'honeypot.pas' {FrmHoneypot},
  limit in 'limit.pas' {FrmLimit},
  log in 'log.pas' {FrmLog},
  main in 'main.pas' {FrmMain},
  sanctioned in 'sanctioned.pas' {FrmSanctioned},
  server in 'server.pas',
  spam in 'spam.pas' {FrmSpam},
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
