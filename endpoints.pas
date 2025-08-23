unit endpoints;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

const
  ID_THE_BANNED_LIST = 5;

procedure getEndpoint(const ID: Integer; const callback: TProc<string, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections, System.JSON,
  // web3
  web3.http, web3.json;

var
  cache: TDictionary<Integer, string>;

procedure getEndpoint(const ID: Integer; const callback: TProc<string, IError>);
begin
  var value: string := '';
  if cache.TryGetValue(ID, value) and (value <> '') then
    callback(value, nil)
  else
    web3.http.get('https://raw.githubusercontent.com/Militereum/Militereum/refs/heads/main/endpoints.json', [], procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;
      const endpoints = getPropAsArr(response, 'endpoints');
      if not Assigned(endpoints) then
      begin
        callback('', TError.Create('endpoints does not exist'));
        EXIT;
      end;
      for var endpoint in endpoints do
        if getPropAsInt(endpoint, 'id') = ID then
        begin
          const URL = getPropAsStr(endpoint, 'url');
          if URL <> '' then
          begin
            cache.AddOrSetValue(ID, URL);
            callback(URL, nil);
          end;
        end;
    end);
end;

initialization
  cache := TDictionary<Integer, string>.Create;

finalization
  if Assigned(cache) then cache.Free;

end.
