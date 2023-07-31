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
  base,
  transaction;

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
    FToken: TAddress;
    procedure SetToken(value: TAddress);
    procedure SetSpender(value: TAddress);
  public
    property Token: TAddress write SetToken;
    property Spender: TAddress write SetSpender;
  end;

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token, spender: TAddress; const callback: TProc<Boolean>; const log: TLog);

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

procedure show(const chain: TChain; const tx: transaction.ITransaction; const token, spender: TAddress; const callback: TProc<Boolean>; const log: TLog);
begin
  const frmSetApprovalForAll = TFrmSetApprovalForAll.Create(chain, tx, callback, log);
  frmSetApprovalForAll.Token   := token;
  frmSetApprovalForAll.Spender := spender;
  frmSetApprovalForAll.Show;
end;

{ TFrmSetApprovalForAll }

procedure TFrmSetApprovalForAll.SetToken(value: TAddress);
begin
  FToken := value;
  web3.eth.erc721.create(TWeb3.Create(Chain), FToken).Name(procedure(name: string; err: IError)
  begin
    if Assigned(err) then
      Self.Log(err)
    else if name.IsEmpty then
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
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
    begin
      lblSpenderText.Text := ens;
    end);
  end);
end;

procedure TFrmSetApprovalForAll.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmSetApprovalForAll.lblSpenderTextClick(Sender: TObject);
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
