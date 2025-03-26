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
  FMX.Menus,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // Indy
  IdContext,
  // web3
  web3,
  // project
  checks,
  demo,
  log,
  server,
  transaction;

type
  TFrmMain = class(TForm)
    btnDismiss: TButton;
    NC: TNotificationCenter;
    Grid: TGridPanelLayout;
    btnEthereum: TSpeedButton;
    btnHolesky: TSpeedButton;
    btnPolygon: TSpeedButton;
    btnArbitrum: TSpeedButton;
    btnOptimism: TSpeedButton;
    imgEthereum: TImage;
    imgHolesky: TImage;
    imgPolygon: TImage;
    imgArbitrum: TImage;
    imgOptimism: TImage;
    edtCopy: TEdit;
    btnCopy: TButton;
    lblTitle: TLabel;
    imgArbitrum1: TImage;
    imgOptimism1: TImage;
    imgPolygon1: TImage;
    imgHolesky1: TImage;
    imgEthereum1: TImage;
    btnSettings: TSpeedButton;
    pmSettings: TPopupMenu;
    mnuAutoRun: TMenuItem;
    imgSettings: TImage;
    lblHelp: TLabel;
    btnBase: TSpeedButton;
    imgBase: TImage;
    imgBase1: TImage;
    btnSepolia: TSpeedButton;
    imgSepolia: TImage;
    imgSepolia1: TImage;
    mnuShowTestNetworks: TMenuItem;
    Header: TGridPanelLayout;
    imgMilitereum: TImage;
    lblWelcome: TLabel;
    mnuDemo: TMenuItem;
    mnuLimit: TMenuItem;
    mnuApprove: TMenuItem;
    mnuSanctioned: TMenuItem;
    mnuUnverified: TMenuItem;
    mnuPhisher: TMenuItem;
    mnuSetApprovalForAll: TMenuItem;
    mnuSpam: TMenuItem;
    mnuHoneypot: TMenuItem;
    mnuUnsupported: TMenuItem;
    mnuNoDexPair: TMenuItem;
    mnuFirsttime: TMenuItem;
    mnuLowDexScore: TMenuItem;
    mnuAirdrop: TMenuItem;
    mnuCensorable: TMenuItem;
    mnuPausable: TMenuItem;
    mnuDormant: TMenuItem;
    mnuUnlock: TMenuItem;
    mnuDarkMode: TMenuItem;
    mnuVault: TMenuItem;
    mnuExploit: TMenuItem;
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnNetworkClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure mnuAutoRunClick(Sender: TObject);
    procedure lblHelpClick(Sender: TObject);
    procedure mnuShowTestNetworksClick(Sender: TObject);
    procedure mnuDarkModeClick(Sender: TObject);
  strict private
    FCanNotify: Boolean;
    FNotified : Boolean;
    FFirstTime: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    FAllowedTransactions: TStrings;
    FBlockedTransactions: TStrings;
    FShowTestNetworks: Boolean;
    FApproved: TArray<TApproval>;
    procedure Dismiss;
    procedure Log(const err: IError); overload;
    procedure Log(const line: TLine; const row: string); overload;
    procedure Notify; overload;
    function  Notify(const body: string): Boolean; overload;
    procedure ShowLogWindow;
    procedure SetShowTestNetworks(Value: Boolean);
  strict protected
    procedure BeforeTransaction(const chain: TChain; const tx: ITransaction);
    procedure AfterTransaction(const chain: TChain; const tx: ITransaction; const allowed: Boolean; const checked: TCustomChecks; const prompted: TPrompted);
    procedure DoShow; override;
    procedure DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>; const error: TProc<IError>);
    procedure DoLog(const request, response: string; const success: Boolean);
    function  AllowedTransactions: TStrings;
    function  BlockedTransactions: TStrings;
    function  IsAllowedTransaction(const params: string): Boolean;
    function  IsBlockedTransaction(const params: string): Boolean;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function GetChain: PChain;
    property ShowTestNetworks: Boolean read FShowTestNetworks write SetShowTestNetworks;
  end;

