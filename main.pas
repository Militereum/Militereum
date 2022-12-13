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
  FMX.StdCtrls,
  FMX.Types,
  // Indy
  IdContext,
  IdCustomHTTPServer,
  // project
  log,
  server;

type
  TFrmMain = class(TForm)
    lblHeader: TLabel;
    btnDismiss: TButton;
    NC: TNotificationCenter;
    Grid: TGridPanelLayout;
    lblEthereum: TLabel;
    lblEthereumURL: TLabel;
    btnEthereum: TButton;
    lblGoerli: TLabel;
    lblGoerliURL: TLabel;
    btnGoerli: TButton;
    lblPolygon: TLabel;
    lblPolygonURL: TLabel;
    btnPolygon: TButton;
    lblArbitrum: TLabel;
    lblArbitrumURL: TLabel;
    btnArbitrum: TButton;
    lblOptimism: TLabel;
    lblOptimismURL: TLabel;
    btnOptimism: TButton;
    procedure btnCopyClick(Sender: TObject);
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnCopyMouseEnter(Sender: TObject);
    procedure btnCopyMouseLeave(Sender: TObject);
  private
    FCanNotify: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    procedure Dismiss;
    function GetURL(chainId: Integer): TLabel;
    procedure ShowLogWindow;
  protected
    procedure DoShow; override;
    procedure DoRPC(
      aContext: TIdContext;
      aPayload: IPayload;
      aResponseInfo: TIdHTTPResponseInfo;
      callback: TProc<TIdHTTPResponseInfo, Boolean>);
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
  // web3
  web3,
  web3.eth.tokenlists,
  web3.utils,
  // project
  approve,
  common,
  thread,
  transaction;

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

  const ports = server.ports(5);
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
    FServer.Active := False;
  finally
    FServer.Free;
  end;
  inherited Destroy;
end;

procedure TFrmMain.Dismiss;
begin
  thread.synchronize(procedure
  begin
    if Self.Visible then
    begin
      Self.Hide;
      if FCanNotify then
      begin
        const N = NC.CreateNotification;
        try
          N.AlertBody := 'Securing your crypto wallet';
          NC.PresentNotification(N);
        finally
          N.Free;
        end;
      end;
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

procedure TFrmMain.DoRPC(
  aContext: TIdContext;
  aPayload: IPayload;
  aResponseInfo: TIdHTTPResponseInfo;
  callback: TProc<TIdHTTPResponseInfo, Boolean>);
begin
  if not Assigned(aPayload) then
  begin
    callback(aResponseInfo, True);
    EXIT;
  end;

  Self.Dismiss;

  if  SameText(aPayload.Method, 'eth_sendRawTransaction')
  and (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
  begin
    const tx = decodeRawTransaction(web3.utils.fromHex(TJsonString(aPayload.Params[0]).Value));
    if tx.IsOk then
    begin
      const func = getTransactionFourBytes(tx.Value.Data);
      if func.IsOk then
        if SameText(fourBytestoHex(func.Value), '0x095EA7B3') then // approve(address,uint256)
        begin
          const args = getTransactionArgs(tx.Value.Data);
          if args.IsOk and (Length(args.Value) > 0) then
          begin
            const chain = FServer.chain(aContext.Binding.Port);
            if Assigned(chain) then
            begin
              web3.eth.tokenlists.token(chain^, tx.Value.&To, procedure(token: IToken; _: IError)
              begin
                if not Assigned(token) then
                begin
                  callback(aResponseInfo, True);
                  EXIT;
                end;
                thread.synchronize(procedure
                begin
                  approve.show(chain^, token, args.Value[0].ToAddress, args.Value[1].toUInt256,
                  procedure // block
                  begin
                    aResponseInfo.ResponseNo  := 405;
                    aResponseInfo.ContentText := Format('{"jsonrpc":"2.0","error":{"code":-32601,"message":"method not allowed"},"id":%s}', [aPayload.Id.ToString(10)]);
                    Self.DoLog(aPayload.ToString, aResponseInfo.ContentText);
                    callback(aResponseInfo, False);
                  end,
                  procedure // allow
                  begin
                    callback(aResponseInfo, True);
                  end);
                end);
              end);
              EXIT;
            end;
          end;
        end;
    end;
  end;

  callback(aResponseInfo, True);
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
