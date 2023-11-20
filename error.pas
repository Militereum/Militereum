unit error;

interface

uses
  // web3;
  web3,
  // project
  checks;

type
  TComment = class(TCustomAttribute)
  strict private
    FValue: string;
  public
    constructor Create(const aValue: string);
    property Value: string read FValue;
  end;

  IMilitereumError = interface(IError)
  ['{535E852A-0D54-4523-A370-BE4576B38695}']
    function FuncName: string;
    function Comment : IResult<string>;
  end;

function wrap(const inner: IError; const step: TStep): IMilitereumError;

implementation

uses
  // Delphi
  System.Rtti;

{ TComment }

constructor TComment.Create(const aValue: string);
begin
  inherited Create;
  FValue := aValue;
end;

{ TMilitereumError }

type
  TMilitereumError = class(TError, IMilitereumError)
  private
    FFuncName: string;
    FComment : TComment;
  public
    constructor Create(const msg: string; const step: TStep);
    function FuncName: string;
    function Comment : IResult<string>;
  end;

constructor TMilitereumError.Create(const msg: string; const step: TStep);
begin
  inherited Create(msg);

  const context = TRttiContext.Create;
  try
    const T = context.GetType(TObject(System.TMethod(step).Data).ClassType);
    for var method in T.GetMethods do
      if method.CodeAddress = System.TMethod(step).Code then
      begin
        FFuncName := method.Name;
        FComment  := method.GetAttribute<TComment>;
        EXIT;
      end;
  finally
    context.Free;
  end;
end;

function TMilitereumError.FuncName: string;
begin
  Result := FFuncName;
end;

function TMilitereumError.Comment: IResult<string>;
begin
  if Assigned(FComment) then
    Result := TResult<string>.Ok(FComment.Value)
  else
    Result := TResult<string>.Err('', 'no comment');
end;

function wrap(const inner: IError; const step: TStep): IMilitereumError;
begin
  if Assigned(inner) then
    Result := TMilitereumError.Create(inner.Message, step)
  else
    Result := nil;
end;

end.
