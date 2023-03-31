unit main;

interface

uses
  // Delphi
  System.Classes,
  System.Notification,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.Layouts,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // Indy
  IdContext,
  IdGlobal,
  // web3
  web3,
  // project
  log,
  server,
  transaction;

type
  TFrmMain = class(TForm)
    btnDismiss: TButton;
    NC: TNotificationCenter;
    Grid: TGridPanelLayout;
    btnEthereum: TSpeedButton;
    btnGoerli: TSpeedButton;
    btnPolygon: TSpeedButton;
    btnArbitrum: TSpeedButton;
    btnOptimism: TSpeedButton;
    imgEthereum: TImage;
    imgGoerli: TImage;
    imgPolygon: TImage;
    imgArbitrum: TImage;
    imgOptimism: TImage;
    edtCopy: TEdit;
    btnCopy: TButton;
    lblWelcome: TLabel;
    imgMilitereum: TImage;
    lblTitle: TLabel;
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnNetworkClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
  strict private
    FCanNotify: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    FKnownTransactions: TStrings;
    procedure Dismiss;
    procedure Notify(const body: string); overload;
    procedure Notify(const port: TIdPort; const chain: TChain; const tx: ITransaction); overload;
    procedure ShowLogWindow;
  strict protected
    procedure DoShow; override;
    procedure DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
    procedure DoLog(const request, response: string);
    function  KnownTransactions: TStrings;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function GetChain: PChain;
  end;

var
  FrmMain: TFrmMain = nil;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.UITypes,
  // FireMonkey
  FMX.Dialogs,
  FMX.Platform,
  FMX.Text,
  // web3
  web3.eth.alchemy.api,
  web3.eth.types,
  web3.utils,
  // project
  checks,
  common,
  thread;

{$I Militereum.version}

{ TFrmMain }

constructor TFrmMain.Create(aOwner: TComponent);

  procedure terminate;
  begin
{$WARN SYMBOL_DEPRECATED OFF}
    MessageDlg('Cannot start HTTP server. The app will quit.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
{$WARN SYMBOL_DEPRECATED DEFAULT}
    Application.Terminate;
  end;

begin
  inherited Create(aOwner);

  Self.Caption := Self.Caption + ' ' + VERSION;

  edtCopy.Visible := False;
  btnCopy.Visible := False;

  const ports = server.ports(NUM_CHAINS);
  if ports.isErr then
  begin
    terminate;
    EXIT;
  end;

  const server = server.start(ports.Value);
  if server.isErr then
  begin
    terminate;
    EXIT;
  end;

  FServer := server.Value;
  FServer.OnRPC := DoRPC;
  FServer.OnLog := DoLog;

  FCanNotify := NC.AuthorizationStatus = TAuthorizationStatus.Authorized;
  if not FCanNotify then NC.RequestPermission;
end;

destructor TFrmMain.Destroy;
begin
  if Assigned(FServer) then
  try
    if FServer.Active then
    try
      FServer.Active := False;
    except end;
  finally
    FServer.Free;
  end;
  if Assigned(FKnownTransactions) then FKnownTransactions.Free;
  inherited Destroy;
end;

function TFrmMain.KnownTransactions: TStrings;
begin
  if not Assigned(FKnownTransactions) then FKnownTransactions := TStringList.Create;
  Result := FKnownTransactions;
end;

procedure TFrmMain.Notify(const body: string);
begin
  if FCanNotify then
    thread.synchronize(procedure
    begin
      const N = NC.CreateNotification;
      try
        N.AlertBody := body;
        NC.PresentNotification(N);
      finally
        N.Free;
      end;
    end);
end;

// notify the user when we allow (not block) a transaction
procedure TFrmMain.Notify(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction);
resourcestring
  RS_APPROVED_YOUR_TX = 'Approved your transaction';
begin
  FServer.apiKey(port)
    .ifErr(procedure(_: IError) begin Self.Notify(RS_APPROVED_YOUR_TX) end)
    .&else(procedure(apiKey: string)
    begin
      tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
      begin
        if not Assigned(changes) then
          Self.Notify(RS_APPROVED_YOUR_TX)
        else
          tx.From
            .ifErr(procedure(_: IError) begin Self.Notify(RS_APPROVED_YOUR_TX) end)
            .&else(procedure(from: TAddress)
            begin
              const item = (function(const outgoing: IAssetChanges): IAssetChange
              begin
                if Assigned(outgoing) then for var I := 0 to Pred(outgoing.Count) do
                  if (outgoing.Item(I).Change = Transfer) and (outgoing.Item(I).Amount > 0) then
                  begin
                    Result := outgoing.Item(I);
                    EXIT;
                  end;
                Result := nil;
              end)(changes.Outgoing(from));
              if not Assigned(item) then
                Self.Notify(RS_APPROVED_YOUR_TX)
              else
                item.&To.ToString(TWeb3.Create(common.Ethereum), procedure(name: string; err: IError)
                begin
                  Self.Notify(System.SysUtils.Format('Approved transfer of %s %s to %s', [item.Symbol, common.Format(item.Unscale), (function: string
                  begin
                    if Assigned(err) then
                      Result := string(item.&To)
                    else
                      Result := name;
                  end)()]));
                end, True);
            end);
      end);
    end);
