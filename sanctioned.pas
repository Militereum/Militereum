unit sanctioned;

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
  TFrmSanctioned = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FAddress: Taddress;
    procedure SetAddress(const value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Address: TAddress write SetAddress;
  end;

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const address : TAddress;
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
  const address : TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmSanctioned) or whitelisted(TFrmSanctioned, address) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmSanctioned = TFrmSanctioned.Create(chain, tx, callback, logProc);
    frmSanctioned.Address := address;
    frmSanctioned.Show;
  end);
end;

{------------------------------- TFrmSanctioned -------------------------------}

procedure TFrmSanctioned.SetAddress(const value: TAddress);
begin
  FAddress := value;
  lblAddressText.Text := string(FAddress);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FAddress, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddressText.Text := friendly;
      end);
    end);
end;

function TFrmSanctioned.Bypass: TBypass;
begin
  Result := TBypass.Create('address', procedure
  begin
    whitelist(TFrmSanctioned, FAddress);
  end);
end;

procedure TFrmSanctioned.lblAddressTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FAddress));
end;

end.
