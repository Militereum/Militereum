program Militereum;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
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
  cache in 'cache.pas',
  censorable in 'censorable.pas' {FrmCensorable},
  checks in 'checks.pas',
  coingecko in 'coingecko.pas',
  common in 'common.pas',
  delegator in 'delegator.pas' {FrmDelegator},
  demo in 'demo.pas' {dmDemo: TDataModule},
  dextools in 'dextools.pas',
  docker in 'docker.pas' {FrmDocker},
  dormant in 'dormant.pas' {FrmDormant},
  error in 'error.pas',
  exploit in 'exploit.pas' {FrmExploit},
  firsttime in 'firsttime.pas' {FrmFirstTime},
  fundedBy in 'fundedBy.pas' {FrmFundedBy},
  honeypot in 'honeypot.pas' {FrmHoneypot},
  limit in 'limit.pas' {FrmLimit},
  log in 'log.pas' {FrmLog},
  lowDexScore in 'lowDexScore.pas' {FrmLowDexScore},
  main in 'main.pas' {FrmMain},
  mobula in 'mobula.pas',
  moralis in 'moralis.pas',
  noDexPair in 'noDexPair.pas' {FrmNoDexPair},
  pausable in 'pausable.pas' {FrmPausable},
  phisher in 'phisher.pas' {FrmPhisher},
  revoke in 'revoke.pas' {FrmRevoke},
  revoke.cash in 'revoke.cash.pas',
  sanctioned in 'sanctioned.pas' {FrmSanctioned},
  setApprovalForAll in 'setApprovalForAll.pas' {FrmSetApprovalForAll},
  server in 'server.pas',
  spam in 'spam.pas' {FrmSpam},
  thread in 'thread.pas',
  transaction in 'transaction.pas',
  unlock in 'unlock.pas' {FrmUnlock},
  unsupported in 'unsupported.pas' {FrmUnsupported},
  unverified in 'unverified.pas' {FrmUnverified},
  update in 'update.pas' {FrmUpdate},
  vault in 'vault.pas' {FrmVault},
  vaults.fyi in 'vaults.fyi.pas';

{$R *.res}

begin
  GlobalUseMetal := True;
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
  Application.CreateForm(TdmDemo, dmDemo);
  common.initialize;
  Application.Run;
  common.finalize;
{$IFDEF MSWINDOWS}
  if mutex <> 0 then CloseHandle(mutex);
{$ENDIF MSWINDOWS}
end.
