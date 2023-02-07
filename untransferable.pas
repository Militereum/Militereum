unit untransferable;

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
  TFrmUntransferable = class(TFrmBase)
    lblHeader: TLabel;
    lblTokenTitle: TLabel;
    lblRecipientTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblRecipientText: TLabel;
    lblTokenText: TLabel;
    lblFooter: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblRecipientTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FToken: TAddress;
    FCallback: TProc<Boolean>;
    procedure SetToken(value: TAddress);
    procedure SetRecipient(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Token: TAddress write SetToken;
    property Recipient: TAddress write SetRecipient;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; token, recipient: TAddress; callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // project
  common,
  thread,
  // web3
  web3.eth.types;

{$R *.fmx}

procedure show(chain: TChain; token, recipient: TAddress; callback: TProc<Boolean>);
begin
  const frmUntransferable = TFrmUntransferable.Create(Application);
  frmUntransferable.Chain := chain;
  frmUntransferable.Token := token;
  frmUntransferable.Recipient := recipient;
  frmUntransferable.Callback := callback;
  frmUntransferable.Show;
end;

{ TFrmUntransferable }

procedure TFrmUntransferable.SetToken(value: TAddress);
begin
  FToken := value;
  if not FToken.IsZero then
    common.Symbol(FChain, FToken, procedure(symbol: string; _: IError)
    begin
      thread.synchronize(procedure
      begin
        lblTokenText.Text := symbol;
      end);
    end);
end;

procedure TFrmUntransferable.SetRecipient(value: TAddress);
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

procedure TFrmUntransferable.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.FChain.BlockExplorer + '/token/' + string(FToken));
end;

procedure TFrmUntransferable.lblRecipientTextClick(Sender: TObject);
begin
  TAddress.Create(TWeb3.Create(common.Ethereum), lblRecipientText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.BlockExplorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.BlockExplorer + '/address/' + lblRecipientText.Text);
  end);
end;

procedure TFrmUntransferable.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmUntransferable.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
