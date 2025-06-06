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
function Simulate: Boolean;

function AppVersion: string;
function Base: TChain;
function Ethereum: TChain;
function Etherscan(const chain: TChain): IEtherscan;
function Format(const value: Double): string;
function GetTempFileName: string;
function Headers: TNetHeaders;
procedure Open(const URL: string);
function ParseSemVer(const version: string): TSemVer;

function AutoRunEnabled: Boolean;
procedure EnableAutoRun;
procedure DisableAutoRun;

function SystemIsDarkMode: Boolean;
function DarkModeEnabled: Boolean;
procedure EnableDarkMode;
procedure DisableDarkMode;

procedure initialize;
procedure finalize;

procedure beforeShowDialog;
procedure afterShowDialog;

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
  Posix.Unistd,
{$ENDIF POSIX}
  // web3
  web3.eth.alchemy,
  // project
  docker;

{$I keys/alchemy.api.key}

function TEthereumRPCServerHelper.chain(const port: TIdPort): PChain;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := @web3.Ethereum
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := @web3.Holesky
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
  else if (chain = web3.Holesky) and (Self.Bindings.Count > 1) then
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
    Result := TResult<TIdPort>.Err(System.SysUtils.Format('invalid chain: %s', [chain.Name]));
end;

function TEthereumRPCServerHelper.apiKey(const port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_ETHEREUM)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := TResult<string>.Ok(ALCHEMY_API_KEY_HOLESKY)
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
    Result := TResult<string>.Err(System.SysUtils.Format('invalid port: %d', [port]));
end;

function TEthereumRPCServerHelper.endpoint(const port: TIdPort): IResult<string>;
begin
  if (Self.Bindings.Count > 0) and (port = Self.Bindings[0].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM, core)
  else if (Self.Bindings.Count > 1) and (port = Self.Bindings[1].Port) then
    Result := web3.eth.alchemy.endpoint(web3.Holesky, ALCHEMY_API_KEY_HOLESKY, core)
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
    Result := TResult<string>.Err(System.SysUtils.Format('invalid port: %d', [port]));
  if Result.isOk then
    if docker.getContainerId(RPCh_CONTAINER_NAME) <> '' then
      Result := TResult<string>.Ok(Self.URI(RPCh_PORT_NUMBER) + '/?provider=' + Result.Value);
end;

function Debug: Boolean;
begin
  Result := FindCmdLineSwitch('debug');
end;

function Demo: Boolean;
begin
  Result := FindCmdLineSwitch('demo');
end;

function Simulate: Boolean;
begin
  Result := FindCmdLineSwitch('simulate');
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

function AppVersion: string;
begin
{$IFDEF MACOS}
  Result := common.mac.appVersion;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := common.win.appVersion;
{$ENDIF MSWINDOWS}
end;

function Base: TChain;
begin
  Result := web3.Base.SetRPC(
    web3.eth.alchemy.endpoint(web3.Base, ALCHEMY_API_KEY_BASE, core).Value
  );
end;

function Ethereum: TChain;
begin
  Result := web3.Ethereum.SetRPC(
    web3.eth.alchemy.endpoint(web3.Ethereum, ALCHEMY_API_KEY_ETHEREUM, core).Value
  );
end;

function Etherscan(const chain: TChain): IEtherscan;
begin
  Result := web3.eth.etherscan.create(chain, {$I keys/etherscan.api.key});
end;

function Format(const value: Double): string;
begin
  Result := System.SysUtils.Format('%.6f', [value]);
  while (Length(Result) > 0) and (Result[High(Result)] = '0') do
    Delete(Result, High(Result), 1);
  if (Length(Result) > 0) and (Result[High(Result)] = FormatSettings.DecimalSeparator) then
    Delete(Result, High(Result), 1);
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

function SystemIsDarkMode: Boolean;
begin
{$IFDEF MACOS}
  Result := common.mac.systemIsDarkMode;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  Result := common.win.systemIsDarkMode;
{$ENDIF MSWINDOWS}
end;

var bDarkModeEnabled: Boolean = False;

function DarkModeEnabled: Boolean;
begin
  Result := bDarkModeEnabled;
end;

procedure EnableDarkMode;
begin
{$IFDEF MACOS}
  common.mac.enableDarkMode;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  common.win.enableDarkMode;
{$ENDIF MSWINDOWS}
  bDarkModeEnabled := True;
end;

procedure DisableDarkMode;
begin
{$IFDEF MACOS}
  common.mac.disableDarkMode;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  common.win.disableDarkMode;
{$ENDIF MSWINDOWS}
  bDarkModeEnabled := False;
end;

procedure initialize;
begin
{$IFDEF MACOS}
  common.mac.initialize;
{$ENDIF MACOS}
{$IFDEF MSWINDOWS}
  common.win.initialize;
{$ENDIF MSWINDOWS}
  if SystemIsDarkMode then EnableDarkMode;
end;

procedure finalize;
begin
{$IFDEF MSWINDOWS}
  common.win.finalize;
{$ENDIF MSWINDOWS}
end;

procedure beforeShowDialog;
begin
{$IFDEF MACOS}
  common.mac.beforeShowDialog;
{$ENDIF MACOS}
end;

procedure afterShowDialog;
begin
{$IFDEF MACOS}
  common.mac.afterShowDialog;
{$ENDIF MACOS}
end;

end.

