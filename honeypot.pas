unit honeypot;

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
  TFrmHoneypot = class(TFrmBase)
    lblHeader: TLabel;
    lblToken: TLabel;
    lblFooter: TLabel;
    procedure lblTokenClick(Sender: TObject);
  strict private
    FToken: TAddress;
    procedure SetToken(const value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Token: TAddress write SetToken;
  end;

type
  TCannot = (Transfer, Sell);

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const token   : TAddress;
  const cannot  : TCannot;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const token   : TAddress;
  const cannot  : TCannot;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
const
  CannotString: array[TCannot] of string = (
    'You cannot transfer this token',
    'You are about to receive a token you cannot sell');
begin
  if whitelisted(TFrmHoneypot) or whitelisted(TFrmHoneypot, token) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmHoneypot = TFrmHoneypot.Create(chain, tx, callback, logProc);
    frmHoneypot.Token          := token;
    frmHoneypot.Blocked        := cannot = TCannot.Sell;
    frmHoneypot.lblHeader.Text := CannotString[cannot];
    frmHoneypot.Show;
  end);
end;

{-------------------------------- TFrmHoneypot --------------------------------}

procedure TFrmHoneypot.SetToken(const value: TAddress);
begin
  FToken := value;
  lblToken.Text := string(FToken);
  if not common.Demo then
    cache.getSymbol(Self.Chain, FToken, procedure(symbol: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblToken.Text := symbol;
      end);
    end);
end;

function TFrmHoneypot.Bypass: TBypass;
begin
  Result := TBypass.Create('token', procedure
  begin
    whitelist(TFrmHoneypot, FToken);
  end);
end;

procedure TFrmHoneypot.lblTokenClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

end.
