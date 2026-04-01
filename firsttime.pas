unit firsttime;

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
  TFrmFirstTime = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressText: TLabel;
    lblMessage: TLabel;
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FAddress: TAddress;
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
  if whitelisted(TFrmFirstTime) or whitelisted(TFrmFirstTime, address) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmFirstTime = TFrmFirstTime.Create(chain, tx, callback, logProc);
    frmFirstTime.Address := address;
    frmFirstTime.Show;
  end);
end;

{------------------------------- TFrmFirstTime --------------------------------}

procedure TFrmFirstTime.SetAddress(const value: TAddress);
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

function TFrmFirstTime.Bypass: TBypass;
begin
  Result := TBypass.Create('address', procedure
  begin
    whitelist(TFrmFirstTime, FAddress);
  end);
end;

procedure TFrmFirstTime.lblAddressTextClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FAddress));
end;

end.
