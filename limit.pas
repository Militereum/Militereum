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
  base;

type
  TFrmLimit = class(TFrmBase)
    lblTitle: TLabel;
    lblAssetTitle: TLabel;
    lblRecipientTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblRecipientText: TLabel;
    lblAssetText: TLabel;
    lblAmountTitle: TLabel;
    lblAmountText: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblRecipientTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetSymbol(const value: string);
    procedure SetRecipient(value: TAddress);
    procedure SetAmount(value: Double);
  public
    constructor Create(aOwner: TComponent); override;
    property Chain: TChain write FChain;
    property Symbol: string write SetSymbol;
    property Recipient: TAddress write SetRecipient;
    property Amount: Double write SetAmount;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(const chain: TChain; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>);

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

procedure show(const chain: TChain; const symbol: string; const recipient: TAddress; const amount: Double; const callback: TProc<Boolean>);
begin
  const frmLimit = TFrmLimit.Create(Application);
  frmLimit.Chain := chain;
  frmLimit.Symbol := symbol;
  frmLimit.Recipient := recipient;
  frmLimit.Amount := amount;
  frmLimit.Callback := callback;
  frmLimit.Show;
end;

{ TFrmLimit }

constructor TFrmLimit.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
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
  TAddress.Create(TWeb3.Create(common.Ethereum), lblRecipientText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.BlockExplorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.BlockExplorer + '/address/' + lblRecipientText.Text);
  end);
end;

procedure TFrmLimit.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmLimit.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
