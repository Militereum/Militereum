unit common;

interface

uses
  // Delphi
  System.Net.URLClient,
  System.SysUtils,
  // Indy
  IdGlobal,
  // web3
  web3,
  // project
  server;

const
  NUM_CHAINS = 5;
  LIMIT      = 5000; // USD

type
  TEthereumRPCServerHelper = class helper for TEthereumRPCServer
  public
    function chain(port: TIdPort): PChain;
    function port(chain: TChain): IResult<TIdPort>;
    function apiKey(port: TIdPort): IResult<string>;
    function endpoint(port: TIdPort): IResult<string>;
  end;

function Debug: Boolean;
function Ethereum: TChain;
function Format(value: Double): string;
function Headers: TNetHeaders;
procedure Open(const URL: string);
procedure Symbol(chain: TChain; token: TAddress; callback: TProc<string, IError>);

procedure initialize;
procedure finalize;

procedure beforeTransaction;
procedure afterTransaction;

implementation

uses
  // Delphi
  System.Classes,
{$IFDEF MACOS}
  common.mac,
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  WinAPI.ShellAPI,
  WinAPI.Windows,
  common.win,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  // web3
  web3.eth.alchemy,
  web3.eth.erc20;

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
    if endpoint.isOk then
      Result^.SetRPC(endpoint.Value);
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
    Result := TResult<TIdPort>.Err(0, System.SysUtils.Format('invalid chain: %s', [chain.Name]));
end;

function TEthereumRPCServerHelper.apiKey(port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_ETHEREUM)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_GOERLI)
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_POLYGON)
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_ARBITRUM)
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_OPTIMISM)
  else
    Result := TResult<string>.Err('', System.SysUtils.Format('invalid port: %d', [port]));
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
    Result := TResult<string>.Err('', System.SysUtils.Format('invalid port: %d', [port]));
end;

function Debug: Boolean;
begin
  Result := FindCmdLineSwitch('debug');
end;

function Ethereum: TChain;
begin
  Result := web3.Ethereum.SetRPC(web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM).Value);
end;

function Format(value: Double): string;
begin
  Result := System.SysUtils.Format('%.6f', [value]);
  while (Length(Result) > 0) and (Result[High(Result)] = '0') do
    Delete(Result, High(Result), 1);
  if (Length(Result) > 0) and (Result[High(Result)] = FormatSettings.DecimalSeparator) then
    Delete(Result, High(Result), 1);
end;

function Headers: TNetHeaders;
begin
  Result := [TNetHeader.Create('Content-Type', 'application/json')];
end;

procedure Open(const URL: string);
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  _system(PAnsiChar('open ' + AnsiString(URL)));
{$ENDIF POSIX}
end;

procedure Symbol(chain: TChain; token: TAddress; callback: TProc<string, IError>);
begin
  web3.eth.erc20.create(TWeb3.Create(chain), token).Symbol(callback);
end;

procedure initialize;
begin
{$IFDEF MACOS}
  common.mac.initialize;
{$ENDIF MACOS}
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

procedure beforeTransaction;
begin
{$IFDEF MACOS}
  common.mac.beforeTransaction;
{$ENDIF MACOS}
end;

procedure afterTransaction;
begin
{$IFDEF MACOS}
  common.mac.afterTransaction;
{$ENDIF MACOS}
end;

end.

