unit server;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Indy
  IdContext,
  IdCustomHTTPServer,
  IdGlobal,
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
    procedure Forward(
      aContext: TIdContext;
      const aRequest: string;
      aResponseInfo: TIdHTTPResponseInfo);
  protected
    procedure DoCommandGet(
      aContext: TIdContext;
      aRequestInfo: TIdHTTPRequestInfo;
      aResponseInfo: TIdHTTPResponseInfo); override;
  public
    class function URL(port: TIdPort): string;
    property OnRPC: TOnRPC read FOnRPC write FOnRPC;
    property OnLog: TOnLog read FOnLog write FOnLog;
  end;

function ports(num: Integer): IResult<TArray<TIdPort>>;

function start: IResult<TEthereumRPCServer>; overload;
function start(port: TIdPort): IResult<TEthereumRPCServer>; overload;
function start(ports: TArray<TIdPort>): IResult<TEthereumRPCServer>; overload;

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

function ports(num: Integer): IResult<TArray<TIdPort>>;
begin
  var output: TArray<TIdPort> := [];
  var port := MAX_PORT_NO;
  while True do
  begin
    const server = TIdCustomHTTPServer.Create;
    try
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
            Result := TResult<TArray<TIdPort>>.Err(nil, TError.Create(E.Message));
            EXIT;
          end;
        end;
      end;
      if server.Active then
      try
        output := output + [server.DefaultPort];
        if Length(output) >= num then
        begin
          Result := TResult<TArray<TIdPort>>.Ok(output);
          EXIT;
        end;
        if server.DefaultPort > MIN_PORT_NO then
          port := port - 1
        else
        begin
          Result := TResult<TArray<TIdPort>>.Err(nil, Format('ports out of range %d..%d', [MIN_PORT_NO, MAX_PORT_NO]));
          EXIT;
        end;
      finally
        server.Active := False;
      end;
    finally
      server.Free;
    end;
  end;
end;

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

function start(port: TIdPort): IResult<TEthereumRPCServer>;
begin
  const server = TEthereumRPCServer.Create;
  server.DefaultPort := port;
  try
    server.Active := True;
  except
    on E: Exception do
    begin
      Result := TResult<TEthereumRPCServer>.Err(nil, TError.Create(E.Message));
      EXIT;
    end;
  end;
  Result := TResult<TEthereumRPCServer>.Ok(server);
end;

function start(ports: TArray<TIdPort>): IResult<TEthereumRPCServer>;
begin
  if Length(ports) = 0 then
  begin
    Result := TResult<TEthereumRPCServer>.Err(nil, 'nothing to do');
    EXIT;
  end;
  if Length(ports) = 1 then
  begin
    Result := start(ports[0]);
    EXIT;
  end;
  const server = TEthereumRPCServer.Create;
  for var I := 0 to High(ports) do server.Bindings.Add.Port := ports[I];
  try
    server.Active := True;
  except
    on E: Exception do
    begin
      Result := TResult<TEthereumRPCServer>.Err(nil, TError.Create(E.Message));
      EXIT;
    end;
  end;
  Result := TResult<TEthereumRPCServer>.Ok(server);
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

  if status = TForward.Allow then Self.Forward(aContext, payload, aResponseInfo);
end;

procedure TEthereumRPCServer.Forward(
  aContext: TIdContext;
  const aRequest: string;
  aResponseInfo: TIdHTTPResponseInfo);
begin
  const endpoint = Self.endpoint(aContext.Binding.Port);
  if endpoint.IsErr then
    aResponseInfo.ContentText := endpoint.Error.Message
  else begin
    const response = web3.http.post(endpoint.Value, aRequest, common.headers);
    if response.IsOk then
      aResponseInfo.ContentText := response.Value.ContentAsString(TEncoding.UTF8)
    else begin
      var err: IHttpError;
      if Supports(response.Error, IHttpError, err) then aResponseInfo.ResponseNo := err.StatusCode;
      aResponseInfo.ContentText := response.Error.Message;
    end;
  end;
  if Assigned(FOnLog) then FOnLog(aRequest, aResponseInfo.ContentText);
end;

class function TEthereumRPCServer.URL(port: TIdPort): string;
begin
  Result := Format('http://%s:%d', [IndyComputerName.ToLower, port]);
end;

end.
