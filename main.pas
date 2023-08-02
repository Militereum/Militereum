unit main;

interface

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.Notification,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.Layouts,
  FMX.Menus,
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
    imgArbitrum1: TImage;
    imgOptimism1: TImage;
    imgPolygon1: TImage;
    imgGoerli1: TImage;
    imgEthereum1: TImage;
    btnSettings: TSpeedButton;
    pmSettings: TPopupMenu;
    mnuAutoRun: TMenuItem;
    imgSettings: TImage;
    lblHelp: TLabel;
    imgHelp: TImage;
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnNetworkClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure mnuAutoRunClick(Sender: TObject);
    procedure lblHelpClick(Sender: TObject);
  strict private
    FCanNotify: Boolean;
    FNotified : Boolean;
    FFirstTime: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    FKnownTransactions: TThreadList<string>;
    procedure Dismiss;
    procedure Log(const err: IError); overload;
    procedure Log(const info: string); overload;
    procedure Notify; overload;
    function  Notify(const body: string): Boolean; overload;
    procedure Notify(const port: TIdPort; const chain: TChain; const tx: ITransaction); overload;
    procedure ShowLogWindow;
  strict protected
    procedure DoShow; override;
    procedure DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
    procedure DoLog(const request, response: string; const success: Boolean);
    function  KnownTransactions: TThreadList<string>;
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
  System.JSON,
  System.Types,
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
  base,
  checks,
  common,
  docker,
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

  FFirstTime := True;
  Self.Caption := Self.Caption + ' ' + VERSION;

  edtCopy.Visible := False;
  btnCopy.Visible := False;
  imgHelp.Visible := False;
  lblHelp.Visible := False;

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

  const id = docker.getContainerId(RPCh_CONTAINER_NAME);
  if id <> '' then docker.stop(id);

  if Assigned(FKnownTransactions) then FKnownTransactions.Free;

  inherited Destroy;
end;

function TFrmMain.KnownTransactions: TThreadList<string>;
begin
  if not Assigned(FKnownTransactions) then FKnownTransactions := TThreadList<string>.Create;
  Result := FKnownTransactions;
end;

procedure TFrmMain.lblHelpClick(Sender: TObject);
begin
  common.Open('https://militereum.com/how-to-setup/');
end;

procedure TFrmMain.Notify;
begin
  FNotified := Self.Notify('Securing your crypto wallet');
end;

function TFrmMain.Notify(const body: string): Boolean;
begin
  Result := FCanNotify;
  if Result then
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
      Self.Notify;
    end;
    if not Self.FNotified then Self.Notify;
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

  procedure updateImage(const button: TSpeedButton);
  begin
    for var I := 0 to Pred(button.ChildrenCount) do
    begin
      const child = button.Children[I];
      if child is TImage then
        TImage(child).Visible := (button.StaysPressed and (TImage(child).Tag = 1))
                              or ((TImage(child).Tag = 0) and not button.StaysPressed);
    end;
  end;

begin
  for var I := 0 to Pred(Self.ComponentCount) do
    if Self.Components[I] is TSpeedButton and (Self.Components[I] <> Sender) then
    begin
      const other = TSpeedButton(Self.Components[I]);
      other.StaysPressed := False;
      updateImage(other);
    end;

  TSpeedButton(Sender).StaysPressed := True;
  updateImage(TSpeedButton(Sender));

  imgHelp.Visible := False;
  lblHelp.Visible := False;

  const chain = Self.GetChain;
  edtCopy.Visible := Assigned(chain);
  btnCopy.Text := 'Copy';
  btnCopy.Visible := Assigned(chain);
  btnDismiss.Visible := not Assigned(chain);

  if Assigned(chain) then edtCopy.Text := FServer.URI(FServer.port(chain^).Value);
end;

procedure TFrmMain.DoShow;
begin
  inherited DoShow;

  if FFirstTime then
    FFirstTime := False
  else
    EXIT;

  if common.Debug then ShowLogWindow;

  if docker.supported and not docker.installed then
  begin
    const frmDocker = TFrmDocker.Create(Application);
    try
      docker.callback := function: TFrmDocker begin Result := frmDocker; end;
      try
        frmDocker.ShowModal;
      finally
        docker.callback := nil;
      end;
    finally
      frmDocker.Free;
    end;
  end;
end;

procedure TFrmMain.NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
begin
  FCanNotify := aIsGranted;
end;

procedure TFrmMain.DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
type
  TStep  = reference to procedure(const server: TEthereumRPCServer; const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TNext; const log: TLog);
  TSteps = array of TStep;
  TNext  = reference to procedure(const steps: TSteps; const index: Integer; const checked: TChecked; const block: TProc; const done: TProc);
