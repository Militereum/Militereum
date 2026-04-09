unit pausable;

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
  TFrmPausable = class(TFrmBase)
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
  if whitelisted(TFrmPausable) or whitelisted(TFrmPausable, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmPausable = TFrmPausable.Create(chain, tx, callback, logProc);
    frmPausable.Info     := info;
    frmPausable.Contract := contract;
    frmPausable.Show;
  end);
end;

{-------------------------------- TFrmPausable --------------------------------}

procedure TFrmPausable.SetInfo(const value: TContractInfo);
begin
  FInfo := value;
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value.Action], value.TargetText]);
end;

procedure TFrmPausable.SetContract(const value: TAddress);
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

function TFrmPausable.Bypass: TBypass;
begin
  Result := TBypass.Create(FInfo.TargetText, procedure
  begin
    whitelist(TFrmPausable, FContract);
  end);
end;

procedure TFrmPausable.lblTokenClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract));
end;

end.