var
  FrmMain: TFrmMain = nil;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.Types,
  System.UITypes,
  // FireMonkey
  FMX.Dialogs,
  FMX.Platform,
  // web3
  web3.eth.simulate,
  web3.eth.types,
  web3.utils,
  // project
  common,
  docker,
  error,
  revoke,
  thread;

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

  FApproved         := [];
  FFirstTime        := True;
  FShowTestNetworks := True;

  Self.Caption := (function: string
  begin
    Result := Self.Caption + ' ' + common.AppVersion;
    if common.Demo then Result := Result + ' - Demo mode';
    if common.Debug then Result := Result + ' - Debug mode';
    if common.Simulate then Result := Result + ' - Simulate-only';
  end)();

  edtCopy.Visible := False;
  btnCopy.Visible := False;
  lblHelp.Visible := False;

  mnuDarkMode.IsChecked := common.DarkModeEnabled;

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

  if Assigned(FAllowedTransactions) then FAllowedTransactions.Free;
  if Assigned(FBlockedTransactions) then FBlockedTransactions.Free;

  inherited Destroy;
end;

function TFrmMain.AllowedTransactions: TStrings;
begin
  if not Assigned(FAllowedTransactions) then FAllowedTransactions := TStringList.Create;
  Result := FAllowedTransactions;
end;

function TFrmMain.BlockedTransactions: TStrings;
begin
  if not Assigned(FBlockedTransactions) then FBlockedTransactions := TStringList.Create;
  Result := FBlockedTransactions;
end;

function TFrmMain.IsAllowedTransaction(const params: string): Boolean;
begin
  Result := Self.AllowedTransactions.IndexOf(params) > -1;
end;

function TFrmMain.IsBlockedTransaction(const params: string): Boolean;
begin
  Result := Self.BlockedTransactions.IndexOf(params) > -1;
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
  else if btnHolesky.IsPressed then
    Result := @web3.Holesky
  else if btnSepolia.IsPressed then
    Result := @web3.Sepolia
  else if btnPolygon.IsPressed then
    Result := @web3.Polygon
  else if btnArbitrum.IsPressed then
    Result := @web3.Arbitrum
  else if btnOptimism.IsPressed then
    Result := @web3.Optimism
  else if btnBase.IsPressed then
    Result := @web3.Base
  else
    Result := nil;
end;

procedure TFrmMain.ShowLogWindow;
begin
  if not Assigned(FFrmLog) then FFrmLog := TFrmLog.Create(Application);
  FFrmLog.Show;
end;

procedure TFrmMain.SetShowTestNetworks(Value: Boolean);
begin
  if Value <> FShowTestNetworks then
  begin
    with Grid do if Value then ColumnCollection[1].Value := ColumnCollection[0].Value else ColumnCollection[1].Value := 0;
    with Grid do if Value then ColumnCollection[2].Value := ColumnCollection[0].Value else ColumnCollection[2].Value := 0;
    Self.ClientWidth := Round((function: Single
    begin
      Result := 2 * Grid.Position.X;
      for var I := 0 to Pred(Grid.ColumnCollection.Count) do Result := Result + Grid.ColumnCollection[I].Value;
    end)());
    FShowTestNetworks := Value;
  end;
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

  TSpeedButton(Sender).StaysPressed := not TSpeedButton(Sender).StaysPressed;
  updateImage(TSpeedButton(Sender));

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

//  update.latestRelease(procedure(tag: string)
//  begin
//    if common.ParseSemVer(tag) > common.ParseSemVer({$I Militereum.version}) then
//      thread.synchronize(procedure
//      begin
//        update.show(tag);
//      end);
//  end);

//  if docker.supported and not docker.installed then
//  begin
//    const frmDocker = TFrmDocker.Create(Application);
//    try
//      docker.callback := function: TFrmDocker begin Result := frmDocker; end;
//      try
//        frmDocker.ShowModal;
//      finally
//        docker.callback := nil;
//      end;
//    finally
//      frmDocker.Free;
//    end;
//  end;
end;

procedure TFrmMain.NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
begin
  FCanNotify := aIsGranted;
end;

procedure TFrmMain.BeforeTransaction(const chain: TChain; const tx: transaction.ITransaction);
begin
  common.beforeShowDialog;
  Self.Notify('Checking your transaction');
end;

procedure TFrmMain.AfterTransaction(
  const chain   : TChain;                   // the network the user is transacting on
  const tx      : transaction.ITransaction; // the transaction that passed through Militereum
  const allowed : Boolean;                  // True if the user allowed for the transaction, otherwise False
  const checked : TCustomChecks;            // reference to the checks that got performed on the transaction
  const prompted: TPrompted);               // the warnings the user got prompted with