begin
  if not Assigned(aPayload) then
  begin
    callback(True);
    EXIT;
  end;

  Self.Dismiss;

  if docker.running then thread.lock(Self, procedure
  begin
    if docker.getContainerId(RPCh_CONTAINER_NAME) = '' then
      if docker.pull(RPCh_DOCKER_IMAGE) then
        if docker.run(RPCh_CONTAINER_NAME, '-e RESPONSE_TIMEOUT=10000 ' +
          '-e DISCOVERY_PLATFORM_API_ENDPOINT=https://production.discovery.rpch.tech ' +
          '-e PORT=8080 ' +
          '-e DATA_DIR=app ' +
          '-e CLIENT=' + {$I hopr.api.key} + ' ' +
          '-p 8080:8080 ' +
          '--rm ' + RPCh_DOCKER_IMAGE) then
          repeat
            TThread.Sleep(100);
          until docker.getContainerId(RPCh_CONTAINER_NAME) <> '';
  end);

//  if docker.installed then thread.lock(Self, procedure
//  begin
//    if docker.running or (function: Boolean
//    begin
//      Result := docker.start;
//      if Result then
//      repeat
//        TThread.Sleep(100);
//      until docker.running;
//    end)() then
//    if docker.getContainerId(RPCh_CONTAINER_NAME) = '' then
//      if docker.pull(RPCh_DOCKER_IMAGE) then
//        if docker.run(RPCh_CONTAINER_NAME, '-e RESPONSE_TIMEOUT=10000 ' +
//          '-e DISCOVERY_PLATFORM_API_ENDPOINT=https://production.discovery.rpch.tech ' +
//          '-e PORT=8080 ' +
//          '-e DATA_DIR=app ' +
//          '-e CLIENT=' + {$I hopr.api.key} + ' ' +
//          '-p 8080:8080 ' +
//          '--rm ' + RPCh_DOCKER_IMAGE) then
//          repeat
//            TThread.Sleep(100);
//          until docker.getContainerId(RPCh_CONTAINER_NAME) <> '';
//  end);

  if SameText(aPayload.Method, 'eth_sendRawTransaction') then
    if (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
      if (function(const tx: string): Integer
      begin
        const L = Self.KnownTransactions.LockList;
        try
          Result := L.IndexOf(TJsonString(aPayload.Params[0]).Value);
        finally
          Self.KnownTransactions.UnlockList;
        end;
      end)(TJsonString(aPayload.Params[0]).Value) = -1 then
      begin
        const tx = decodeRawTransaction(web3.utils.fromHex(TJsonString(aPayload.Params[0]).Value));
        if tx.isOk then
        begin
          const chain = FServer.chain(aContext.Binding.Port);
          if Assigned(chain) then
          begin
            Self.KnownTransactions.Add(TJsonString(aPayload.Params[0]).Value);

            thread.lock(Self, procedure
            begin
              common.beforeTransaction;

              var next: TNext;
              next := procedure(const steps: TSteps; const index: Integer; const input: TChecked; const block: TProc; const done: TProc)
              begin
                if index >= Length(steps) then
                  done
                else
                  steps[index](FServer, aContext.Binding.Port, chain^, tx.Value, input, block, procedure(const output: TChecked; const err: IError)
                  begin
                    if Assigned(err) then Log(err);
                    next(steps, index + 1, output, block, done)
                  end, Self.Log);
              end;

              const done: TProc<Boolean> = procedure(allow: Boolean)
              begin
                common.afterTransaction;
                callback(allow);
              end;

              next([Step1, Step2, Step3, Step4, Step5, Step6, Step7, Step8, Step9, Step10, Step11, Step12, Step13], 0, [],
                procedure // block
                begin
                  done(False);
                end,
                procedure // allow
                begin
                  Self.Notify(aContext.Binding.Port, chain^, tx.Value);
                  done(True);
                end);
            end);

            EXIT;
          end;
        end;
      end;

  callback(True);
end;

procedure TFrmMain.DoLog(const request, response: string; const success: Boolean);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.BeginUpdate;
      try
        FFrmLog.Add(TLine.Request, request);
        if success then
          FFrmLog.Add(TLine.Response, response)
        else
          FFrmLog.Add(TLine.Error, response);
      finally
        FFrmLog.EndUpdate;
      end;
    end);
end;

procedure TFrmMain.Log(const err: IError);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.Add(TLine.Error, err.Message);
    end);
end;

procedure TFrmMain.Log(const info: string);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.Add(TLine.Info, info);
    end);
end;

procedure TFrmMain.btnSettingsClick(Sender: TObject);
begin
  mnuAutoRun.IsChecked := common.AutoRunEnabled;
  const P = btnSettings.LocalToScreen(PointF(0, btnSettings.Height));
  pmSettings.Popup(P.X, P.Y);
end;

procedure TFrmMain.mnuAutoRunClick(Sender: TObject);
begin
  mnuAutoRun.IsChecked := not mnuAutoRun.IsChecked;
  if mnuAutoRun.IsChecked then
    common.EnableAutoRun
  else
    common.DisableAutoRun;
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
      S.SetClipboard(FServer.URI(FServer.port(chain^).Value));
      TButton(Sender).Text := 'Copied';
      imgHelp.Visible := True;
      lblHelp.Visible := True;
    end;
  end;
end;

end.
