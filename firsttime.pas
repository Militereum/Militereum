unit firsttime;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  // project
  base;

type
  TFrmFirstTime = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblAddressText: TLabel;
    Label1: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetAddress(value: TAddress);
  public
    property Chain: TChain write FChain;
    property Address: TAddress write SetAddress;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(const chain: TChain; const address: TAddress; const callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // web3
  web3.eth.types,
  // project
  common,
  thread;

{$R *.fmx}

procedure show(const chain: TChain; const address: TAddress; const callback: TProc<Boolean>);
begin
  const frmFirstTime = TFrmFirstTime.Create(Application);
  frmFirstTime.Chain := chain;
  frmFirstTime.Address := address;
  frmFirstTime.Callback := callback;
  frmFirstTime.Show;
end;

{ TFrmFirstTime }

procedure TFrmFirstTime.SetAddress(value: TAddress);
begin
  lblAddressText.Text := string(value);
  value.ToString(TWeb3.Create(common.Ethereum), procedure(ens: string; err: IError)
  begin
    if not Assigned(err) then
      thread.synchronize(procedure
      begin
        lblAddressText.Text := ens;
      end);
  end);
end;

procedure TFrmFirstTime.lblAddressTextClick(Sender: TObject);
begin
  TAddress.Create(TWeb3.Create(common.Ethereum), lblAddressText.Text, procedure(address: TAddress; err: IError)
  begin
    if not Assigned(err) then
      common.Open(Self.FChain.BlockExplorer + '/address/' + string(address))
    else
      common.Open(Self.FChain.BlockExplorer + '/address/' + lblAddressText.Text);
  end);
end;

procedure TFrmFirstTime.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmFirstTime.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
