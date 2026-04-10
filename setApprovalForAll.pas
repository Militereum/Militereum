unit setApprovalForAll;

interface

uses
  // Delphi
  System.Classes, System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Menus,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  base, transaction;

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
    FToken  : TAddress;
    FSpender: TAddress;
    procedure SetToken(const value: TAddress);
    procedure SetSpender(const value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Token: TAddress write SetToken;
    property Spender: TAddress write SetSpender;
  end;

procedure show(
  const chain         : TChain;
  const tx            : transaction.ITransaction;
  const token, spender: TAddress;
  const callback      : TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc       : TLogProc);

implementation

uses
  // web3
  web3.eth.erc721,
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain         : TChain;
  const tx            : transaction.ITransaction;
  const token, spender: TAddress;
  const callback      : TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc       : TLogProc);
begin
  if whitelisted(TFrmSetApprovalForAll) or whitelisted(TFrmSetApprovalForAll, spender) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmSetApprovalForAll = TFrmSetApprovalForAll.Create(chain, tx, callback, logProc);
    frmSetApprovalForAll.Token   := token;
    frmSetApprovalForAll.Spender := spender;
    frmSetApprovalForAll.Show;
  end);
end;

{--------------------------- TFrmSetApprovalForAll ----------------------------}

procedure TFrmSetApprovalForAll.SetToken(const value: TAddress);
begin
  FToken := value;
  web3.eth.erc721.create(TWeb3.Create(Chain), FToken).Name(procedure(name: string; err: IError)
  begin
    if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
    begin
      if name.IsEmpty then
        lblTokenText.Text := string(FToken)
      else
        lblTokenText.Text := name;
    end);
  end);
end;

procedure TFrmSetApprovalForAll.SetSpender(const value: TAddress);
begin
  FSpender := value;
  lblSpenderText.Text := string(FSpender);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FSpender, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblSpenderText.Text := friendly;
      end);
    end);
end;

function TFrmSetApprovalForAll.Bypass: TBypass;
begin
  Result := TBypass.Create('spender', procedure
  begin
    whitelist(TFrmSetApprovalForAll, FSpender);
  end);
end;

procedure TFrmSetApprovalForAll.lblTokenTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/token/' + string(FToken));
end;

procedure TFrmSetApprovalForAll.lblSpenderTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FSpender));
end;

end.