end;

procedure TFrmMain.Dismiss;
begin
  thread.synchronize(procedure
  begin
    if Self.Visible then
    begin
      Self.Hide;
      Self.Notify('Securing your crypto wallet');
    end;
  end);
end;

function TfrmMain.GetChain: PChain;
begin
  if btnEthereum.IsPressed then
    Result := @web3.Ethereum
  else if btnGoerli.IsPressed then
    Result := @web3.Goerli
  else if btnPolygon.IsPressed then
    Result := @web3.Polygon
  else if btnArbitrum.IsPressed then
    Result := @web3.Arbitrum
  else if btnOptimism.IsPressed then
    Result := @web3.Optimism
  else
    Result := nil;
end;

procedure TFrmMain.ShowLogWindow;
begin
  if not Assigned(FFrmLog) then FFrmLog := TFrmLog.Create(Application);
  FFrmLog.Show;
end;

procedure TFrmMain.btnNetworkClick(Sender: TObject);
begin
  for var I := 0 to Pred(Self.ComponentCount) do
    if Self.Components[I] is TSpeedButton and (Self.Components[I] <> Sender) then
      TSpeedButton(Self.Components[I]).StaysPressed := False;

  TSpeedButton(Sender).StaysPressed := True;

  const chain = Self.GetChain;
  edtCopy.Visible := Assigned(chain);
  btnCopy.Text := 'Copy';
  btnCopy.Visible := Assigned(chain);
  btnDismiss.Visible := not Assigned(chain);

  if Assigned(chain) then edtCopy.Text := FServer.URL(FServer.port(chain^).Value);
end;

procedure TFrmMain.DoShow;
begin
  inherited DoShow;
  if common.Debug then ShowLogWindow;
end;

procedure TFrmMain.NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
begin
  FCanNotify := aIsGranted;
end;

procedure TFrmMain.DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
type
  TStep  = reference to procedure(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
  TSteps = array of TStep;
  TNext  = reference to procedure(const steps: TSteps; const index: Integer; const checked: TChecked; const block: TProc; const done: TProc);
begin
  if not Assigned(aPayload) then
  begin
    callback(True);
    EXIT;
  end;

  Self.Dismiss;

  if SameText(aPayload.Method, 'eth_sendRawTransaction') then
    if (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
      if Self.KnownTransactions.IndexOf(TJsonString(aPayload.Params[0]).Value) = -1 then
      begin
        const tx = decodeRawTransaction(web3.utils.fromHex(TJsonString(aPayload.Params[0]).Value));
        if tx.isOk then
        begin
          const chain = FServer.chain(aContext.Binding.Port);
          if Assigned(chain) then
          begin
            Self.KnownTransactions.Add(TJsonString(aPayload.Params[0]).Value);
            common.beforeTransaction;

            var next: TNext;
            next := procedure(const steps: TSteps; const index: Integer; const input: TChecked; const block: TProc; const done: TProc)
            begin
              if index >= Length(steps) then
                done
              else
                steps[index](FServer, aContext.Binding.Port, chain^, tx.Value, input, block, procedure(output: TChecked)
                begin
                  next(steps, index + 1, output, block, done)
                end);
            end;

            const done: TProc<Boolean> = procedure(allow: Boolean)
            begin
              common.afterTransaction;
              callback(allow);
            end;

            next([Step1, Step2, Step3, Step4, Step5, Step6, Step7, Step8, Step9], 0, [],
              procedure // block
              begin
                done(False);
              end,
              procedure // allow
              begin
                Self.Notify(aContext.Binding.Port, chain^, tx.Value);
                done(True);
              end);

            EXIT;
          end;
        end;
      end;

  callback(True);
end;

procedure TFrmMain.DoLog(const request: string; const response: string);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.Memo.Lines.BeginUpdate;
      try
        FFrmLog.Memo.Lines.Add('REQUEST : ' + request);
        FFrmLog.Memo.Lines.Add('RESPONSE: ' + response);
      finally
        FFrmLog.Memo.Lines.EndUpdate;
      end;
      FFrmLog.Memo.Model.CaretPosition := TCaretPosition.Create(FFrmLog.Memo.Model.Lines.Count - 1, 0);
    end);
end;

procedure TFrmMain.btnDismissClick(Sender: TObject);
begin
  Self.Dismiss;
end;

procedure TFrmMain.btnCopyClick(Sender: TObject);
begin
  var S: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, S) then
  begin
    const chain = Self.GetChain;
    if Assigned(chain) then
    begin
      S.SetClipboard(FServer.URL(FServer.port(chain^).Value));
      TButton(Sender).Text := 'Copied';
    end;
  end;
end;

end.
