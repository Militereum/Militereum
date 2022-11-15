program Militereum;

uses
  System.StartUpCopy,
  FMX.Forms,
  main in 'main.pas' {FrmMain},
  server in 'server.pas',
  log in 'log.pas' {FrmLog},
  transaction in 'transaction.pas',
  approve in 'approve.pas' {FrmApprove},
  common in 'common.pas',
  thread in 'thread.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
