unit metamorphic;

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
  TFrmMetamorphic = class(TFrmBase)
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
  if whitelisted(TFrmMetamorphic) or whitelisted(TFrmMetamorphic, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmMetamorphic = TFrmMetamorphic.Create(chain, tx, callback, logProc);
    frmMetamorphic.Contract := contract;
    frmMetamorphic.Show;
  end);
end;

{------------------------------ TFrmMetamorphic -------------------------------}

procedure TFrmMetamorphic.SetContract(const value: TAddress);
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

function TFrmMetamorphic.Bypass: TBypass;
begin
  Result := TBypass.Create('contract', procedure
  begin
    whitelist(TFrmMetamorphic, FContract);
  end);
end;

procedure TFrmMetamorphic.lblAddressClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract));
end;

end.
