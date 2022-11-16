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
    lblURL: TLabel;
    btnCopy: TButton;
    btnDismiss: TButton;
    NC: TNotificationCenter;
    procedure btnCopyClick(Sender: TObject);
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
  private
    FCanNotify: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    procedure Dismiss;
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
  end;

var
  FrmMain: TFrmMain;

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
begin
  inherited Create(aOwner);

  const server = server.start;
  if server.IsErr then
  begin
{$WARN SYMBOL_DEPRECATED OFF}
    MessageDlg('Cannot start HTTP server. The app will quit.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
{$WARN SYMBOL_DEPRECATED DEFAULT}
    Application.Terminate;
    EXIT;
  end;

  FServer := server.Value;
  FServer.OnRPC := DoRPC;
  FServer.OnLog := DoLog;

  lblURL.Text := FServer.URL;
  Self.Caption := Self.Caption + ' ' + VERSION;

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
          N.AlertBody := 'Securing your wallet on ' + FServer.URL;
          NC.PresentNotification(N);
        finally
          N.Free;
        end;
      end;
    end;
  end);
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
            web3.eth.tokenlists.token(common.Chain, tx.Value.&To, procedure(token: IToken; _: IError)
            begin
              if not Assigned(token) then
              begin
                callback(aResponseInfo, True);
                EXIT;
              end;
              thread.synchronize(procedure
              begin
                approve.show(token, args.Value[0].ToAddress,
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

procedure TFrmMain.btnCopyClick(Sender: TObject);
begin
  var service: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, service) then
    service.SetClipboard(FServer.URL);
end;

procedure TFrmMain.btnDismissClick(Sender: TObject);
begin
  Self.Dismiss;
end;

end.
