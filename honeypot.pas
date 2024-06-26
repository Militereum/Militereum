unit honeypot;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  base,
  transaction;

type
  TFrmHoneypot = class(TFrmBase)
    lblHeader: TLabel;
    lblTokenTitle: TLabel;
    lblRecipientTitle: TLabel;
    lblRecipientText: TLabel;
    lblTokenText: TLabel;
    lblFooter: TLabel;
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblRecipientTextClick(Sender: TObject);
  strict private
    FToken: TAddress;
    procedure SetToken(value: TAddress);
    procedure SetRecipient(value: TAddress);
  public
    property Token: TAddress write SetToken;
    property Recipient: TAddress write SetRecipient;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token, recipient: TAddress; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // web3
  web3.utils,
  // project
  cache,
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token, recipient: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmHoneypot = TFrmHoneypot.Create(chain, tx, callback, log);
  frmHoneypot.Token     := token;
  frmHoneypot.Recipient := recipient;
  frmHoneypot.Show;
end;

{ TFrmHoneypot }

procedure TFrmHoneypot.SetToken(value: TAddress);
begin
  FToken := value;
  if common.Demo then
    lblTokenText.Text := string(value)
  else
    cache.getSymbol(Self.Chain, FToken, procedure(symbol: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblTokenText.Text := symbol;
      end);
    end);
end;

procedure TFrmHoneypot.SetRecipient(value: TAddress);
begin
  lblRecipientText.Text := string(value);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, value, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblRecipientText.Text := friendly;
      end);
    end);
end;

procedure TFrmHoneypot.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmHoneypot.lblRecipientTextClick(Sender: TObject);
begin
  cache.fromName(lblRecipientText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.Chain.Explorer + '/address/' + lblRecipientText.Text);
  end);
end;

end.
