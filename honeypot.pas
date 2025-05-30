unit honeypot;

interface

uses
  // Delphi
  System.Classes, System.SysUtils,
  // FireMonkey
  FMX.Controls, FMX.Controls.Presentation, FMX.Objects, FMX.StdCtrls, FMX.Types,
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
    procedure SetToken(value: TAddress);
  public
    property Token: TAddress write SetToken;
  end;

type
  TCannot = (Transfer, Sell);

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token: TAddress; const cannot: TCannot; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token: TAddress; const cannot: TCannot; const callback: TProc<Boolean>; const log: TLog);
const
  CannotString: array[TCannot] of string = ('transfer', 'sell');
begin
  const frmHoneypot = TFrmHoneypot.Create(chain, tx, callback, log);
  frmHoneypot.Token := token;
  frmHoneypot.lblHeader.Text := System.SysUtils.Format(frmHoneypot.lblHeader.Text, [CannotString[cannot]]);
  frmHoneypot.Show;
end;

{ TFrmHoneypot }

procedure TFrmHoneypot.SetToken(value: TAddress);
begin
  FToken := value;
  if common.Demo then
    lblToken.Text := string(value)
  else
    cache.getSymbol(Self.Chain, FToken, procedure(symbol: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblToken.Text := symbol;
      end);
    end);
end;

procedure TFrmHoneypot.lblTokenClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

end.
