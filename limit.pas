unit limit;

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
    procedure SetSymbol(const value: string);
    procedure SetRecipient(value: TAddress);
    procedure SetAmount(value: Double);
  public
    constructor Create(const chain: TChain; const tx: transaction.ITransaction; const callback: TProc<Boolean>; const log: TLog); override;
    property Symbol: string write SetSymbol;
    property Recipient: TAddress write SetRecipient;
    property Amount: Double write SetAmount;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>; const log: TLog);

implementation

uses
  // project
  cache,
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmLimit = TFrmLimit.Create(chain, tx, callback, log);
  frmLimit.Symbol    := symbol;
  frmLimit.Recipient := recipient;
  frmLimit.Amount    := amount;
  frmLimit.Show;
end;

{ TFrmLimit }

constructor TFrmLimit.Create(const chain: TChain; const tx: transaction.ITransaction; const callback: TProc<Boolean>; const log: TLog);
begin
  inherited Create(chain, tx, callback, log);
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [common.LIMIT]);
end;

procedure TFrmLimit.SetSymbol(const value: string);
begin
  lblAssetText.Text := value;
end;

procedure TFrmLimit.SetRecipient(value: TAddress);
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

procedure TFrmLimit.SetAmount(value: Double);
begin
  lblAmountText.Text := System.SysUtils.Format('$ %.2f', [value]);
end;

procedure TFrmLimit.lblRecipientTextClick(Sender: TObject);
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
