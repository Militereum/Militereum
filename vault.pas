unit vault;

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
  TFrmVault = class(TFrmBase)
    lblTitle: TLabel;
    Label1: TLabel;
    Label2: TLabel;
  strict private
    FAddress: TAddress;
    procedure SetSymbol(const value: string);
  strict protected
    function Bypass: TBypass; override;
  public
    property Address: TAddress write FAddress;
    property Symbol: string write SetSymbol;
  end;

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const vault   : TAddress;
  const symbol  : string;
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);

implementation

uses
  // project
  thread;

{$R *.fmx}

procedure show(
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const vault   : TAddress;
  const symbol  : string;
  const allowed : TProc;
  const callback: TProc<Boolean>;
  const log     : TLogProc);
begin
  if whitelisted(TFrmVault) or whitelisted(TFrmVault, vault) then
  begin
    allowed;
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmVault = TFrmVault.Create(chain, tx, callback, log);
    frmVault.Address := vault;
    frmVault.Symbol  := symbol;
    frmVault.Show;
  end);
end;

{--------------------------------- TFrmVault ----------------------------------}

procedure TFrmVault.SetSymbol(const value: string);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [value]);
end;

function TFrmVault.Bypass: TBypass;
begin
  Result := TBypass.Create('vault', procedure
  begin
    whitelist(TFrmVault, FAddress);
  end);
end;

end.
