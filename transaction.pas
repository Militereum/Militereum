unit transaction;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.simulate,
  web3.eth.types;

type
  TTransactionType = (Legacy, eip1559, eip7702);

type
  ITransaction = interface
    function &Type: TTransactionType;
    function Nonce: BigInteger;
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    function  GetAuth: IResult<TArray<TAddress>>; // get the EIP-7702 authorizations
    procedure ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure ToIsVault(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure ToIsDeposit(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure EstimateGas(const chain: TChain; const callback: TProc<BigInteger, IError>);
    procedure Simulate(const chain: TChain; const callback: TProc<IAssetChanges, IError>);
  end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(const encoded: TBytes): IResult<ITransaction>;

type
  TFourBytes = array[0..3] of Byte;

// input the transaction "data", returns the 4-byte function signature
function getTransactionFourBytes(const data: TBytes): IResult<TFourBytes>;
function fourBytesToHex(const input: TFourBytes): string;

// input the transaction "data", returns the function arguments
function getTransactionArgs(const data: TBytes): IResult<TArray<TArg>>;

implementation

uses
  // web3
  web3.eth.etherscan,
  web3.eth.gas,
  web3.eth.tx,
  web3.rlp,
  web3.utils,
  // project
  cache,
  common;

{ TTransaction }

type
  TTransaction = class(TInterfacedObject, ITransaction)
  private
    type
      TTriState = (Unknown, Yes, No);
    var
      FRaw        : TBytes;
      FType       : TTransactionType;
      FNonce      : BigInteger;
      FTo         : TAddress;
      FToIsEOA    : TTriState;
      FToIsVault  : TTriState;
      FToIsDeposit: TTriState;
      FValue      : TWei;
      FData       : TBytes;
      FAuth       : TBytes;
      FEstimated  : BigInteger;
      FSimulated  : IAssetChanges;
  public
    constructor Create(const raw: TBytes; const &type: TTransactionType; const nonce: BigInteger; const &to: TAddress; const value: TWei; const data, auth: TBytes);
    function &Type: TTransactionType;
    function Nonce: BigInteger;
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    function  GetAuth: IResult<TArray<TAddress>>;
    procedure ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure ToIsVault(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure ToIsDeposit(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure EstimateGas(const chain: TChain; const callback: TProc<BigInteger, IError>);
    procedure Simulate(const chain: TChain; const callback: TProc<IAssetChanges, IError>);
  end;

constructor TTransaction.Create(const raw: TBytes; const &type: TTransactionType; const nonce: BigInteger; const &to: TAddress; const value: TWei; const data, auth: TBytes);
begin
  Self.FRaw         := raw;
  Self.FType        := &type;
  Self.FNonce       := nonce;
  Self.FTo          := &to;
  Self.FToIsEOA     := Unknown;
  Self.FToIsVault   := Unknown;
  Self.FToIsDeposit := Unknown;
  Self.FValue       := value;
  Self.FData        := data;
  Self.FAuth        := auth;
  Self.FEstimated   := BigInteger.Zero;
  Self.FSimulated   := nil;
end;

function TTransaction.&Type: TTransactionType;
begin
  Result := Self.FType;
end;

function TTransaction.Nonce: BigInteger;
begin
  Result := Self.FNonce;
end;

function TTransaction.From: IResult<TAddress>;
begin
  Result := ecRecoverTransaction(FRaw);
end;

function TTransaction.&To: TAddress;
begin
  Result := FTo;
end;

function TTransaction.Value: TWei;
begin
  Result := FValue;
end;

function TTransaction.Data: TBytes;
begin
  Result := FData;
end;

function TTransaction.GetAuth: IResult<TArray<TAddress>>;
begin
  if Length(FAuth) = 0 then
  begin
    Result := TResult<TArray<TAddress>>.Err('not an EIP-7702 transaction');
    EXIT;
  end;
  const authorizations = web3.rlp.decode(FAuth);
  if authorizations.isErr then
  begin
    Result := TResult<TArray<TAddress>>.Err(authorizations.Error);
    EXIT;
  end;
  if Length(authorizations.Value) = 0 then
  begin
    Result := TResult<TArray<TAddress>>.Err('not an EIP-7702 transaction');
    EXIT;
  end;
  var addresses: TArray<TAddress> := [];
  for var I := 0 to Pred(Length(authorizations.Value)) do
  begin
    const authorization = web3.rlp.decode(authorizations.Value[I].Bytes);
    if authorization.isErr then
    begin
      Result := TResult<TArray<TAddress>>.Err(authorization.Error);
      EXIT;
    end;
    if Length(authorization.Value) <> 6 then
    begin
      Result := TResult<TArray<TAddress>>.Err('not an EIP-7702 transaction');
      EXIT;
    end;
    addresses := addresses + [TAddress.Create(web3.utils.toHex(authorization.Value[1].Bytes))];
  end;
  Result := TResult<TArray<TAddress>>.Ok(addresses);
end;

procedure TTransaction.ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
begin
  if FToIsEOA = Unknown then
  begin
    Self.&To.IsEOA(TWeb3.Create(chain), procedure(isEOA: Boolean; err: IError)
    begin
      if err = nil then if isEOA then Self.FToIsEOA := Yes else Self.FToIsEOA := No;
      callback(isEOA, err);
    end);
    EXIT;
  end;
  callback(FToIsEOA = Yes, nil);
end;

procedure TTransaction.ToIsVault(const chain: TChain; const callback: TProc<Boolean, IError>);
begin
  if FToIsVault = Unknown then
  begin
    // step 1: are we transacting with an EOA? if yes, we cannot be transacting with a vault
    Self.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
    begin
      if isEOA or Assigned(err) then
      begin
        if not Assigned(err) then Self.FToIsVault := No;
        callback(not isEOA, err);
      end
      else
        // step 2: is this transaction calling a deposit() function? if yes, we are probably transacting with a vault
        Self.ToIsDeposit(chain, procedure(deposit: Boolean; err: IError)
        begin
          if deposit or Assigned(err) then
          begin
            if not Assigned(err) then Self.FToIsVault := Yes;
            callback(deposit, err);
          end
          else
            // step 3: get the contract ABI and determine if it is ERC4626 (a tokenized vaults standard) or not
            cache.getContractABI(chain, Self.&To, procedure(abi: IContractABI; err: IError)
            begin
              if not Assigned(err) then
                if Assigned(abi) and abi.IsERC4626 then
                  Self.FToIsVault := Yes
                else
                  Self.FToIsVault := No;
              callback(Assigned(abi) and abi.IsERC4626, err);
            end);
        end);
    end);
    EXIT;
  end;
  callback(FToIsVault = Yes, nil);
end;

procedure TTransaction.ToIsDeposit(const chain: TChain; const callback: TProc<Boolean, IError>);

  procedure GetToIsDeposit(const chain: TChain; const callback: TProc<Boolean, IError>);
  begin
    // step 1: are we transacting with an EOA? if yes, we cannot be depositing into a contract
    Self.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
    begin
      if isEOA or Assigned(err) then
      begin
        callback(False, err);
        EXIT;
      end;
      // step 2: get the function signature and compare it with a few hard-coded signatures we know about
      getTransactionFourBytes(Self.Data).into(procedure(func: TFourBytes; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(False, err);
          EXIT;
        end;
        // returns the first 4 (hex-encoded) bytes of a function signature after hashing
        const getSelector = function(const signature: string): string
        begin
          Result := web3.utils.toHex(Copy(web3.utils.sha3(web3.utils.toHex(signature)), 0, 4));
        end;
        // returns True if any of the function signatures match the function selector, otherwise False
        const isSelector = function(const func: TFourBytes; const signatures: TArray<string>): Boolean
        begin
          Result := False; for var sig in signatures do if SameText(fourBytestoHex(func), getSelector(sig)) then EXIT(True);
        end;
        // if the function signature equals one of the below hard-coded signatures, we are depositing into a contract
        callback(isSelector(func, [
          'deposit(address)', 'deposit(address,address)', 'deposit(address,uint256)', 'deposit(address,address,uint256)', 'deposit(address,uint256,address)',
          'deposit(uint256)', 'deposit(uint256,uint256)', 'deposit(uint256,address)', 'deposit(uint256,uint256,address)', 'deposit(uint256,address,uint256)']), nil);
      end);
    end);
  end;

begin
  if FToIsDeposit = Unknown then
  begin
    GetToIsDeposit(chain, procedure(deposit: Boolean; err: IError)
    begin
      if err = nil then if deposit then Self.FToIsDeposit := Yes else Self.FToIsDeposit := No;
      callback(deposit, err);
    end);
    EXIT;
  end;
  callback(FToIsDeposit = Yes, nil);
end;

procedure TTransaction.EstimateGas(const chain: TChain; const callback: TProc<BigInteger, IError>);
begin
  if FEstimated > BigInteger.Zero then
    callback(FEstimated, nil)
  else
    Self.From
      .ifErr(procedure(err: IError)
      begin
        callback(BigInteger.Zero, err)
      end)
      .&else(procedure(from: TAddress)
      begin
        web3.eth.gas.estimateGas(TWeb3.Create(chain), from, Self.&To, web3.utils.toHex(Self.Data), procedure(qty: BigInteger; err: IError)
        begin
          if (err = nil) then Self.FEstimated := qty;
          callback(qty, err);
        end);
      end)
end;

procedure TTransaction.Simulate(const chain: TChain; const callback: TProc<IAssetChanges, IError>);
{$I keys/tenderly.api.key}
begin
  if Assigned(FSimulated) then
    callback(FSimulated, nil)
  else
    common.AlchemyApiKey(chain)
      .ifErr(procedure(err: IError)
      begin
        callback(nil, TError.Create('cannot get Alchemy API key: %s', [err.Message]))
      end)
      .&else(procedure(ALCHEMY_API_KEY: string)
      begin
        Self.From
          .ifErr(procedure(err: IError)
          begin
            callback(nil, TError.Create('cannot recover signer from signature: %s', [err.Message]))
          end)
          .&else(procedure(from: TAddress)
          begin
            web3.eth.simulate.simulate(ALCHEMY_API_KEY, TENDERLY_ACCOUNT_ID, TENDERLY_PROJECT_ID, TENDERLY_ACCESS_KEY, chain, from, Self.&To, Self.Value, web3.utils.toHex(Self.Data), procedure(changes: IAssetChanges; err: IError)
            begin
              if (err = nil) then Self.FSimulated := changes;
              callback(changes, err);
            end);
          end);
      end);
end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(const encoded: TBytes): IResult<ITransaction>;

  function toBigInt(const bytes: TBytes): BigInteger; inline;
  begin
    if Length(bytes) = 0 then
      Result := BigInteger.Zero
    else
      Result := BigInteger.Create(web3.utils.toHex(bytes));
  end;

begin
  const decoded = web3.rlp.decode(encoded);
  if decoded.isErr then
  begin
    Result := TResult<ITransaction>.Err(decoded.Error);
    EXIT;
  end;

  // EIP-7702 ['4', [signature]]
  if Length(decoded.Value) = 2 then
  begin
    const i0 = decoded.Value[0];
    const i1 = decoded.Value[1];
    if (Length(i0.Bytes) = 1) and (i0.Bytes[0] = 4) and (i1.DataType = dtList) then
    begin
      const signature = web3.rlp.decode(i1.Bytes);
      if signature.isErr then
      begin
        Result := TResult<ITransaction>.Err(signature.Error);
        EXIT;
      end;
      if Length(signature.Value) > 9 then
      begin
        Result := TResult<ITransaction>.Ok(TTransaction.Create(
          encoded,                                                     // raw
          eip7702,                                                     // type
          toBigInt(signature.Value[1].Bytes),                          // nonce
          TAddress.Create(web3.utils.toHex(signature.Value[5].Bytes)), // recipient
          toBigInt(signature.Value[6].Bytes),                          // value
          signature.Value[7].Bytes,                                    // data
          signature.Value[9].Bytes                                     // auth
        ));
        EXIT;
      end;
    end;
  end;

  // EIP-1559 ['2', [signature]]
  if Length(decoded.Value) = 2 then
  begin
    const i0 = decoded.Value[0];
    const i1 = decoded.Value[1];
    if (Length(i0.Bytes) = 1) and (i0.Bytes[0] = 2) and (i1.DataType = dtList) then
    begin
      const signature = web3.rlp.decode(i1.Bytes);
      if signature.isErr then
      begin
        Result := TResult<ITransaction>.Err(signature.Error);
        EXIT;
      end;
      if Length(signature.Value) > 7 then
      begin
        Result := TResult<ITransaction>.Ok(TTransaction.Create(
          encoded,                                                     // raw
          eip1559,                                                     // type
          toBigInt(signature.Value[1].Bytes),                          // nonce
          TAddress.Create(web3.utils.toHex(signature.Value[5].Bytes)), // recipient
          toBigInt(signature.Value[6].Bytes),                          // value
          signature.Value[7].Bytes,                                    // data
          nil                                                          // auth
        ));
        EXIT;
      end;
    end;
  end;

  // Legacy transaction
  if (Length(decoded.Value) = 1) and (decoded.Value[0].DataType = dtList) then
  begin
    const signature = web3.rlp.decode(decoded.Value[0].Bytes);
    if signature.isErr then
    begin
      Result := TResult<ITransaction>.Err(signature.Error);
      EXIT;
    end;
    if Length(signature.Value) > 5 then
    begin
      Result := TResult<ITransaction>.Ok(TTransaction.Create(
        encoded,                                                     // raw
        Legacy,                                                      // type
        toBigInt(signature.Value[0].Bytes),                          // nonce
        TAddress.Create(web3.utils.toHex(signature.Value[3].Bytes)), // recipient
        toBigInt(signature.Value[4].Bytes),                          // value
        signature.Value[5].Bytes,                                    // data
        nil                                                          // auth
      ));
      EXIT;
    end;
  end;

  Result := TResult<ITransaction>.Err('unknown transaction encoding');
end;

// input the transaction "data", returns the 4-byte function signature
function getTransactionFourBytes(const data: TBytes): IResult<TFourBytes>;
begin
  var func: TFourBytes;
  FillChar(func, SizeOf(func), 0);
  if Length(data) > 3 then
  begin
    Move(data[0], func[0], SizeOf(func));
    Result := TResult<TFourBytes>.Ok(func);
  end
  else
    Result := TResult<TFourBytes>.Err('no 4-byte function signature');
end;

function fourBytesToHex(const input: TFourBytes): string;
begin
  var buf: TBytes;
  SetLength(buf, 4);
  Move(input, buf[0], 4);
  Result := web3.utils.toHex(buf);
end;

// input the transaction "data", returns the function arguments
function getTransactionArgs(const data: TBytes): IResult<TArray<TArg>>;
begin
  const func = getTransactionFourBytes(data);
  if func.isErr then
  begin
    Result := TResult<TArray<TArg>>.Err(func.Error);
    EXIT;
  end;
  var input : TBytes := Copy(data, 4, Length(data) - 4);
  var output: TArray<TArg> := [];
  while Length(input) >= 32 do
  begin
    SetLength(output, Length(output) + 1);
    Move(input[0], output[High(output)].Inner[0], 32);
    Delete(input, 0, 32);
  end;
  Result := TResult<TArray<TArg>>.Ok(output);
end;

end.
