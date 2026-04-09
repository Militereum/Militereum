unit dormant;

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
  TFrmDormant = class(TFrmBase)
    lblTitle: TLabel;
    lblToken: TLabel;
    lblFooter: TLabel;
    procedure lblTokenClick(Sender: TObject);
  strict private
    FContract: TAddress;
    FInfo: TContractInfo;
    procedure SetInfo(const value: TContractInfo);
    procedure SetContract(const value: TAddress);
  strict protected
    function Bypass: TBypass; override;
  public
    property Info: TContractInfo write SetInfo;
    property Contract: TAddress write SetContract;
  end;

procedure show(
  const info    : TContractInfo;
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
  const info    : TContractInfo;
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmDormant) or whitelisted(TFrmDormant, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmDormant = TFrmDormant.Create(chain, tx, callback, logProc);
    frmDormant.Info     := info;
    frmDormant.Contract := contract;
    frmDormant.Show;
  end);
end;

{-------------------------------- TFrmDormant ---------------------------------}

function TFrmDormant.Bypass: TBypass;
begin
  Result := TBypass.Create(FInfo.TargetText, procedure
  begin
    whitelist(TFrmDormant, FContract);
  end);
end;

procedure TFrmDormant.SetInfo(const value: TContractInfo);
begin
  FInfo := value;
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value.Action], value.TargetText]);
end;

procedure TFrmDormant.SetContract(const value: TAddress);
begin
  FContract := value;
  lblToken.Text := string(FContract);
  if not common.Demo then
    cache.getFriendlyName(Self.Chain, FContract, procedure(friendly: string; err: IError)
    begin
      if Assigned(err) then Self.Log(err) else thread.synchronize(procedure
      begin
        lblToken.Text := friendly;
      end);
    end);
end;

procedure TFrmDormant.lblTokenClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract));
end;

end.
