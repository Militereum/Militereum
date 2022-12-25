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
    lblHeader: TLabel;
    btnDismiss: TButton;
    NC: TNotificationCenter;
    Grid: TGridPanelLayout;
    imgEthereum: TImage;
    lblEthereum: TLabel;
    lblEthereumURL: TLabel;
    btnEthereum: TButton;
    imgGoerli: TImage;
    lblGoerli: TLabel;
    lblGoerliURL: TLabel;
    btnGoerli: TButton;
    imgPolygon: TImage;
    lblPolygon: TLabel;
    lblPolygonURL: TLabel;
    btnPolygon: TButton;
    imgArbitrum: TImage;
    lblArbitrum: TLabel;
    lblArbitrumURL: TLabel;
    btnArbitrum: TButton;
    imgOptimism: TImage;
    lblOptimism: TLabel;
    lblOptimismURL: TLabel;
    btnOptimism: TButton;
    procedure btnCopyClick(Sender: TObject);
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnCopyMouseEnter(Sender: TObject);
    procedure btnCopyMouseLeave(Sender: TObject);
  strict private
    FCanNotify: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    procedure Dismiss;
    function GetURL(chainId: Integer): TLabel;
    procedure Notify(const body: string);
    procedure ShowLogWindow;
    procedure Step1(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
    procedure Step2(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
    procedure Step3(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
    procedure Step4(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
    procedure Step5(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
  strict protected
    procedure DoShow; override;
    procedure DoRPC(
      aContext: TIdContext;
      aPayload: IPayload;
      callback: TProc<Boolean>);
    procedure DoLog(const request, response: string);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    property URL[chainId: Integer]: TLabel read GetURL;
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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.defillama,
  web3.eth.breadcrumbs,
  web3.eth.tokenlists,
  web3.utils,
  // project
  approve,
  common,
  limit,
  sanctioned,
  thread,
  unverified;

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

  const ports = server.ports(NUM_CHAINS);
  if ports.IsErr then
  begin
    terminate;
    EXIT;
  end;

  const server = server.start(ports.Value);
  if server.IsErr then
  begin
    terminate;
    EXIT;
  end;

  FServer := server.Value;
  FServer.OnRPC := DoRPC;
  FServer.OnLog := DoLog;

  lblEthereumURL.Text := FServer.URL(FServer.port(web3.Ethereum).Value);
  lblGoerliURL.Text   := FServer.URL(FServer.port(web3.Goerli).Value);
  lblPolygonURL.Text  := FServer.URL(FServer.port(web3.Polygon).Value);
  lblArbitrumURL.Text := FServer.URL(FServer.port(web3.Arbitrum).Value);
  lblOptimismURL.Text := FServer.URL(FServer.port(web3.Optimism).Value);

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
  inherited Destroy;
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

function TFrmMain.GetURL(chainId: Integer): TLabel;
begin
  for var I := 0 to Pred(Self.ComponentCount) do
    if (Self.Components[I] is TLabel) and (TLabel(Self.Components[I]).Tag = chainId) then
    begin
      Result := TLabel(Self.Components[I]);
      EXIT;
    end;
  Result := nil;
end;

procedure TFrmMain.ShowLogWindow;
begin
  if not Assigned(FFrmLog) then FFrmLog := TFrmLog.Create(Application);
  FFrmLog.Show;
end;

procedure TFrmMain.DoShow;
begin
  inherited DoShow;
  if common.debug then ShowLogWindow;
end;

procedure TFrmMain.NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
begin
  FCanNotify := aIsGranted;
end;

// approve(address,uint256)
procedure TFrmMain.Step1(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
begin
  const func = getTransactionFourBytes(tx.Data);
  if func.IsOk and SameText(fourBytestoHex(func.Value), '0x095EA7B3') then
  begin
    const args = getTransactionArgs(tx.Data);
    if args.IsOk and (Length(args.Value) > 0) then
    begin
      const value = (function: BigInteger
      begin
        if Length(args.Value) > 1 then
          Result := args.Value[1].toUInt256
        else
          Result := web3.Infinite;
      end)();
      if value > 0 then
      begin
        web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; _: IError)
        begin
          if not Assigned(token) then
            next
          else
            thread.synchronize(procedure
            begin
              approve.show(chain, token, args.Value[0].ToAddress, value, callback);
            end);
        end);
        EXIT;
      end;
    end;
  end;
  next;
end;

// transfer(address,uint256)
procedure TFrmMain.Step2(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
begin
  const func = getTransactionFourBytes(tx.Data);
  if func.IsOk and SameText(fourBytestoHex(func.Value), '0xA9059CBB') then
  begin
    const args = getTransactionArgs(tx.Data);
    if args.IsOk and (Length(args.Value) > 1) then
    begin
      const quantity = args.Value[1].toUInt256;
      if quantity > 0 then
      begin
        web3.defillama.price(chain, tx.&To, procedure(price: Double; _: IError)
        begin
          const amount = quantity.AsInt64 * price;
          if amount < common.LIMIT then
            next
          else
            common.symbol(chain, tx.&To, procedure(symbol: string; _: IError)
            begin
              thread.synchronize(procedure
              begin
                limit.show(chain, symbol, args.Value[0].ToAddress, amount, callback);
              end);
            end);
        end);
        EXIT;
      end;
    end;
  end;
  next;
end;

// are we sending more than $5k in ETH, translated to USD?
procedure TFrmMain.Step3(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
begin
  if tx.Value > 0 then
  begin
    const client: IWeb3 = TWeb3.Create(chain);
    client.LatestPrice(procedure(price: Double; _: IError)
    begin
      const amount = tx.Value.AsInt64 * price;
      if amount < common.LIMIT then
        next
      else
        thread.synchronize(procedure
        begin
          limit.show(chain, chain.Symbol, tx.&To, amount, callback);
        end);
    end);
    EXIT;
  end;
  next;
end;

// are we transacting with (a) smart contract and (b) not verified with etherscan?
procedure TFrmMain.Step4(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
begin
  const isEOA = tx.&To.IsEOA(TWeb3.Create(chain));
  if isEOA.IsOk and not isEOA.Value then
  begin
    const etherscan = FServer.etherscan(port);
    if etherscan.IsOk then
    begin
      etherscan.Value.getContractSourceCode(tx.&To, procedure(src: string; _: IError)
      begin
        if src <> '' then
          next
        else
          thread.synchronize(procedure
          begin
            unverified.show(chain, tx.&To, callback);
          end);
      end);
      EXIT;
    end;
  end;
  next;
end;

// are we transacting with a sanctioned address?
procedure TFrmMain.Step5(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
begin
  web3.eth.breadcrumbs.sanctioned({$I breadcrumbs.api.key}, chain, tx.&To, procedure(value: Boolean; _: IError)
  begin
    if not value then
      next
    else
      thread.synchronize(procedure
      begin
        sanctioned.show(chain, tx.&To, callback);
      end);
  end);
end;

procedure TFrmMain.DoRPC(
  aContext: TIdContext;
  aPayload: IPayload;
  callback: TProc<Boolean>);
type
  TStep  = reference to procedure(port: TIdPort; chain: TChain; tx: TTransaction; callback: TProc<Boolean>; next: TProc);
  TSteps = array of TStep;
  TNext  = reference to procedure(steps: TSteps; index: Integer; callback: TProc<Boolean>; done: TProc);
begin
  if not Assigned(aPayload) then
  begin
    callback(True);
    EXIT;
  end;

  Self.Dismiss;

  if SameText(aPayload.Method, 'eth_sendRawTransaction') then
    if (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
    begin
      const tx = decodeRawTransaction(web3.utils.fromHex(TJsonString(aPayload.Params[0]).Value));
      if tx.IsOk then
      begin
        const chain = FServer.chain(aContext.Binding.Port);
        if Assigned(chain) then
        begin
          common.beforeTransaction;

          var next: TNext;
          next := procedure(steps: TSteps; index: Integer; callback: TProc<Boolean>; done: TProc)
          begin
            if index >= Length(steps) then
              done
            else
              steps[index](aContext.Binding.Port, chain^, tx.Value, callback, procedure
              begin
                next(steps, index + 1, callback, done)
              end);
          end;

          const done: TProc<Boolean> = procedure(allow: Boolean)
          begin
            common.afterTransaction;
            callback(allow);
          end;

          next([Step1, Step2, Step3, Step4, Step5], 0,
            procedure(allow: Boolean)
            begin
              done(allow);
            end,
            procedure
            begin
              Self.Notify('Approved your transaction');
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

procedure TFrmMain.btnCopyMouseEnter(Sender: TObject);
begin
  const L = Self.URL[TButton(Sender).Tag];
  if Assigned(L) then
    L.TextSettings.Font.Style := L.TextSettings.Font.Style + [TFontStyle.fsUnderline];
end;

procedure TFrmMain.btnCopyMouseLeave(Sender: TObject);
begin
  const L = Self.URL[TButton(Sender).Tag];
  if Assigned(L) then
    L.TextSettings.Font.Style := L.TextSettings.Font.Style - [TFontStyle.fsUnderline];
end;

procedure TFrmMain.btnCopyClick(Sender: TObject);
begin
  var S: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, S) then
  begin
    const L = Self.URL[TButton(Sender).Tag];
    if Assigned(L) then
      S.SetClipboard(L.Text);
  end;
end;

procedure TFrmMain.btnDismissClick(Sender: TObject);
begin
  Self.Dismiss;
end;

end.
