unit unverified;

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
  TFrmUnverified = class(TFrmBase)
    lblTitle: TLabel;
    lblContractText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblContractTextClick(Sender: TObject);
  strict private
    FContract: TAddress;
    procedure SetContract(value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Contract: TAddress write SetContract;
  end;

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmUnverified) or whitelisted(TFrmUnverified, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmUnverified = TFrmUnverified.Create(chain, tx, callback, logProc);
    frmUnverified.Contract := contract;
    frmUnverified.Show;
  end);
end;

{------------------------------- TFrmUnverified -------------------------------}

procedure TFrmUnverified.SetContract(value: TAddress);
begin
  if value <> FContract then
  begin
    FContract := value;
    lblContractText.Text := string(FContract);
    if not common.Demo then
      cache.getFriendlyName(Self.Chain, FContract, procedure(friendly: string; err: IError)
      begin
        if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
        begin
          lblContractText.Text := friendly;
        end);
      end);
  end;
end;

function TFrmUnverified.Bypass: TBypass;
begin
  Result := TBypass.Create('contract', procedure
  begin
    whitelist(TFrmUnverified, FContract);
  end);
end;

procedure TFrmUnverified.lblContractTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract) + '#code')
end;

end.
