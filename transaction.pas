unit transaction;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.alchemy.api,
  web3.eth.types;

type
  TTransaction = record
  private
    Raw: TBytes;
    class function Empty: TTransaction; static;
  public
    Nonce: BigInteger;
    &To  : TAddress;
    Value: TWei;
    Data : TBytes;
    function From: IResult<TAddress>;
    constructor Create(raw: TBytes; nonce: BigInteger; &to: TAddress; value: TWei; data: TBytes);
    procedure Simulate(const apiKey: string; chain: TChain; callback: TProc<IAssetChanges, IError>);
  end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(encoded: TBytes): IResult<TTransaction>;

type
  TFourBytes = array[0..3] of Byte;

// input the transaction "data", returns the 4-byte function signature
function getTransactionFourBytes(data: TBytes): IResult<TFourBytes>;
function fourBytesToHex(const input: TFourBytes): string;

// input the transaction "data", returns the function arguments
function getTransactionArgs(data: TBytes): IResult<TArray<TArg>>;

implementation

uses
  // web3
  web3.eth.tx,
  web3.rlp,
  web3.utils;

{ TTransaction }

constructor TTransaction.Create(raw: TBytes; nonce: BigInteger; &to: TAddress; value: TWei; data: TBytes);
begin
  Self.Raw   := raw;
  Self.Nonce := nonce;
  Self.&To   := &to;
  Self.Value := value;
  Self.Data  := data;
end;

class function TTransaction.Empty: TTransaction;
begin
  FillChar(Result, 0, SizeOf(Result));
end;

function TTransaction.From: IResult<TAddress>;
begin
  Result := ecRecoverTransaction(Self.Raw);
end;

procedure TTransaction.Simulate(const apiKey: string; chain: TChain; callback: TProc<IAssetChanges, IError>);
begin
  const from = Self.From;
  if from.IsErr then
    callback(nil, TError.Create('cannot recover signer from signature: %s', [from.Error.Message]))
  else
    web3.eth.alchemy.api.simulate(apiKey, chain, from.Value, Self.&To, Self.Value, web3.utils.toHex(Self.Data), callback);
end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(encoded: TBytes): IResult<TTransaction>;

  function toBigInt(const bytes: TBytes): BigInteger; inline;
  begin
    if Length(bytes) = 0 then
      Result := BigInteger.Zero
    else
      Result := BigInteger.Create(web3.utils.toHex(bytes));
  end;

begin
  const decoded = web3.rlp.decode(encoded);
  if decoded.IsErr then
  begin
    Result := TResult<TTransaction>.Err(TTransaction.Empty, decoded.Error);
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
      if signature.IsErr then
      begin
        Result := TResult<TTransaction>.Err(TTransaction.Empty, signature.Error);
        EXIT;
      end;
      if Length(signature.Value) > 7 then
      begin
        Result := TResult<TTransaction>.Ok(TTransaction.Create(
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
    if signature.IsErr then
    begin
      Result := TResult<TTransaction>.Err(TTransaction.Empty, signature.Error);
      EXIT;
    end;
    if Length(signature.Value) > 5 then
    begin
      Result := TResult<TTransaction>.Ok(TTransaction.Create(
        encoded,                                                     // raw
        toBigInt(signature.Value[0].Bytes),                          // nonce
        TAddress.Create(web3.utils.toHex(signature.Value[3].Bytes)), // recipient
        toBigInt(signature.Value[4].Bytes),                          // value
        signature.Value[5].Bytes                                     // data
      ));
      EXIT;
    end;
  end;

  Result := TResult<TTransaction>.Err(TTransaction.Empty, 'unknown transaction encoding');
end;

// input the transaction "data", returns the 4-byte function signature
function getTransactionFourBytes(data: TBytes): IResult<TFourBytes>;
begin
  var func: TFourBytes;
  FillChar(func, SizeOf(func), 0);
  if Length(data) > 3 then
  begin
    Move(data[0], func[0], SizeOf(func));
    Result := TResult<TFourBytes>.Ok(func);
  end
  else
    Result := TResult<TFourBytes>.Err(func, 'no 4-byte function signature');
end;

function fourBytesToHex(const input: TFourBytes): string;
begin
  var buf: TBytes;
  SetLength(buf, 4);
  Move(input, buf[0], 4);
  Result := web3.utils.toHex(buf);
end;

// input the transaction "data", returns the function arguments
function getTransactionArgs(data: TBytes): IResult<TArray<TArg>>;
begin
  const func = getTransactionFourBytes(data);
  if func.IsErr then
  begin
    Result := TResult<TArray<TArg>>.Err([], func.Error);
    EXIT;
  end;
  Delete(data, 0, 4);
  var output: TArray<TArg> := [];
  while Length(data) >= 32 do
  begin
    SetLength(output, Length(output) + 1);
    Move(data[0], output[High(output)].Inner[0], 32);
    Delete(data, 0, 32);
  end;
  Result := TResult<TArray<TArg>>.Ok(output);
end;

end.
