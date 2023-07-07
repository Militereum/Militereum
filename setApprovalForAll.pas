unit setApprovalForAll;

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
  TFrmSetApprovalForAll = class(TFrmBase)
    lblTitle: TLabel;
    lblTokenTitle: TLabel;
    lblSpenderTitle: TLabel;
    lblSpenderText: TLabel;
    lblTokenText: TLabel;
    lblAmountTitle: TLabel;
    lblAmountText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblTokenTextClick(Sender: TObject);
    procedure lblSpenderTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FToken: TAddress;
    procedure SetToken(value: TAddress);
    procedure SetSpender(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Token: TAddress write SetToken;
    property Spender: TAddress write SetSpender;
  end;

procedure show(const chain: TChain; const token, spender: TAddress; const callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // web3
  web3.eth.erc721,
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const token, spender: TAddress; const callback: TProc<Boolean>);
begin
  const frmSetApprovalForAll = TFrmSetApprovalForAll.Create(Application);
  frmSetApprovalForAll.Chain := chain;
  frmSetApprovalForAll.Token := token;
  frmSetApprovalForAll.Spender := spender;
  frmSetApprovalForAll.Callback := callback;
  frmSetApprovalForAll.Show;
end;

{ TFrmSetApprovalForAll }

procedure TFrmSetApprovalForAll.SetToken(value: TAddress);
begin
  FToken := value;
  web3.eth.erc721.create(TWeb3.Create(FChain), FToken).Name(procedure(name: string; err: IError)
  begin
    if Assigned(err) or name.IsEmpty then
      lblTokenText.Text := string(value)
    else
      lblTokenText.Text := name;
  end);
end;

procedure TFrmSetApprovalForAll.SetSpender(value: TAddress);
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

procedure TFrmSetApprovalForAll.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.FChain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmSetApprovalForAll.lblSpenderTextClick(Sender: TObject);
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
