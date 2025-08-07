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
  IAsset = interface
    function Name: string;
    function Address: TAddress;
    function Symbol: string;
  end;

  IVault = interface
    function Name: string;
    function Address: TAddress;
    function TVL: BigInteger;
    function Asset: IAsset;
    function APY: Double; // 7-day avg
    function URL: string;
    function Score: Double; // from 0 - 100
  end;

procedure network(const chain: TChain; const callback: TProc<string, IError>);
procedure vault(const network: string; const contract: TAddress; const callback: TProc<IVault, IError>);
procedure vaults(const network, symbol: string; const callback: TProc<TArray<IVault>, IError>);
procedure better(const chain: TChain; const contract: TAddress; const callback: TProc<IVault, IError>);

implementation

uses
  // Delphi
  System.JSON, System.Net.URLClient,
  // web3
  web3.eth.types, web3.http, web3.json;

const VAULTS_API_BASE = 'https://api.vaults.fyi/v2/';

procedure network(const chain: TChain; const callback: TProc<string, IError>);
begin
  web3.http.get(VAULTS_API_BASE + 'networks', [TNetHeader.Create('accept', 'application/json'), TNetHeader.Create('x-api-key', {$I keys/vaults.fyi.api.key})],
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
  TAsset = class(TDeserialized, IAsset)
    function Name: string;
    function Address: TAddress;
    function Symbol: string;
  end;

  function TAsset.Name: string;
  begin
    Result := getPropAsStr(FJsonValue, 'name');
  end;

  function TAsset.Address: TAddress;
  begin
    Result := TAddress.Create(getPropAsStr(FJsonValue, 'address'));
  end;

  function TAsset.Symbol: string;
  begin
    Result := getPropAsStr(FJsonValue, 'symbol');
  end;

type
  TVault = class(TDeserialized, IVault)
  public
    function Name: string;
    function Address: TAddress;
    function TVL: BigInteger;
    function Asset: IAsset;
    function APY: Double;
    function URL: string;
    function Score: Double;
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
    const tvl = getPropAsObj(FJsonValue, 'tvl');
    if Assigned(tvl) then
      Result := getPropAsBigInt(tvl, 'usd')
    else
      Result := 0;
  end;

  function TVault.Asset: IAsset;
  begin
    Result := TAsset.Create(getPropAsObj(FJsonValue, 'asset'));
  end;

  function TVault.APY: Double;
  begin
    Result := 0;
    const apy = getPropAsObj(FJsonValue, 'apy');
    if Assigned(apy) then
    begin
      const sevenDay = getPropAsObj(apy, '7day');
      if Assigned(sevenDay) then
        Result := getPropAsDouble(sevenDay, 'total');
      if Result > 0 then Result := Result * 100;
    end;
  end;

  function TVault.URL: string;
  begin
    Result := getPropAsStr(FJsonValue, 'lendUrl');
  end;

  function TVault.Score: Double;
  begin
    Result := 0;
    const score = getPropAsObj(FJsonValue, 'score');
    if Assigned(score) then
      Result := getPropAsDouble(score, 'vaultScore');
  end;

procedure vault(const network: string; const contract: TAddress; const callback: TProc<IVault, IError>);
begin
  web3.http.get(VAULTS_API_BASE + Format('detailed-vaults/%s/%s', [network, contract.ToChecksum]), [TNetHeader.Create('accept', 'application/json'), TNetHeader.Create('x-api-key', {$I keys/vaults.fyi.api.key})],
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

procedure vaults(const network, symbol: string; const callback: TProc<TArray<IVault>, IError>);
type
  TNext = reference to procedure(const page: Integer);
begin
  var next  : TNext;
  var result: TArray<IVault> := [];
  try
    next := procedure(const page: Integer)
    begin
      web3.http.get(VAULTS_API_BASE + Format('detailed-vaults?allowedNetworks=%s&allowedAssets=%s&page=%d&perPage=100', [network, symbol, page]), [TNetHeader.Create('accept', 'application/json'), TNetHeader.Create('x-api-key', {$I keys/vaults.fyi.api.key})],
        procedure(response: TJsonValue; err: IError)
        begin
          const data = getPropAsArr(response, 'data');
          if not Assigned(data) then
          begin
            callback([], TError.Create('data is not an array'));
            EXIT;
          end;
          for var vault in data do result := result + [TVault.Create(vault)];
          const page = getPropAsInt(response, 'nextPage');
          if page > 0 then
            next(page)
          else
            callback(result, nil);
        end);
    end;
  finally
    next(0);
  end;
end;

procedure better(const chain: TChain; const contract: TAddress; const callback: TProc<IVault, IError>);
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
      vaults(network, this.Asset.Symbol, procedure(vaults: TArray<IVault>; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        var best: IVault := nil;
        try
          // if another vault provides for a higher APY while holding the same TVL (or more), return the better vault
          for var that in vaults do if (not that.Address.SameAs(this.Address)) and (that.APY > this.APY) and (that.TVL >= this.TVL) then
          begin
            this := that;
            best := that;
          end;
        finally
          callback(best, nil);
        end;
      end);
    end);
  end);
end;

end.
