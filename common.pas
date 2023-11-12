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
  web3.eth.etherscan,
  // project
  server;

const
  NUM_CHAINS = 7;
  LIMIT      = 5000; // USD

type
  TEthereumRPCServerHelper = class helper for TEthereumRPCServer
  public
    function chain(const port: TIdPort): PChain;
    function port(const chain: TChain): IResult<TIdPort>;
    function apiKey(const port: TIdPort): IResult<string>;
    function endpoint(const port: TIdPort): IResult<string>;
  end;

type
  TSemVer = record
  private
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
  public
    constructor Create(const aMajor, aMinor, aPatch: Integer);
    class operator Equal(const A, B: TSemVer): Boolean;
    class operator GreaterThan(const A, B: TSemVer): Boolean;
    class operator GreaterThanOrEqual(const A, B: TSemVer): Boolean;
  end;

function Debug: Boolean;
function Demo: Boolean;
function Ethereum: TChain;
function Etherscan(const chain: TChain): IResult<IEtherscan>;
function GetTempFileName: string;
function Headers: TNetHeaders;
procedure Open(const URL: string);
function ParseSemVer(const version: string): TSemVer;
procedure Symbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);

function AutoRunEnabled: Boolean;
procedure EnableAutoRun;
procedure DisableAutoRun;

procedure initialize;
procedure finalize;

procedure beforeTransaction;
procedure afterTransaction;

implementation

uses
  // Delphi
  System.Character,
  System.Classes,
  System.IOUtils,
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
  web3.eth.erc20,
  // project
  docker;

{$I keys/alchemy.api.key}
{$I keys/etherscan.api.key}

function TEthereumRPCServerHelper.chain(const port: TIdPort): PChain;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := @web3.Ethereum
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := @web3.Goerli
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := @web3.Sepolia
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := @web3.Polygon
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := @web3.Arbitrum
  else if (Self.Bindings.Count > 5) and (port = Self.Bindings[5].Port) then
    Result := @web3.Optimism
  else if (Self.Bindings.Count > 6) and (port = Self.Bindings[6].Port) then
    Result := @web3.Base
  else
    Result := nil;
  if Assigned(Result) then
  begin
    const endpoint = endpoint(port);
    if endpoint.isOk then
      Result^.SetRPC(endpoint.Value);
  end;
end;

function TEthereumRPCServerHelper.port(const chain: TChain): IResult<TIdPort>;
begin
  if (chain = web3.Ethereum) and (Self.Bindings.Count > 0) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[0].Port)
  else if (chain = web3.Goerli) and (Self.Bindings.Count > 1) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[1].Port)
  else if (chain = web3.Sepolia) and (Self.Bindings.Count > 2) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[2].Port)
  else if (chain = web3.Polygon) and (Self.Bindings.Count > 3) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[3].Port)
  else if (chain = web3.Arbitrum) and (Self.Bindings.Count > 4) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[4].Port)
  else if (chain = web3.Optimism) and (Self.Bindings.Count > 5) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[5].Port)
  else if (chain = web3.Base) and (Self.Bindings.Count > 6) then
    Result := TResult<TIdPort>.Ok(Self.Bindings[6].Port)
  else
    Result := TResult<TIdPort>.Err(0, System.SysUtils.Format('invalid chain: %s', [chain.Name]));
end;

function TEthereumRPCServerHelper.apiKey(const port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_ETHEREUM)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_GOERLI)
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_SEPOLIA)
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_POLYGON)
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_ARBITRUM)
  else if (Self.Bindings.Count > 5) and (port = Self.Bindings[5].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_OPTIMISM)
  else if (Self.Bindings.Count > 6) and (port = Self.Bindings[6].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_BASE)
  else
    Result := TResult<string>.Err('', System.SysUtils.Format('invalid port: %d', [port]));
end;

