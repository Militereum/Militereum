unit limit;

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
  TFrmLimit = class(TFrmBase)
    lblTitle: TLabel;
    lblAssetTitle: TLabel;
    lblRecipientTitle: TLabel;
    lblRecipientText: TLabel;
    lblAssetText: TLabel;
    lblAmountTitle: TLabel;
    lblAmountText: TLabel;
    procedure lblRecipientTextClick(Sender: TObject);
  strict private
    FRecipient: TAddress;
    procedure SetLimit(const value: Integer);
    procedure SetSymbol(const value: string);
    procedure SetRecipient(const value: TAddress);
    procedure SetAmount(const value: Double);
  strict protected
    function Bypass: TBypass; override;
  public
    property Limit    : Integer  write SetLimit;
    property Symbol   : string   write SetSymbol;
    property Recipient: TAddress write SetRecipient;
    property Amount   : Double   write SetAmount;
  end;

procedure show(
  const chain    : TChain;
  const tx       : transaction.ITransaction;
  const symbol   : string;
  const recipient: TAddress;
  const amount   : Double;
  const callback : TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc  : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain    : TChain;
  const tx       : transaction.ITransaction;
  const symbol   : string;
  const recipient: TAddress;
  const amount   : Double;
  const callback : TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc  : TLogProc);
begin
  if whitelisted(TFrmLimit) or whitelisted(TFrmLimit, recipient) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmLimit = TFrmLimit.Create(chain, tx, callback, logProc);
    frmLimit.Limit     := common.LIMIT;
    frmLimit.Symbol    := symbol;
    frmLimit.Recipient := recipient;
    frmLimit.Amount    := amount;
    frmLimit.Show;
  end);
end;

{--------------------------------- TFrmLimit ----------------------------------}

procedure TFrmLimit.SetLimit(const value: Integer);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [value]);
end;

procedure TFrmLimit.SetSymbol(const value: string);
begin
  lblAssetText.Text := value;
end;

procedure TFrmLimit.SetRecipient(const value: TAddress);
begin
  FRecipient := value;
  lblRecipientText.Text := string(FRecipient);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FRecipient, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblRecipientText.Text := friendly;
      end);
    end);
end;

procedure TFrmLimit.SetAmount(const value: Double);
begin
  lblAmountText.Text := System.SysUtils.Format('$ %.2f', [value]);
end;

function TFrmLimit.Bypass: TBypass;
begin
  Result := TBypass.Create('recipient', procedure
  begin
    whitelist(TFrmLimit, FRecipient);
  end);
end;

procedure TFrmLimit.lblRecipientTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FRecipient));
end;

end.
