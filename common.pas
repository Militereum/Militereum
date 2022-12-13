unit common;

interface

uses
  // Delphi
  System.Net.URLClient,
  // Indy
  IdGlobal,
  // web3
  web3,
  // project
  server;

type
  TEthereumRPCServerHelper = class helper for TEthereumRPCServer
  public
    function chain(port: TIdPort): PChain;
    function port(chain: TChain): IResult<TIdPort>;
    function endpoint(port: TIdPort): IResult<string>;
  end;

function debug: Boolean;
function headers: TNetHeaders;
procedure open(const URL: string);

procedure initialize;
procedure finalize;

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
{$IFDEF MSWINDOWS}
  WinAPI.ShellAPI,
  WinAPI.Windows,
  common.win,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  // web3
  web3.eth.alchemy;

{$I alchemy.api.key}

function TEthereumRPCServerHelper.chain(port: TIdPort): PChain;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := @web3.Ethereum
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := @web3.Goerli
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := @web3.Polygon
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := @web3.Arbitrum
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := @web3.Optimism
  else
    Result := nil;
  if Assigned(Result) then
  begin
    const endpoint = endpoint(port);
    if endpoint.IsOk then
      Result^.SetGateway(endpoint.Value);
  end;
end;

function TEthereumRPCServerHelper.port(chain: TChain): IResult<TIdPort>;
begin
  if (chain = web3.Ethereum) and (Self.Bindings.Count > 0) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[0].Port)
  else if (chain = web3.Goerli) and (Self.Bindings.Count > 1) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[1].Port)
  else if (chain = web3.Polygon) and (Self.Bindings.Count > 2) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[2].Port)
  else if (chain = web3.Arbitrum) and (Self.Bindings.Count > 3) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[3].Port)
  else if (chain = web3.Optimism) and (Self.Bindings.Count > 4) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[4].Port)
  else
    Result := TResult<TIdPort>.Err(0, Format('invalid chain: %s', [chain.Name]));
end;

function TEthereumRPCServerHelper.endpoint(port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Goerli, ALCHEMY_API_KEY_GOERLI)
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Polygon, ALCHEMY_API_KEY_POLYGON)
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Arbitrum, ALCHEMY_API_KEY_ARBITRUM)
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Optimism, ALCHEMY_API_KEY_OPTIMISM)
  else
    Result := TResult<string>.Err('', Format('invalid port: %d', [port]));
end;

function debug: Boolean;
begin
  Result := FindCmdLineSwitch('debug');
end;

function headers: TNetHeaders;
begin
  Result := [TNetHeader.Create('Content-Type', 'application/json')];
end;

procedure open(const URL: string);
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  _system(PAnsiChar('open ' + AnsiString(URL)));
{$ENDIF POSIX}
end;

procedure initialize;
begin
{$IFDEF MSWINDOWS}
  common.win.initialize;
{$ENDIF MSWINDOWS}
end;

procedure finalize;
begin
{$IFDEF MSWINDOWS}
  common.win.finalize;
{$ENDIF MSWINDOWS}
end;

end.
