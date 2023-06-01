unit asset;

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
  TFrmAsset = class(TFrmBase)
    imgLogo: TImage;
    lblTitle: TLabel;
    lblTokenTitle: TLabel;
    lblSpenderTitle: TLabel;
    lblSpenderText: TLabel;
    lblTokenText: TLabel;
    lblAmountTitle: TLabel;
    lblAmountText: TLabel;
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblSpenderTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FToken: TAddress;
    procedure SetKind(value: TChangeType);
    procedure SetToken(value: IToken);
    procedure SetChange(value: IAssetChange);
    procedure SetLogo(value: TURL);
    procedure SetSpender(value: TAddress);
  public
    procedure Amount(const symbol: string; const quantity: BigInteger; const decimals: Integer);
    property Chain: TChain write FChain;
    property Kind: TChangeType write SetKind;
    property Token: IToken write SetToken;
    property Change: IAssetChange write SetChange;
    property Logo: TURL write SetLogo;
    property Spender: TAddress write SetSpender;
  end;

procedure approve(const chain: TChain; const token: IToken; const spender: TAddress; const quantity: BigInteger; const callback: TProc<Boolean>);
procedure show(const chain: TChain; const change: IAssetChange; const callback: TProc<Boolean>);

implementation

uses
  // Delphi
  System.Math,
  System.Net.HttpClient,
  // FireMonkey
  FMX.Forms,
  // web3
  web3.defillama,
  web3.eth.types,
  web3.http,
  // project
  common,
  thread;

{$R *.fmx}

procedure approve(const chain: TChain; const token: IToken; const spender: TAddress; const quantity: BigInteger; const callback: TProc<Boolean>);
begin
  const frmAsset = TFrmAsset.Create(Application);
  frmAsset.Chain := chain;
  frmAsset.Token := token;
  frmAsset.Spender := spender;
  frmAsset.Amount(token.Symbol, quantity, token.Decimals);
  frmAsset.Callback := callback;
  frmAsset.Show;
end;

procedure show(const chain: TChain; const change: IAssetChange; const callback: TProc<Boolean>);
begin
  const frmApprove = TFrmAsset.Create(Application);
  frmApprove.Chain := chain;
  frmApprove.Change := change;
  frmApprove.Callback := callback;
  frmApprove.Show;
end;

{ TFrmAsset }

procedure TFrmAsset.SetKind(value: TChangeType);
begin
  if value = Transfer then
  begin
    lblTitle.Text := 'The following token is about to leave your wallet';
    lblSpenderTitle.Text := 'Recipient';
  end;
end;

procedure TFrmAsset.SetToken(value: IToken);
begin
  FToken := value.Address;

  lblTokenText.Text := (function(const value: IToken): string
  begin
    if value.Name <> '' then
      Result := value.Name
    else
      Result := string(value.Address);
  end)(value);

  Self.Logo := value.Logo;
end;

procedure TFrmAsset.SetChange(value: IAssetChange);
begin
  FToken := value.Contract;

  lblTokenText.Text := (function(const value: IAssetChange): string
  begin
    if value.Name <> '' then
      Result := value.Name
    else
      Result := string(value.Contract);
  end)(value);

  Self.Kind := value.Change;
  Self.Logo := value.Logo;
  Self.Spender := value.&To;
  Self.Amount(value.Symbol, value.Amount, value.Decimals);
end;

procedure TFrmAsset.SetLogo(value: TURL);
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

procedure TFrmAsset.SetSpender(value: TAddress);
begin
  lblSpenderText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblSpenderText.Text := ens;
      end);
  end);
end;

procedure TFrmAsset.Amount(const symbol: string; const quantity: BigInteger; const decimals: Integer);
begin
  if quantity = web3.Infinite then
    lblAmountText.Text := 'Unlimited'
  else
    web3.defillama.price(Self.FChain, FToken, procedure(price: Double; _: IError)
    begin
      thread.synchronize(procedure
      begin
        if (price > 0) and (quantity.BitLength <= 64) then
          lblAmountText.Text := System.SysUtils.Format('$ %s', [common.Format(quantity.AsUInt64 * price)])
        else
          lblAmountText.Text := System.SysUtils.Format('%s %s', [symbol, common.Format(quantity.AsDouble / Round(Power(10, decimals)))]);
      end);
    end);
end;

procedure TFrmAsset.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.FChain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmAsset.lblSpenderTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblSpenderText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.Explorer + '/address/' + lblSpenderText.Text);
  end);
end;

end.
