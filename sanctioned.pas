unit sanctioned;

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
  TFrmSanctioned = class(TFrmBase)
    lblTitle: TLabel;
    lblAddressTitle: TLabel;
    btnAllow: TButton;
    btnBlock: TButton;
    lblAddressText: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnBlockClick(Sender: TObject);
    procedure btnAllowClick(Sender: TObject);
    procedure lblAddressTextClick(Sender: TObject);
  strict private
    FChain: TChain;
    FCallback: TProc<Boolean>;
    procedure SetAddress(address: TAddress);
  public
    property Chain: TChain write FChain;
    property Address: TAddress write SetAddress;
    property Callback: TProc<Boolean> write FCallback;
  end;

procedure show(chain: TChain; address: TAddress; callback: TProc<Boolean>);

implementation

uses
  // FireMonkey
  FMX.Forms,
  // project
  common;

{$R *.fmx}

procedure show(chain: TChain; address: TAddress; callback: TProc<Boolean>);
begin
  const frmSanctioned = TFrmSanctioned.Create(Application);
  frmSanctioned.Chain := chain;
  frmSanctioned.Address := address;
  frmSanctioned.Callback := callback;
  frmSanctioned.Show;
end;

{ TFrmSanctioned }

procedure TFrmSanctioned.SetAddress(address: TAddress);
begin
  lblAddressText.Text := string(address);
end;

procedure TFrmSanctioned.lblAddressTextClick(Sender: TObject);
begin
  common.open(Self.FChain.BlockExplorer + '/address/' + lblAddressText.Text);
end;

procedure TFrmSanctioned.btnBlockClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(False);
  Self.Close;
end;

procedure TFrmSanctioned.btnAllowClick(Sender: TObject);
begin
  if Assigned(Self.FCallback) then Self.FCallback(True);
  Self.Close;
end;

end.
