unit blacklisted;

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
  TFrmBlacklisted = class(TFrmBase)
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
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const address : TAddress;
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);
begin
  if whitelisted(TFrmBlacklisted) or whitelisted(TFrmBlacklisted, address) then
  begin
    allowed;
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmBlacklisted = TFrmBlacklisted.Create(chain, tx, callback, log);
    frmBlacklisted.Address := address;
    frmBlacklisted.Show;
  end);
end;

{------------------------------ TFrmBlacklisted -------------------------------}

procedure TFrmBlacklisted.SetAddress(const value: TAddress);
begin
  if value <> FAddress then
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
end;

function TFrmBlacklisted.Bypass: TBypass;
begin
  Result := TBypass.Create('address', procedure
  begin
    whitelist(TFrmBlacklisted, FAddress);
  end);
end;

procedure TFrmBlacklisted.lblAddressClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FAddress));
end;

end.
