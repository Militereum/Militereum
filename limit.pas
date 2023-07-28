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
    constructor Create(const chain: TChain; const tx: transaction.ITransaction; const callback: TProc<Boolean>); override;
    property Symbol: string write SetSymbol;
    property Recipient: TAddress write SetRecipient;
    property Amount: Double write SetAmount;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // web3
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const tx: transaction.ITransaction; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>);
begin
  const frmLimit = TFrmLimit.Create(chain, tx, callback);
  frmLimit.Symbol    := symbol;
  frmLimit.Recipient := recipient;
  frmLimit.Amount    := amount;
  frmLimit.Show;
end;

{ TFrmLimit }

constructor TFrmLimit.Create(const chain: TChain; const tx: transaction.ITransaction; const callback: TProc<Boolean>);
begin
  inherited Create(chain, tx, callback);
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [common.LIMIT]);
end;

procedure TFrmLimit.SetSymbol(const value: string);
begin
  lblAssetText.Text := value;
end;

procedure TFrmLimit.SetRecipient(value: TAddress);
begin
  lblRecipientText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblRecipientText.Text := ens;
      end);
  end);
end;

procedure TFrmLimit.SetAmount(value: Double);
begin
  lblAmountText.Text := System.SysUtils.Format('$ %.2f', [value]);
end;

procedure TFrmLimit.lblRecipientTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblRecipientText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.Chain.Explorer + '/address/' + lblRecipientText.Text);
  end);
end;

end.
