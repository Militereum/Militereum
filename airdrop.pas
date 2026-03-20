unit airdrop;

interface

uses
  // Delphi
  System.Classes, System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Menus,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  base, transaction;

type
  TFrmAirdrop = class(TFrmBase)
    lblTitle: TLabel;
    lblTokenText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblTokenTextClick(Sender: TObject);
  strict private
    FToken: TAddress;
    procedure SetAction(value: TTokenAction);
    procedure SetToken(value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Action: TTokenAction write SetAction;
    property Token: TAddress write SetToken;
  end;

procedure show(
  const action  : TTokenAction;
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const token   : TAddress;
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const action  : TTokenAction;
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const token   : TAddress;
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);
begin
  if whitelisted(TFrmAirdrop) or whitelisted(TFrmAirdrop, token) then
  begin
    allowed;
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmAirdrop = TFrmAirdrop.Create(chain, tx, callback, log);
    frmAirdrop.Action := action;
    frmAirdrop.Token  := token;
    frmAirdrop.Show;
  end);
end;

{-------------------------------- TFrmAirdrop ---------------------------------}

procedure TFrmAirdrop.SetAction(value: TTokenAction);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value]]);
end;

procedure TFrmAirdrop.SetToken(value: TAddress);
begin
  if value <> FToken then
  begin
    FToken := value;
    lblTokenText.Text := string(FToken);
    if not common.Demo then
      cache.getFriendlyName(Self.Chain, FToken, procedure(friendly: string; err: IError)
      begin
        if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
        begin
          lblTokenText.Text := friendly;
        end);
      end);
  end;
end;

function TFrmAirdrop.Bypass: TBypass;
begin
  Result := TBypass.Create('token', procedure
  begin
    whitelist(TFrmAirdrop, FToken);
  end);
end;

procedure TFrmAirdrop.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken))
end;

end.
