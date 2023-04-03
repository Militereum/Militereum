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
    const aContext: TIdContext;
    const aPayload: IPayload;
    const callback: TProc<Boolean>) of object;
  TOnLog = procedure(const request, response: string) of object;

  TEthereumRPCServer = class(TIdCustomHTTPServer)
  strict private
    FOnRPC: TOnRPC;
    FOnLog: TOnLog;
    procedure Block(
      const aPayload: IPayload;
      const aResponseInfo: TIdHTTPResponseInfo);
    procedure Forward(
      const aContext: TIdContext;
      const aRequest: string;
      const aResponseInfo: TIdHTTPResponseInfo);
  strict protected
    procedure DoCommandGet(
      aContext: TIdContext;
      aRequestInfo: TIdHTTPRequestInfo;
      aResponseInfo: TIdHTTPResponseInfo); override;
  public
    class function URL(const port: TIdPort): string;
    property OnRPC: TOnRPC read FOnRPC write FOnRPC;
    property OnLog: TOnLog read FOnLog write FOnLog;
  end;

function ports(num: Integer): IResult<TArray<TIdPort>>;

function start: IResult<TEthereumRPCServer>; overload;
function start(const port: TIdPort): IResult<TEthereumRPCServer>; overload;
function start(const ports: TArray<TIdPort>): IResult<TEthereumRPCServer>; overload;

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
          Result := TResult<TArray<TIdPort>>.Err(nil, System.SysUtils.Format('ports out of range %d..%d', [MIN_PORT_NO, MAX_PORT_NO]));
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

function start(const port: TIdPort): IResult<TEthereumRPCServer>;
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

function start(const ports: TArray<TIdPort>): IResult<TEthereumRPCServer>;
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
  strict private
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
  Result := System.SysUtils.Format('{"jsonrpc":"2.0","method":"%s","params":%s,"id":%s}', [Self.Method, web3.json.marshal(Self.Params), Self.Id.ToString(10)]);
end;

{ TEthereumRPCServer }

procedure TEthereumRPCServer.DoCommandGet(
  aContext: TIdContext;
  aRequestInfo: TIdHTTPRequestInfo;
  aResponseInfo: TIdHTTPResponseInfo);
type
  TForward = (Allow, Wait, Block);
begin
  const body = (function(const aRequestInfo: TIdHTTPRequestInfo): string
  begin
    Result := '';
    if not Assigned(aRequestInfo.PostStream) then
      EXIT;
    const SS = TStringStream.Create;
    try
      SS.CopyFrom(aRequestInfo.PostStream, 0);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end)(aRequestInfo);

  const &object = web3.json.unmarshal(body);
  if Assigned(&object) then
  try
    if web3.json.getPropAsStr(&object, 'jsonrpc') <> '' then
      if Assigned(FOnRPC) then
      begin
        const payload: IPayload = TPayload.Create(&object);

        var status := TForward.Wait;
        FOnRPC(aContext, payload, procedure(allow: Boolean)
        begin
          if allow then
            status := TForward.Allow
          else
            status := TForward.Block;
        end);
        while status = TForward.Wait do TThread.Sleep(500);

        if status = TForward.Block then
          Self.Block(payload, aResponseInfo)
        else
          Self.Forward(aContext, body, aResponseInfo);
      end;
  finally
    &object.Free;
  end;

  if Assigned(FOnLog) then FOnLog(body, aResponseInfo.ContentText);
end;

procedure TEthereumRPCServer.Block(
  const aPayload: IPayload;
  const aResponseInfo: TIdHTTPResponseInfo);
begin
  aResponseInfo.ResponseNo  := 405;
  aResponseInfo.ContentText := System.SysUtils.Format('{"jsonrpc":"2.0","error":{"code":-32601,"message":"method not allowed"},"id":%s}', [aPayload.Id.ToString(10)]);
end;

procedure TEthereumRPCServer.Forward(
  const aContext: TIdContext;
  const aRequest: string;
  const aResponseInfo: TIdHTTPResponseInfo);
begin
  const endpoint = Self.endpoint(aContext.Binding.Port);
  if endpoint.isErr then
    aResponseInfo.ContentText := endpoint.Error.Message
  else begin
    const response = web3.http.post(endpoint.Value, aRequest, common.Headers);
    if response.isOk then
      aResponseInfo.ContentText := response.Value.ContentAsString(TEncoding.UTF8)
    else begin
      var err: IHttpError;
      if Supports(response.Error, IHttpError, err) then aResponseInfo.ResponseNo := err.StatusCode;
      aResponseInfo.ContentText := response.Error.Message;
    end;
  end;
end;

class function TEthereumRPCServer.URL(const port: TIdPort): string;
begin
  Result := System.SysUtils.Format('http://%s:%d', [(function: string
  begin
    if IndyComputerName <> '' then
      Result := IndyComputerName.ToLower
    else
      Result := 'localhost';
  end)(), port]);
end;

end.
