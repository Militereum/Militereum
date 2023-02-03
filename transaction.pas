unit transaction;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.alchemy.api,
  web3.eth.types;

type
  ITransaction = interface
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    procedure ToEOA(chain: TChain; callback: TProc<Boolean, IError>);
    procedure Simulate(const apiKey: string; chain: TChain; callback: TProc<IAssetChanges, IError>);
  end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(encoded: TBytes): IResult<ITransaction>;

type
  TFourBytes = array[0..3] of Byte;

// input the transaction "data", returns the 4-byte function signature
function getTransactionFourBytes(const data: TBytes): IResult<TFourBytes>;
function fourBytesToHex(const input: TFourBytes): string;

// input the transaction "data", returns the function arguments
function getTransactionArgs(const data: TBytes): IResult<TArray<TArg>>;

implementation

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
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
      FRaw  : TBytes;
      FNonce: BigInteger;
      FTo   : TAddress;
      FToEOA: TIsEOA;
      FValue: TWei;
      FData : TBytes;
      FSimulated: IAssetChanges;
  public
    constructor Create(raw: TBytes; nonce: BigInteger; &to: TAddress; value: TWei; data: TBytes);
    function From : IResult<TAddress>;
    function &To  : TAddress;
    function Value: TWei;
    function Data : TBytes;
    procedure ToEOA(chain: TChain; callback: TProc<Boolean, IError>);
    procedure Simulate(const apiKey: string; chain: TChain; callback: TProc<IAssetChanges, IError>);
  end;

constructor TTransaction.Create(raw: TBytes; nonce: BigInteger; &to: TAddress; value: TWei; data: TBytes);
begin
  Self.FRaw   := raw;
  Self.FNonce := nonce;
  Self.FTo    := &to;
  Self.FToEOA := Unknown;
  Self.FValue := value;
  Self.FData  := data;
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

procedure TTransaction.ToEOA(chain: TChain; callback: TProc<Boolean, IError>);
begin
  if FToEOA = Unknown then
  begin
    Self.&To.IsEOA(TWeb3.Create(chain), procedure(isEOA: Boolean; err: IError)
    begin
      if (err = nil) then if isEOA then Self.FToEOA := Yes else Self.FToEOA := No;
      callback(isEOA, err);
    end);
    EXIT;
  end;
  if FToEOA = Yes then callback(True, nil) else callback(False, nil);
end;

procedure TTransaction.Simulate(const apiKey: string; chain: TChain; callback: TProc<IAssetChanges, IError>);
begin
  if Assigned(FSimulated) then
  begin
    callback(FSimulated, nil);
    EXIT;
  end;
  const from = Self.From;
  if from.IsErr then
  begin
    callback(nil, TError.Create('cannot recover signer from signature: %s', [from.Error.Message]));
    EXIT;
  end;
  web3.eth.alchemy.api.simulate(apiKey, chain, from.Value, Self.&To, Self.Value, web3.utils.toHex(Self.Data), procedure(changes: IAssetChanges; err: IError)
  begin
    Self.FSimulated := changes;
    callback(changes, err);
  end);
end;

// input the JSON-RPC "params", returns the transaction
function decodeRawTransaction(encoded: TBytes): IResult<ITransaction>;

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
    Result := TResult<ITransaction>.Err(nil, decoded.Error);
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
        Result := TResult<ITransaction>.Err(nil, signature.Error);
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
    if signature.IsErr then
    begin
      Result := TResult<ITransaction>.Err(nil, signature.Error);
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

  Result := TResult<ITransaction>.Err(nil, 'unknown transaction encoding');
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
function getTransactionArgs(const data: TBytes): IResult<TArray<TArg>>;
begin
  const func = getTransactionFourBytes(data);
  if func.IsErr then
  begin
    Result := TResult<TArray<TArg>>.Err([], func.Error);
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
