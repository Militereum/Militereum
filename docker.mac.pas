unit docker.mac;

interface

function supported: Boolean;
function installed: Boolean;
function installer: string;

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

end.
