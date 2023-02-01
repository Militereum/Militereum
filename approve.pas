unit approve;

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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.alchemy.api,
  web3.eth.tokenlists,
  // project
  base;

type
  TFrmApprove = class(TFrmBase)
    imgLogo: TImage;
    lblTitle: TLabel;
    lblTokenTitle: TLabel;
    lblSpenderTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblSpenderText: TLabel;
    lblTokenText: TLabel;
    lblAmountTitle: TLabel;
    lblAmountText: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblSpenderTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FToken: TAddress;
    FCallback: TProc<Boolean>;
    procedure SetKind(value: TChangeType);
    procedure SetToken(value: IToken);
    procedure SetChange(value: IAssetChange);
    procedure SetLogo(value: TURL);
    procedure SetSpender(value: TAddress);
  public
    procedure Amount(const symbol: string; quantity: BigInteger; decimals: Integer);
    property Chain: TChain write FChain;
    property Kind: TChangeType write SetKind;
    property Token: IToken write SetToken;
    property Change: IAssetChange write SetChange;
    property Logo: TURL write SetLogo;
    property Spender: TAddress write SetSpender;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; const token: IToken; spender: TAddress; quantity: BigInteger; callback: TProc<Boolean>); overload;
procedure show(chain: TChain; const change: IAssetChange; callback: TProc<Boolean>); overload;

implementation

uses
  // Delphi
  System.Math,
  System.Net.HttpClient,
  // FireMonkey
  FMX.Forms,
  // web3
  web3.defillama,
  web3.http,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(chain: TChain; const token: IToken; spender: TAddress; quantity: BigInteger; callback: TProc<Boolean>);
begin
  const frmApprove = TFrmApprove.Create(Application);
  frmApprove.Chain := chain;
  frmApprove.Token := token;
  frmApprove.Spender := spender;
  frmApprove.Amount(token.Symbol, quantity, token.Decimals);
  frmApprove.Callback := callback;
  frmApprove.Show;
end;

procedure show(chain: TChain; const change: IAssetChange; callback: TProc<Boolean>);
begin
  const frmApprove = TFrmApprove.Create(Application);
  frmApprove.Chain := chain;
  frmApprove.Change := change;
  frmApprove.Callback := callback;
  frmApprove.Show;
end;

{ TFrmApprove }

procedure TFrmApprove.SetKind(value: TChangeType);
begin
  if value = Transfer then
  begin
    lblTitle.Text := 'The following token is about to leave your wallet.';
    lblSpenderTitle.Text := 'Recipient';
  end;
end;

procedure TFrmApprove.SetToken(value: IToken);
begin
  FToken := value.Address;

  lblTokenText.Text := (function: string
  begin
    if value.Name <> '' then
      Result := value.Name
    else
      Result := string(value.Address);
  end)();

  Self.Logo := value.Logo;
end;

procedure TFrmApprove.SetChange(value: IAssetChange);
begin
  FToken := value.Contract;

  lblTokenText.Text := (function: string
  begin
    if value.Name <> '' then
      Result := value.Name
    else
      Result := string(value.Contract);
  end)();

  Self.Kind := value.Change;
  Self.Logo := value.Logo;
  Self.Spender := value.&To;
  Self.Amount(value.Symbol, value.Amount, value.Decimals);
end;

procedure TFrmApprove.SetLogo(value: TURL);
begin
  if value <> '' then
    web3.http.get(value, [], procedure(img: IHttpResponse; err: IError)
    begin
      if Assigned(img) then
        thread.synchronize(procedure
        begin
          try
            imgLogo.Bitmap.LoadFromStream(img.ContentStream);
          except end;
        end);
    end);
end;

procedure TFrmApprove.SetSpender(value: TAddress);
begin
  lblSpenderText.Text := string(value);
end;

procedure TFrmApprove.Amount(const symbol: string; quantity: BigInteger; decimals: Integer);
begin
  if quantity <> web3.Infinite then
    web3.defillama.price(Self.FChain, FToken, procedure(price: Double; _: IError)
    begin
      if (price > 0) and (quantity.BitLength <= 64) then
        lblAmountText.Text := System.SysUtils.Format('$ %.2f', [quantity.AsUInt64 * price])
      else
        lblAmountText.Text := System.SysUtils.Format('%s %s', [symbol, common.format(quantity.AsDouble / Round(Power(10, decimals)))]);
    end);
end;

procedure TFrmApprove.lblTokenTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/token/' + string(FToken));
end;

procedure TFrmApprove.lblSpenderTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/address/' + lblSpenderText.Text);
end;

procedure TFrmApprove.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmApprove.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
