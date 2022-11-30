unit approve;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.UITypes,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  web3.eth.tokenlists;

type
  TFrmApprove = class(TForm)
    imgLogo: TImage;
    lblTitle: TLabel;
    lblTokenTitle: TLabel;
    lblSpenderTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblSpenderText: TLabel;
    lblTokenText: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblSpenderTextClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FToken: IToken;
    FOnBlock: TProc;
    FOnAllow: TProc;
    procedure SetToken(token: IToken);
    procedure SetSpender(spender: TAddress);
  public
    property Token: IToken write SetToken;
    property Spender: TAddress write SetSpender;
    property OnBlock: TProc write FOnBlock;
    property OnAllow: TProc write FOnAllow;
  end;

procedure show(const token: IToken; spender: TAddress; onBlock, onAllow: TProc);

implementation

uses
  // Delphi
  System.Net.HttpClient,
  // web3
  web3.eth.types,
  web3.http,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const token: IToken; spender: TAddress; onBlock, onAllow: TProc);
begin
  const frmApprove = TFrmApprove.Create(Application);
  frmApprove.Token := token;
  frmApprove.Spender := spender;
  frmApprove.OnBlock := onBlock;
  frmApprove.OnAllow := onAllow;
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

  if token.LogoURI <> '' then
    web3.http.get(token.LogoURI, [], procedure(img: IHttpResponse; err: IError)
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
  if spender.IsEOA(TWeb3.Create(common.endpoint)).Value then
    Self.Caption := Format(Self.Caption, ['someone'])
  else
    Self.Caption := Format(Self.Caption, ['something']);
end;

procedure TFrmApprove.lblTokenTextClick(Sender: TObject);
begin
  common.open(chain.BlockExplorer + '/token/' + string(FToken.Address));
end;

procedure TFrmApprove.lblSpenderTextClick(Sender: TObject);
begin
  common.open(chain.BlockExplorer + '/address/' + lblSpenderText.Text);
end;

procedure TFrmApprove.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FOnBlock) then Self.FOnBlock();
  Self.Close;
end;

procedure TFrmApprove.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FOnAllow) then Self.FOnAllow();
  Self.Close;
end;

procedure TFrmApprove.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := TCloseAction.caFree;
end;

end.