begin
  common.afterShowDialog;
  if allowed then
  begin
    if TWarning.Approve in prompted then thread.lock(Self, procedure
    begin
      Self.FApproved := Self.FApproved + checked.Approved;
    end);
    // clean up after the approvals that aren't active anymore (eg. have been revoked)
    thread.lock(Self, procedure(done: TCallback)
    begin
      var next: TProc<Integer>;
      next := procedure(index: Integer)
      begin
        if index >= Length(Self.FApproved) then
          done
        else
          // is this allowance active? (eg. has not been revoked yet)
          Self.FApproved[index].Active(procedure(active: Boolean; err: IError)
          begin
            if active or Assigned(err) then
              next(index + 1)
            else try
              Delete(Self.FApproved, index, 1);
            finally
              next(index);
            end;
          end);
      end;
      next(0);
    end);
    // auto-revoke: https://medium.com/@svanas/introducing-auto-revoke-dba9f3222414
    tx.From.ifOk(procedure(from: TAddress)
    begin
      tx.ToIsEOA(chain, procedure(eoa: Boolean; err: IError)
      begin
        // did we transact with a smart contract? (not with an EOA)
        if not eoa then
        begin
          // did we previously approve this smart contract?
          const approved = thread.TLock.get<TArray<TApproval>>(Self, function: TArray<TApproval>
          begin
            Result := [];
            for var approval in Self.FApproved do
              if (approval.Chain = chain) and approval.Owner.SameAs(from) and approval.Spender.SameAs(tx.&To) then
                Result := Result + [approval];
          end);
          if Length(approved) > 0 then
            // is this allowance active? (eg. has not been revoked yet)
            approved[0].Active(procedure(active: Boolean; err: IError)
            begin
              if Assigned(err) or not active then
                { nothing to do }
              else begin
                common.beforeShowDialog;
                try
                  // prompt the user to revoke this spender/contract
                  thread.synchronize(procedure
                  begin
                    revoke.show(approved[0].Chain, approved[0].Token, approved[0].Spender, procedure(revoke: Boolean)
                    begin
                      if revoke then common.Open(System.SysUtils.Format('https://revoke.cash/address/%s?chainId=%d&spenderSearch=%s', [from.ToChecksum, chain.Id, approved[0].Spender.ToChecksum]));
                    end)
                  end)
                finally
                  common.afterShowDialog;
                end;
              end;
            end);
        end;
      end);
    end);
  end;
end;

procedure TFrmMain.DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>; const error: TProc<IError>);
type
  TNext = reference to procedure(const steps: TSteps; const index: Integer; const prompted: TPrompted; const done: TDone);
