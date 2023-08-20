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
  base,
  transaction;

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
    FToken: TAddress;
    procedure SetKind(value: TChangeType);
    procedure SetToken(value: IToken);
    procedure SetChange(value: IAssetChange);
    procedure SetLogo(value: TURL);
    procedure SetSpender(value: TAddress);
  public
    procedure Amount(const symbol: string; const quantity: BigInteger; const decimals: Integer);
    property Kind: TChangeType write SetKind;
    property Token: IToken write SetToken;
    property Change: IAssetChange write SetChange;
    property Logo: TURL write SetLogo;
    property Spender: TAddress write SetSpender;
  end;

procedure approve(const chain: TChain; const tx: transaction.ITransaction; const token: IToken; const spender: TAddress; const quantity: BigInteger; const callback: TProc<Boolean>; const log: TLog);
procedure show(const chain: TChain; const tx: transaction.ITransaction; const change: IAssetChange; const callback: TProc<Boolean>; const log: TLog);

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

procedure approve(const chain: TChain; const tx: transaction.ITransaction; const token: IToken; const spender: TAddress; const quantity: BigInteger; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmAsset = TFrmAsset.Create(chain, tx, callback, log);
  frmAsset.Token   := token;
  frmAsset.Spender := spender;
  frmAsset.Amount(token.Symbol, quantity, token.Decimals);
  frmAsset.Show;
end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const change: IAssetChange; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmAsset = TFrmAsset.Create(chain, tx, callback, log);
  frmAsset.Change := change;
  frmAsset.Show;
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
      if Assigned(err) then Self.Log(err) else if Assigned(img) then thread.synchronize(procedure
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
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
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
    web3.defillama.price(Self.Chain, FToken, procedure(price: Double; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAmountText.Text := System.SysUtils.Format('$ %.2f', [(quantity.AsDouble / Round(Power(10, decimals))) * price]);
      end);
    end);
end;

procedure TFrmAsset.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmAsset.lblSpenderTextClick(Sender: TObject);
begin
  TAddress.FromName(TWeb3.Create(common.Ethereum), lblSpenderText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.Chain.Explorer + '/address/' + string(address))
    else
      common.Open(Self.Chain.Explorer + '/address/' + lblSpenderText.Text);
  end);
end;

end.
