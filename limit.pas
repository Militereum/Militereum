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
    procedure SetSymbol(const symbol: string);
    procedure SetRecipient(recipient: TAddress);
    procedure SetAmount(amount: Double);
  public
    constructor Create(aOwner: TComponent); override;
    property Chain: TChain write FChain;
    property Symbol: string write SetSymbol;
    property Recipient: TAddress write SetRecipient;
    property Amount: Double write SetAmount;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; const symbol: string; recipient: TAddress; amount: Double; callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // project
  common;

{$R *.fmx}

procedure show(chain: TChain; const symbol: string; recipient: TAddress; amount: Double; callback: TProc<Boolean>);
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
  lblTitle.Text := Format(lblTitle.Text, [common.LIMIT]);
end;

procedure TFrmLimit.SetSymbol(const symbol: string);
begin
  lblAssetText.Text := symbol;
end;

procedure TFrmLimit.SetRecipient(recipient: TAddress);
begin
  lblRecipientText.Text := string(recipient);
end;

procedure TFrmLimit.SetAmount(amount: Double);
begin
  lblAmountText.Text := Format('$ %.2f', [amount]);
end;

procedure TFrmLimit.lblRecipientTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/address/' + lblRecipientText.Text);
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
