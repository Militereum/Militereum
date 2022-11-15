unit server;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Indy
  IdContext,
  IdCustomHTTPServer,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // project
  web3;

type
  IPayload = interface
    function Id: BigInteger;
    function Method: string;
    function Params: TJsonArray;
    function ToString: string;
  end;

  TOnRPC = procedure(
    aContext: TIdContext;
    aPayload: IPayload;
    aResponseInfo: TIdHTTPResponseInfo;
    callback: TProc<TIdHTTPResponseInfo, Boolean>) of object;
  TOnLog = procedure(const request, response: string) of object;

  TEthereumRPCServer = class(TIdCustomHTTPServer)
  private
    FOnRPC: TOnRPC;
    FOnLog: TOnLog;
    procedure Forward(const request: string; aResponseInfo: TIdHTTPResponseInfo);
  protected
    procedure DoCommandGet(
      aContext: TIdContext;
      aRequestInfo: TIdHTTPRequestInfo;
      aResponseInfo: TIdHTTPResponseInfo); override;
  public
    function URL: string;
    property OnRPC: TOnRPC read FOnRPC write FOnRPC;
    property OnLog: TOnLog read FOnLog write FOnLog;
  end;

function start: IResult<TEthereumRPCServer>;

implementation

uses
  // Delphi
  System.Classes,
  // Indy
  IdException,
  IdGlobalProtocols,
  // web3
  web3.http,
  web3.json,
  // project
  common;

const
  MAX_PORT_NO = 65535 - 1024;
  MIN_PORT_NO = 1024;

function start: IResult<TEthereumRPCServer>;
begin
  var port := MAX_PORT_NO;
  while True do
  begin
    const server = TEthereumRPCServer.Create;
    server.DefaultPort := port;
    try
      server.Active := True;
    except
      on E: Exception do
      begin
        if E is EIdCouldNotBindSocket and (server.DefaultPort > MIN_PORT_NO) then
          port := port - 1
        else
        begin
          Result := TResult<TEthereumRPCServer>.Err(nil, TError.Create(E.Message));
          EXIT;
        end;
      end;
    end;
    if not server.Active then
      server.Free
    else
    begin
      Result := TResult<TEthereumRPCServer>.Ok(server);
      EXIT;
    end;
  end;
end;

type
  TPayload = class(TInterfacedObject, IPayload)
  private
    FObject: TJsonObject;
  public
    function Id: BigInteger;
    function Method: string;
    function Params: TJsonArray;
    function ToString: string; override;
    constructor Create(aObject: TJsonValue);
    destructor Destroy; override;
  end;

constructor TPayload.Create(aObject: TJsonValue);
begin
  inherited Create;
  FObject := aObject.Clone as TJsonObject;
end;

destructor TPayload.Destroy;
begin
  if Assigned(FObject) then FObject.Free;
  inherited Destroy;
end;

function TPayload.Id: BigInteger;
begin
  Result := web3.json.getPropAsBigInt(FObject, 'id');
end;

function TPayload.Method: string;
begin
  Result := web3.json.getPropAsStr(FObject, 'method');
end;

function TPayload.Params: TJsonArray;
begin
  Result := web3.json.getPropAsArr(FObject, 'params');
end;

function TPayload.ToString: string;
begin
  Result := Format('{"jsonrpc":"2.0","method":"%s","params":%s,"id":%s}', [Self.Method, web3.json.marshal(Self.Params), Self.Id.ToString(10)]);
end;

{ TEthereumRPCServer }

procedure TEthereumRPCServer.DoCommandGet(
  aContext: TIdContext;
  aRequestInfo: TIdHTTPRequestInfo;
  aResponseInfo: TIdHTTPResponseInfo);
type
  TForward = (Allow, Wait, Block);
begin
  const payload = (function: string
  begin
    if not Assigned(aRequestInfo.PostStream) then
      EXIT;
    const SS = TStringStream.Create;
    try
      SS.CopyFrom(aRequestInfo.PostStream, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end)();

  var status := TForward.Allow;

  const &object = web3.json.unmarshal(payload);
  if Assigned(&object) then
  try
    if web3.json.getPropAsStr(&object, 'jsonrpc') <> '' then
      if Assigned(FOnRPC) then
      begin
        status := TForward.Wait;
        FOnRPC(aContext, TPayload.Create(&object), aResponseInfo, procedure(_: TIdHTTPResponseInfo; allow: Boolean)
        begin
          if allow then
            status := TForward.Allow
          else
            status := TForward.Block;
        end);
        while status = TForward.Wait do TThread.Sleep(500);
      end;
  finally
    &object.Free;
  end;

  if status = TForward.Allow then Self.Forward(payload, aResponseInfo);
end;

procedure TEthereumRPCServer.Forward(const request: string; aResponseInfo: TIdHTTPResponseInfo);
begin
  const response = web3.http.post(common.endpoint, request, common.headers);

  if response.IsErr then
  begin
    var err: IHttpError;
    if Supports(response.Error, IHttpError, err) then aResponseInfo.ResponseNo := err.StatusCode;
    aResponseInfo.ContentText := response.Error.Message;
  end
  else
    aResponseInfo.ContentText := response.Value.ContentAsString(TEncoding.UTF8);

  if Assigned(FOnLog) then FOnLog(request, aResponseInfo.ContentText);
end;

function TEthereumRPCServer.URL: string;
begin
  Result := Format('http://%s:%d', [IndyComputerName.ToLower, Self.DefaultPort]);
end;

end.
