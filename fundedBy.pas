unit fundedBy;

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
  TFrmFundedBy = class(TFrmBase)
    lblTitle: TLabel;
    lblAddress: TLabel;
    lblFooter: TLabel;
    procedure lblAddressClick(Sender: TObject);
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
  if whitelisted(TFrmFundedBy) or whitelisted(TFrmFundedBy, address) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmFundedBy = TFrmFundedBy.Create(chain, tx, callback, logProc);
    frmFundedBy.Address := address;
    frmFundedBy.Show;
  end);
end;

{-------------------------------- TFrmFundedBy --------------------------------}

function TFrmFundedBy.Bypass: TBypass;
begin
  Result := TBypass.Create('address', procedure
  begin
    whitelist(TFrmFundedBy, FAddress);
  end);
end;

procedure TFrmFundedBy.SetAddress(const value: TAddress);
begin
  FAddress := value;
  lblAddress.Text := string(FAddress);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FAddress, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblAddress.Text := friendly;
      end);
    end);
end;

procedure TFrmFundedBy.lblAddressClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FAddress));
end;

end.
