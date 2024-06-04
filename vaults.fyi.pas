unit vaults.fyi;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3;

type
  IToken = interface
    function Name: string;
    function Address: TAddress;
    function Symbol: string;
  end;

  IVault = interface
    function Name: string;
    function Address: TAddress;
    function TVL: BigInteger;
    function Token: IToken;
    function APY: Double; // 7-day avg
    function URL: string;
  end;

procedure network(const chain: TChain; const callback: TProc<string, IError>);
procedure vault(const network: string; const contract: TAddress; const callback: TProc<IVault, IError>);
procedure vaults(const network, symbol: string; const callback: TProc<TArray<TAddress>, IError>);
procedure better(const chain: TChain; const contract: TAddress; const callback: TProc<IVault, IError>);

implementation

uses
  // Delphi
  System.JSON,
  System.Net.URLClient,
  // web3
  web3.eth.types,
  web3.http,
  web3.json;

const VAULTS_API_BASE = 'https://api.vaults.fyi/v1/';

procedure network(const chain: TChain; const callback: TProc<string, IError>);
begin
  web3.http.get(VAULTS_API_BASE + 'networks', [TNetHeader.Create('accept', 'application/json')],
    procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;
      if not(response is TJsonArray) then
      begin
        callback('', TError.Create('response is not an array'));
        EXIT;
      end;
      for var network in response as TJsonArray do
        if getPropAsUInt64(network, 'chainId') = chain.Id then
        begin
          callback(getPropAsStr(network, 'name'), nil);
          EXIT;
        end;
      callback('', TError.Create('%s not supported', [chain.Name]));
    end);
end;

type
  TToken = class(TDeserialized, IToken)
    function Name: string;
    function Address: TAddress;
    function Symbol: string;
  end;

  function TToken.Name: string;
  begin
    Result := getPropAsStr(FJsonValue, 'name');
  end;

  function TToken.Address: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'assetAddress'));
  end;

  function TToken.Symbol: string;
  begin
    Result := getPropAsStr(FJsonValue, 'symbol');
  end;

type
  TVault = class(TDeserialized, IVault)
  public
    function Name: string;
    function Address: TAddress;
    function TVL: BigInteger;
    function Token: IToken;
    function APY: Double; // 7-day avg
    function URL: string;
  end;

  function TVault.Name: string;
  begin
    Result := getPropAsStr(FJsonValue, 'name');
  end;

  function TVault.Address: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'address'));
  end;

  function TVault.TVL: BigInteger;
  begin
    Result := getPropAsBigInt(FJsonValue, 'tvl');
  end;

  function TVault.Token: IToken;
  begin
    Result := TToken.Create(getPropAsObj(FJsonValue, 'token'));
  end;

  function TVault.APY: Double;
  begin
    Result := 0;
    const apy = getPropAsObj(FJsonValue, 'apy');
    if Assigned(apy) then
    begin
      Result := getPropAsInt(apy, '7day');
      if Result > 0 then Result := Result / 100;
    end;
  end;

  function TVault.URL: string;
  begin
    Result := Format('https://www.vaults.fyi/vaults/%s/%s', [getPropAsStr(FJsonValue, 'network'), getPropAsStr(FJsonValue, 'address')]);
  end;

procedure vault(const network: string; const contract: TAddress; const callback: TProc<IVault, IError>);
begin
  web3.http.get(VAULTS_API_BASE + Format('vaults/%s/%s', [network, contract.ToChecksum]), [TNetHeader.Create('accept', 'application/json')],
    procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      callback(TVault.Create(response), nil);
    end);
end;

procedure vaults(const network, symbol: string; const callback: TProc<TArray<TAddress>, IError>);
begin
  web3.http.get(VAULTS_API_BASE + Format('vaults?network=%s&token=%s', [network, symbol]), [TNetHeader.Create('accept', 'application/json')],
    procedure(response: TJsonValue; err: IError)
    begin
      if not(response is TJsonArray) then
      begin
        callback([], TError.Create('response is not an array'));
        EXIT;
      end;
      var result: TArray<TAddress> := [];
      try
        for var vault in response as TJsonArray do result := result + [TAddress.Create(getPropAsStr(vault, 'address'))];
      finally
        callback(result, nil);
      end;
    end);
end;

procedure better(const chain: TChain; const contract: TAddress; const callback: TProc<IVault, IError>);
type
  TNext = reference to procedure(const steps: TArray<TAddress>; const index: Integer);
begin
  // first of all, get the vaults.fyi network string
  network(chain, procedure(network: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // is our contract address in the vaults.fyi API?
    vault(network, contract, procedure(this: IVault; err: IError)
    begin
      if Assigned(err) or not Assigned(this) then
      begin
        callback(nil, nil); // vault does not exist
        EXIT;
      end;
      // if yes, compare the APY with the other vaults in the vaults.fyi API
      vaults(network, this.Token.Symbol, procedure(vaults: TArray<TAddress>; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        // if another vault provides for a higher APY while holding the same TVL (or more), return the better vault
        var next: TNext;
        next := procedure(const steps: TArray<TAddress>; const index: Integer)
        begin
          if index >= Length(steps) then
            callback(nil, nil)
          else
            if steps[index].SameAs(contract) then
              next(steps, index + 1)
            else
              vault(network, steps[index], procedure(that: IVault; err: IError)
              begin
                if Assigned(err) and not err.Message.Contains('does not exists on network') then
                begin
                  callback(nil, err);
                  EXIT;
                end;
                if Assigned(that) and (that.APY > this.APY) and (that.TVL >= this.TVL) then
                  callback(that, nil)
                else
                  next(steps, index + 1);
              end);
        end;
        next(vaults, 0);
      end);
    end);
  end);
end;

end.
