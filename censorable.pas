unit censorable;

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
  TFrmCensorable = class(TFrmBase)
    lblTitle: TLabel;
    lblToken: TLabel;
    lblFooter: TLabel;
    procedure lblTokenClick(Sender: TObject);
  strict private
    FContract: TAddress;
    FIsERC20 : Boolean;
    function  What: string; inline;
    procedure SetAction(const value: TTokenAction);
    procedure SetContract(const value: TAddress);
    procedure SetIsERC20(const value: Boolean);
  strict protected
    function Bypass: TBypass; override;
  public
    property Action: TTokenAction write SetAction;
    property Contract: TAddress write SetContract;
    property IsERC20: Boolean write SetIsERC20;
  end;

procedure show(
  const action  : TTokenAction;
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const isERC20 : Boolean;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);

implementation

uses
  // project
  cache, common, thread;

{$R *.fmx}

procedure show(
  const action  : TTokenAction;
  const chain   : TChain;
  const tx      : transaction.ITransaction;
  const contract: TAddress;
  const isERC20 : Boolean;
  const callback: TProc<Boolean, Boolean>; // -> (allow, shown)
  const logProc : TLogProc);
begin
  if whitelisted(TFrmCensorable) or whitelisted(TFrmCensorable, contract) then
  begin
    callback(True, False);
    EXIT;
  end;
  thread.synchronize(procedure
  begin
    const frmCensorable = TFrmCensorable.Create(chain, tx, callback, logProc);
    frmCensorable.Action   := action;
    frmCensorable.Contract := contract;
    frmCensorable.IsERC20  := isERC20;
    frmCensorable.Show;
  end);
end;

{------------------------------- TFrmCensorable -------------------------------}

function TFrmCensorable.Bypass: TBypass;
begin
  Result := TBypass.Create(Self.What, procedure
  begin
    whitelist(TFrmCensorable, FContract);
  end);
end;

function TFrmCensorable.What: string;
begin
  if FIsERC20 then Result := 'token' else Result := 'contract';
end;

procedure TFrmCensorable.SetAction(const value: TTokenAction);
begin
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [ActionText[value], '%s']);
end;

procedure TFrmCensorable.SetContract(const value: TAddress);
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

procedure TFrmCensorable.SetIsERC20(const value: Boolean);
begin
  FIsERC20 := value;
  lblTitle.Text := System.SysUtils.Format(lblTitle.Text, [Self.What]);
end;

procedure TFrmCensorable.lblTokenClick(Sender: TObject);
begin
  common.Open(Self.Chain.Explorer + '/address/' + string(FContract));
end;

end.
