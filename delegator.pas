unit delegator;

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
  TFrmDelegator = class(TFrmBase)
    lblTitle: TLabel;
    lblAddress: TLabel;
    lblFooter: TLabel;
    procedure lblAddressClick(Sender: TObject);
  strict private
    FContract: TAddress;
    procedure SetContract(const value: TAddress);
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
  if whitelisted(TFrmDelegator) or whitelisted(TFrmDelegator, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmDelegator = TFrmDelegator.Create(chain, tx, callback, logProc);
    frmDelegator.Contract := contract;
    frmDelegator.Show;
  end);
end;

{------------------------------- TFrmDelegator --------------------------------}

function TFrmDelegator.Bypass: TBypass;
begin
  Result := TBypass.Create('contract', procedure
  begin
    whitelist(TFrmDelegator, FContract);
  end);
end;

procedure TFrmDelegator.SetContract(const value: TAddress);
begin
  FContract := value;
  lblAddress.Text := string(FContract);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FContract, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddress.Text := friendly;
      end);
    end);
end;

procedure TFrmDelegator.lblAddressClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract));
end;

end.
