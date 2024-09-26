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
  ITransaction = interface
    function Nonce: BigInteger;
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    procedure ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure EstimateGas(const chain: TChain; const callback: TProc<BigInteger, IError>);
    procedure Simulate(const apiKey: string; const chain: TChain; const callback: TProc<IAssetChanges, IError>);
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
  web3.eth.gas,
  web3.eth.tx,
  web3.rlp,
  web3.utils;

{ TTransaction }

type
  TTransaction = class(TInterfacedObject, ITransaction)
  private
    type
      TIsEOA = (Unknown, Yes, No);
    var
      FRaw      : TBytes;
      FNonce    : BigInteger;
      FTo       : TAddress;
      FToIsEOA  : TIsEOA;
      FValue    : TWei;
      FData     : TBytes;
      FEstimated: BigInteger;
      FSimulated: IAssetChanges;
  public
    constructor Create(const raw: TBytes; const nonce: BigInteger; const &to: TAddress; const value: TWei; const data: TBytes);
    function Nonce: BigInteger;
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    procedure ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
    procedure EstimateGas(const chain: TChain; const callback: TProc<BigInteger, IError>);
    procedure Simulate(const apiKey: string; const chain: TChain; const callback: TProc<IAssetChanges, IError>);
  end;

constructor TTransaction.Create(const raw: TBytes; const nonce: BigInteger; const &to: TAddress; const value: TWei; const data: TBytes);
begin
  Self.FRaw       := raw;
  Self.FNonce     := nonce;
  Self.FTo        := &to;
  Self.FToIsEOA   := Unknown;
  Self.FValue     := value;
  Self.FData      := data;
  Self.FEstimated := BigInteger.Zero;
  Self.FSimulated := nil;
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

procedure TTransaction.ToIsEOA(const chain: TChain; const callback: TProc<Boolean, IError>);
begin
  if FToIsEOA = Unknown then
  begin
    Self.&To.IsEOA(TWeb3.Create(chain), procedure(isEOA: Boolean; err: IError)
    begin
      if (err = nil) then if isEOA then Self.FToIsEOA := Yes else Self.FToIsEOA := No;
      callback(isEOA, err);
    end);
    EXIT;
  end;
  if FToIsEOA = Yes then callback(True, nil) else callback(False, nil);
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

procedure TTransaction.Simulate(const apiKey: string; const chain: TChain; const callback: TProc<IAssetChanges, IError>);
{$I keys/tenderly.api.key}
begin
  if Assigned(FSimulated) then
    callback(FSimulated, nil)
  else
    Self.From
      .ifErr(procedure(err: IError)
      begin
        callback(nil, TError.Create('cannot recover signer from signature: %s', [err.Message]))
      end)
      .&else(procedure(from: TAddress)
      begin
        web3.eth.simulate.simulate(apiKey, TENDERLY_ACCOUNT_ID, TENDERLY_PROJECT_ID, TENDERLY_ACCESS_KEY, chain, from, Self.&To, Self.Value, web3.utils.toHex(Self.Data), procedure(changes: IAssetChanges; err: IError)
        begin
          if (err = nil) then Self.FSimulated := changes;
          callback(changes, err);
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

  // EIP-1559 ['2', [signature]]
  if Length(decoded.Value) = 2 then
  begin
    const i0 = decoded.Value[0];
    const i1 = decoded.Value[1];
    if (Length(i0.Bytes) = 1) and (i0.Bytes[0] >= 2) and (i1.DataType = dtList) then
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
          toBigInt(signature.Value[1].Bytes),                          // nonce
          TAddress.Create(web3.utils.toHex(signature.Value[5].Bytes)), // recipient
          toBigInt(signature.Value[6].Bytes),                          // value
          signature.Value[7].Bytes                                     // data
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
        toBigInt(signature.Value[0].Bytes),                          // nonce
        TAddress.Create(web3.utils.toHex(signature.Value[3].Bytes)), // recipient
        toBigInt(signature.Value[4].Bytes),                          // value
        signature.Value[5].Bytes                                     // data
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
