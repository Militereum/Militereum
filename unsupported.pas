unit unsupported;

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
  TFrmUnsupported = class(TFrmBase)
    lblTitle: TLabel;
    lblTokenText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblTokenTextClick(Sender: TObject);
  strict private
    FToken: TAddress;
    procedure SetAction(const value: TTokenAction);
    procedure SetToken(const value: TAddress);
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
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

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
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmUnsupported) or whitelisted(TFrmUnsupported, token) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmUnsupported = TFrmUnsupported.Create(chain, tx, callback, logProc);
    frmUnsupported.Action := action;
    frmUnsupported.Token  := token;
    frmUnsupported.Show;
  end);
end;

{------------------------------ TFrmUnsupported -------------------------------}

procedure TFrmUnsupported.SetAction(const value: TTokenAction);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value]]);
end;

procedure TFrmUnsupported.SetToken(const value: TAddress);
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

function TFrmUnsupported.Bypass: TBypass;
begin
  Result := TBypass.Create('token', procedure
  begin
    whitelist(TFrmUnsupported, FToken);
  end);
end;

procedure TFrmUnsupported.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

end.
