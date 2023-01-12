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
    FToken: IToken;
    FCallback: TProc<Boolean>;
    procedure SetToken(token: IToken);
    procedure SetSpender(spender: TAddress);
    procedure SetQuantity(quantity: BigInteger);
  public
    property Chain: TChain write FChain;
    property Token: IToken write SetToken;
    property Spender: TAddress write SetSpender;
    property Quantity: BigInteger write SetQuantity;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; const token: IToken; spender: TAddress; quantity: BigInteger; callback: TProc<Boolean>);

implementation

uses
  // Delphi
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

procedure show(chain: TChain; const token: IToken; spender: TAddress; quantity: BigInteger; callback: TProc<Boolean>);
begin
  const frmApprove = TFrmApprove.Create(Application);
  frmApprove.Chain := chain;
  frmApprove.Token := token;
  frmApprove.Spender := spender;
  frmApprove.Quantity := quantity;
  frmApprove.Callback := callback;
  frmApprove.Show;
end;

{ TFrmApprove }

procedure TFrmApprove.SetToken(token: IToken);
begin
  FToken := token;

  lblTokenText.Text := (function: string
  begin
    if token.Name <> '' then
      Result := token.Name
    else if token.Symbol <> '' then
      Result := token.Symbol
    else
      Result := string(token.Address);
  end)();

  if token.Logo <> '' then
    web3.http.get(token.Logo, [], procedure(img: IHttpResponse; err: IError)
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

procedure TFrmApprove.SetSpender(spender: TAddress);
begin
  lblSpenderText.Text := string(spender);
  if spender.IsEOA(TWeb3.Create(Self.FChain)).Value then
    lblTitle.Text := Format(lblTitle.Text, ['someone'])
  else
    lblTitle.Text := Format(lblTitle.Text, ['something']);
end;

procedure TFrmApprove.SetQuantity(quantity: BigInteger);
begin
  if quantity <> web3.Infinite then
    web3.defillama.price(Self.FChain, FToken.Address, procedure(price: Double; _: IError)
    begin
      if price > 0 then
        lblAmountText.Text := Format('$ %.2f', [quantity.AsInt64 * price]);
    end);
end;

procedure TFrmApprove.lblTokenTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/token/' + string(FToken.Address));
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
