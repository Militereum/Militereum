unit docker.mac;

interface

function supported: Boolean;
function installed: Boolean;
function installer: string;
function running: Boolean;
function start: Boolean;
function pull(const image: string): Boolean;
function run(const name, command: string): Boolean;
function getContainerId(const name: string): string;
function stop(const containerId: string): Boolean;

implementation

function supported: Boolean;
begin
  Result := False;
end;

function installed: Boolean;
begin
  Result := False;
end;

function installer: string;
begin
{$IFDEF CPUARM}
  Result := 'https://desktop.docker.com/mac/main/arm64/Docker.dmg';
{$ELSE}
  Result := 'https://desktop.docker.com/mac/main/amd64/Docker.dmg';
{$ENDIF}
end;

function running: Boolean;
begin
  Result := False;
end;

function start: Boolean;
begin
  Result := False;
end;

function pull(const image: string): Boolean;
begin
  Result := False;
end;

function run(const name, command: string): Boolean;
begin
  Result := False;
end;

function getContainerId(const name: string): string;
begin
  Result := '';
end;

function stop(const containerId: string): Boolean;
begin
  Result := True;
end;

end.
