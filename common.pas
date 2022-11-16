unit common;

interface

uses
  // Delphi
  System.Net.URLClient,
  // web3
  web3;

function chain: TChain;
function debug: Boolean;
function endpoint: string;
function headers: TNetHeaders;
procedure open(const URL: string);

implementation

uses
  // Delphi
  System.SysUtils,
{$IFDEF MSWINDOWS}
  WinAPI.ShellAPI,
  WinAPI.Windows,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  // web3
  web3.eth.infura;

{$I infura.api.key}

function chain: TChain;
begin
{$IFDEF DEBUG}
  Result := Goerli;
{$ELSE}
  Result := Ethereum;
{$ENDIF}
end;

function debug: Boolean;
begin
  Result := FindCmdLineSwitch('debug');
end;

function endpoint: string;
begin
  Result := web3.eth.infura.endpoint(chain, INFURA_API_KEY).Value;
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

end.