function TEthereumRPCServerHelper.endpoint(const port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM, core)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Goerli, ALCHEMY_API_KEY_GOERLI, core)
  else if (Self.Bindings.Count > 2) and (port = Self.Bindings[2].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Sepolia, ALCHEMY_API_KEY_SEPOLIA, core)
  else if (Self.Bindings.Count > 3) and (port = Self.Bindings[3].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Polygon, ALCHEMY_API_KEY_POLYGON, core)
  else if (Self.Bindings.Count > 4) and (port = Self.Bindings[4].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Arbitrum, ALCHEMY_API_KEY_ARBITRUM, core)
  else if (Self.Bindings.Count > 5) and (port = Self.Bindings[5].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Optimism, ALCHEMY_API_KEY_OPTIMISM, core)
  else if (Self.Bindings.Count> 6) and (port = Self.Bindings[6].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Base, ALCHEMY_API_KEY_BASE, core)
  else
    Result := TResult<string>.Err('', System.SysUtils.Format('invalid port: %d', [port]));
  if Result.isOk then
    if docker.getContainerId(RPCh_CONTAINER_NAME) <> '' then
      Result := TResult<string>.Ok(Self.URI(8080) + '/?exit-provider=' + Result.Value);
end;

constructor TSemVer.Create(const aMajor, aMinor, aPatch: Integer);
begin
  Self.Major := aMajor;
  Self.Minor := aMinor;
  Self.Patch := aPatch;
end;

class operator TSemVer.Equal(const A, B: TSemVer): Boolean;
begin
  Result := (A.Major = B.Major) and (A.Minor = B.Minor) and (A.Patch = B.Patch);
end;

class operator TSemVer.GreaterThan(const A, B: TSemVer): Boolean;
begin
  Result := (A.Major > B.Major)
        or ((A.Major = B.Major) and (A.Minor > B.Minor))
        or ((A.Major = B.Major) and (A.Minor = B.Minor) and (A.Patch > B.Patch));
end;

class operator TSemVer.GreaterThanOrEqual(const A, B: TSemVer): Boolean;
begin
  Result := (A > B) or (A = B);
end;

function Debug: Boolean;
begin
  Result := FindCmdLineSwitch('debug');
end;

function Demo: Boolean;
begin
  Result := FindCmdLineSwitch('demo');
end;

function Ethereum: TChain;
begin
  Result := web3.Ethereum.SetRPC(
    web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM, core).Value
  );
end;

function Etherscan(const chain: TChain): IResult<IEtherscan>;
begin
  if chain = web3.Ethereum then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_ETHEREUM))
  else if chain = web3.Goerli then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_GOERLI))
  else if chain = web3.Sepolia then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_SEPOLIA))
  else if chain = web3.Polygon then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_POLYGON))
  else if chain = web3.Arbitrum then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_ARBITRUM))
  else if chain = web3.Optimism then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_OPTIMISM))
  else if chain = web3.Base then
    Result := TResult<IEtherscan>.Ok(web3.eth.etherscan.create(chain, ETHERSCAN_API_KEY_BASE))
  else
    Result := TResult<IEtherscan>.Err(nil, System.SysUtils.Format('not supported on %s', [chain.Name]));
end;

function GetTempFileName: string;
begin
  Result := TPath.GetTempFileName;
  System.SysUtils.DeleteFile(Result);
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

function ParseSemVer(const version: string): TSemVer;
begin
  FillChar(Result, SizeOf(Result), 0);
  const SL = TStringList.Create;
  try
    SL.Delimiter := '.';
    SL.StrictDelimiter := True;
    SL.DelimitedText := version;
    for var i := 0 to Pred(SL.Count) do
    begin
      var S := SL[i];
      var n := Low(S);
      while n <= High(S) do
        if S[n].IsNumber then
          Inc(n)
        else
          if (S <> '') and S[Low(S)].IsNumber then
            Delete(S, n, Length(S) - n + 1)
          else
            Delete(S, n, 1);
      case I of
        0: Result.Major := StrToIntDef(S, 0);
        1: Result.Minor := StrToIntDef(S, 0);
        2: Result.Patch := StrToIntDef(S, 0);
      end;
    end;
  finally
    SL.Free;
  end;
end;

procedure Symbol(const chain: TChain; const token: TAddress; const callback: TProc<string, IError>);
begin
  web3.eth.erc20.create(TWeb3.Create(chain), token).Symbol(callback);
end;

function AutoRunEnabled: Boolean;
begin
{$IFDEF MACOS}
  Result := common.mac.autoRunEnabled;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := common.win.autoRunEnabled;
{$ENDIF MSWINDOWS}
end;

procedure EnableAutoRun;
begin
{$IFDEF MACOS}
  common.mac.enableAutoRun;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  common.win.enableAutoRun;
{$ENDIF MSWINDOWS}
end;

procedure DisableAutoRun;
begin
{$IFDEF MACOS}
  common.mac.disableAutoRun;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  common.win.disableAutoRun;
{$ENDIF MSWINDOWS}
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