begin
  if not Assigned(aPayload) then
  begin
    callback(True);
    EXIT;
  end;

  Self.Dismiss;

  if (function: Boolean
  begin
    Result := docker.running;
//  Result := docker.installed and docker.running or (function: Boolean
//  begin
//    Result := docker.start;
//    if Result then
//    repeat
//      TThread.Sleep(100);
//    until docker.running;
//  end)();
  end)()
  and (docker.getContainerId(RPCh_CONTAINER_NAME) = '')
  and docker.pull(RPCh_DOCKER_IMAGE)
  and docker.run(RPCh_CONTAINER_NAME,
    '--pull always ' +
    '--platform=linux/amd64 ' +
    '-e FORCE_ZERO_HOP=true ' +
    '-e CLIENT=' + {$I keys/hopr.api.key} + ' ' +
    System.SysUtils.Format('-p %d:%d ', [RPCh_PORT_NUMBER, RPCh_PORT_NUMBER]) +
    '--rm ' + RPCh_DOCKER_IMAGE) then
    repeat
      TThread.Sleep(100);
    until docker.getContainerId(RPCh_CONTAINER_NAME) <> '';

  if SameText(aPayload.Method, 'eth_sendRawTransaction') then
    if (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
    begin
      const params = TJsonString(aPayload.Params[0]).Value;
      if IsAllowedTransaction(params) then
        callback(True)
      else if IsBlockedTransaction(params) then
        callback(False)
      else begin
        decodeRawTransaction(web3.utils.fromHex(params))
          .ifErr(procedure(err: IError) begin error(err) end)
          .&else(procedure(tx: transaction.ITransaction)
          begin
            const chain = FServer.chain(aContext.Binding.Port);
            if Assigned(chain) then
            begin
              Self.BeforeTransaction(chain^, tx);

              var next: TNext;
              next := procedure(const steps: TSteps; const index: Integer; const input: TPrompted; const done: TDone)
              begin
                if index >= Length(steps) then
                  done(input)
                else
                  steps[index](input, procedure(const output: TPrompted; const err: IError)
                  begin
                    if Assigned(err) then
                    begin
                      var ME: IMilitereumError;
                      if Supports(err, IMilitereumError, ME) then ME.Comment
                        .ifErr(procedure(_: IError)
                        begin
                          Self.Log(TLine.Info, ME.FuncName)
                        end)
                        .&else(procedure(comment: string)
                        begin
                          Self.Log(TLine.Info, System.SysUtils.Format('%s - %s', [ME.FuncName, comment]))
                        end);
                      Self.Log(err);
                    end;
                    next(steps, index + 1, output, done);
                  end);
              end;

              var checks: TChecks := nil;

              const done = procedure(const allow: Boolean; const prompted: TPrompted)
              begin
                if allow then Self.AllowedTransactions.Add(params) else Self.BlockedTransactions.Add(params);
                try
                  callback(allow);
                finally
                  Self.AfterTransaction(chain^, tx, allow, checks, prompted);
                  if Assigned(checks) then checks.Free;
                end;
                if (prompted <> []) and ((Self.AllowedTransactions.Count > 1) or (Self.BlockedTransactions.Count > 1)) then {show nag screen};
              end;

              checks := TChecks.Create(FServer, aContext.Binding.Port, chain^, tx,
                procedure(const prompted: TPrompted) // block
                begin
                  done(False, prompted);
                end, Self.Log);

              const steps = (function: TSteps
              begin
                Result := [checks.Step1, checks.Step2, checks.Step3, checks.Step4, checks.Step5, checks.Step6, checks.Step7, checks.Step8, checks.Step9, checks.Step10, checks.Step11, checks.Step12, checks.Step13, checks.Step14, checks.Step15, checks.Step16, checks.Step17, checks.Step18, checks.Step19, checks.Step20];
                if common.Simulate then
                begin
                  Result := Result + [checks.Fail];
                  FServer.apiKey(aContext.Binding.Port).ifOk(procedure(apiKey: string)
                  begin
                    tx.Simulate(apiKey, chain^, procedure(changes: IAssetChanges; _: IError)
                    begin
                      if Assigned(changes) then
                      begin
                        var S: IFMXClipboardService;
                        if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, S) then
                        begin
                          S.SetClipboard(changes.ToString);
                          Self.Notify('Copied your simulated transaction to the clipboard');
                        end;
                      end;
                    end);
                  end)
                end;
              end)();

              next(steps, 0, [],
                procedure(const prompted: TPrompted) // allow
                begin
                  Self.Notify(System.SysUtils.Format('Approved your transaction %s', [tx.Nonce.ToString]));
                  done(True, prompted);
                end);
            end;
          end);
      end;
      EXIT;
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
  Log(TLine.Error, err.Message);
end;

procedure TFrmMain.Log(const line: TLine; const row: string);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.Add(line, row);
    end);
end;

procedure TFrmMain.btnSettingsClick(Sender: TObject);
begin
  mnuShowTestNetworks.IsChecked := Self.ShowTestNetworks;
  mnuAutoRun.IsChecked := common.AutoRunEnabled;
  mnuDemo.Visible := common.Demo;
  const P = btnSettings.LocalToScreen(PointF(0, btnSettings.Height));
  pmSettings.Popup(P.X, P.Y);
end;

procedure TFrmMain.mnuShowTestNetworksClick(Sender: TObject);
begin
  mnuShowTestNetworks.IsChecked := not mnuShowTestNetworks.IsChecked;
  Self.ShowTestNetworks := mnuShowTestNetworks.IsChecked;
end;

procedure TFrmMain.mnuAutoRunClick(Sender: TObject);
begin
  mnuAutoRun.IsChecked := not mnuAutoRun.IsChecked;
  if mnuAutoRun.IsChecked then
    common.EnableAutoRun
  else
    common.DisableAutoRun;
end;

procedure TFrmMain.mnuDarkModeClick(Sender: TObject);
begin
  mnuDarkMode.IsChecked := not mnuDarkMode.IsChecked;
  if mnuDarkMode.IsChecked then
    common.EnableDarkMode
  else
    common.DisableDarkMode;
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
      lblHelp.Visible := True;
    end;
  end;
end;

end.
