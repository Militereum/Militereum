unit main;

interface

uses
  // Delphi
  System.Classes,
  System.Notification,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Forms,
  FMX.Layouts,
  FMX.Objects,
  FMX.StdCtrls,
  FMX.Types,
  // Indy
  IdContext,
  IdGlobal,
  // web3
  web3,
  web3.eth.alchemy.api,
  web3.eth.etherscan,
  // project
  log,
  server,
  transaction;

type
  TChecked = set of TChangeType;

type
  TFrmMain = class(TForm)
    lblHeader: TLabel;
    btnDismiss: TButton;
    NC: TNotificationCenter;
    Grid: TGridPanelLayout;
    imgEthereum: TImage;
    lblEthereum: TLabel;
    lblEthereumURL: TLabel;
    btnEthereum: TButton;
    imgGoerli: TImage;
    lblGoerli: TLabel;
    lblGoerliURL: TLabel;
    btnGoerli: TButton;
    imgPolygon: TImage;
    lblPolygon: TLabel;
    lblPolygonURL: TLabel;
    btnPolygon: TButton;
    imgArbitrum: TImage;
    lblArbitrum: TLabel;
    lblArbitrumURL: TLabel;
    btnArbitrum: TButton;
    imgOptimism: TImage;
    lblOptimism: TLabel;
    lblOptimismURL: TLabel;
    btnOptimism: TButton;
    procedure btnCopyClick(Sender: TObject);
    procedure btnDismissClick(Sender: TObject);
    procedure NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
    procedure btnCopyMouseEnter(Sender: TObject);
    procedure btnCopyMouseLeave(Sender: TObject);
  strict private
    FCanNotify: Boolean;
    FFrmLog: TFrmLog;
    FServer: TEthereumRPCServer;
    procedure Dismiss;
    function GetURL(chainId: Integer): TLabel;
    procedure Notify(const body: string); overload;
    procedure Notify(port: TIdPort; chain: TChain; tx: ITransaction); overload;
    procedure ShowLogWindow;
    procedure Step1(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step2(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step3(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step4(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step5(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step6(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step7(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step8(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Step9(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
    procedure Block(port: TIdPort; chain: TChain; tx: ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
  strict protected
    procedure DoShow; override;
    procedure DoRPC(aContext: TIdContext; aPayload: IPayload; callback: TProc<Boolean>);
    procedure DoLog(const request, response: string);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    property URL[chainId: Integer]: TLabel read GetURL;
  end;

var
  FrmMain: TFrmMain = nil;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.UITypes,
  // FireMonkey
  FMX.Dialogs,
  FMX.Platform,
  FMX.Text,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.defillama,
  web3.eth.breadcrumbs,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.utils,
  // project
  airdrop,
  approve,
  common,
  firsttime,
  limit,
  sanctioned,
  spam,
  thread,
  untransferable,
  unverified;

{$I Militereum.version}

{ TFrmMain }

constructor TFrmMain.Create(aOwner: TComponent);

  procedure terminate;
  begin
{$WARN SYMBOL_DEPRECATED OFF}
    MessageDlg('Cannot start HTTP server. The app will quit.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
{$WARN SYMBOL_DEPRECATED DEFAULT}
    Application.Terminate;
  end;

begin
  inherited Create(aOwner);

  Self.Caption := Self.Caption + ' ' + VERSION;

  const ports = server.ports(NUM_CHAINS);
  if ports.IsErr then
  begin
    terminate;
    EXIT;
  end;

  const server = server.start(ports.Value);
  if server.IsErr then
  begin
    terminate;
    EXIT;
  end;

  FServer := server.Value;
  FServer.OnRPC := DoRPC;
  FServer.OnLog := DoLog;

  lblEthereumURL.Text := FServer.URL(FServer.port(web3.Ethereum).Value);
  lblGoerliURL.Text   := FServer.URL(FServer.port(web3.Goerli).Value);
  lblPolygonURL.Text  := FServer.URL(FServer.port(web3.Polygon).Value);
  lblArbitrumURL.Text := FServer.URL(FServer.port(web3.Arbitrum).Value);
  lblOptimismURL.Text := FServer.URL(FServer.port(web3.Optimism).Value);

  FCanNotify := NC.AuthorizationStatus = TAuthorizationStatus.Authorized;
  if not FCanNotify then NC.RequestPermission;
end;

destructor TFrmMain.Destroy;
begin
  if Assigned(FServer) then
  try
    if FServer.Active then
    try
      FServer.Active := False;
    except end;
  finally
    FServer.Free;
  end;
  inherited Destroy;
end;

procedure TFrmMain.Notify(const body: string);
begin
  if FCanNotify then
    thread.synchronize(procedure
    begin
      const N = NC.CreateNotification;
      try
        N.AlertBody := body;
        NC.PresentNotification(N);
      finally
        N.Free;
      end;
    end);
end;

// notify the user when we allow (not block) a transaction
procedure TFrmMain.Notify(port: TIdPort; chain: TChain; tx: transaction.ITransaction);
begin
  const apiKey = FServer.apiKey(port);
  if apiKey.IsErr then
    Self.Notify('Approved your transaction')
  else
    tx.Simulate(apiKey.Value, chain, procedure(changes: IAssetChanges; _: IError)
    begin
      if (changes = nil) or (changes.Count = 0) or (changes.Item(0).Change <> Transfer) or (changes.Item(0).Amount = 0) then
        Self.Notify('Approved your transaction')
      else
      begin
        const item = changes.Item(0);
        item.&To.ToString(TWeb3.Create(common.Ethereum), procedure(name: string; err: IError)
        begin
          Self.Notify(System.SysUtils.Format('Approved transfer of %s %s to %s', [item.Symbol, common.Format(item.Unscale), (function: string
          begin
            if Assigned(err) then
              Result := string(item.&To)
            else
              Result := name;
          end)()]));
        end, True);
      end;
    end);
end;

procedure TFrmMain.Dismiss;
begin
  thread.synchronize(procedure
  begin
    if Self.Visible then
    begin
      Self.Hide;
      Self.Notify('Securing your crypto wallet');
    end;
  end);
end;

function TFrmMain.GetURL(chainId: Integer): TLabel;
begin
  for var I := 0 to Pred(Self.ComponentCount) do
    if (Self.Components[I] is TLabel) and (TLabel(Self.Components[I]).Tag = chainId) then
    begin
      Result := TLabel(Self.Components[I]);
      EXIT;
    end;
  Result := nil;
end;

procedure TFrmMain.ShowLogWindow;
begin
  if not Assigned(FFrmLog) then FFrmLog := TFrmLog.Create(Application);
  FFrmLog.Show;
end;

procedure TFrmMain.DoShow;
begin
  inherited DoShow;
  if common.Debug then ShowLogWindow;
end;

procedure TFrmMain.NCPermissionRequestResult(Sender: TObject; const aIsGranted: Boolean);
begin
  FCanNotify := aIsGranted;
end;

// approve(address,uint256)
procedure TFrmMain.Step1(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  const func = getTransactionFourBytes(tx.Data);
  if func.IsOk and SameText(fourBytestoHex(func.Value), '0x095EA7B3') then
  begin
    const args = getTransactionArgs(tx.Data);
    if args.IsOk and (Length(args.Value) > 0) then
    begin
      const value = (function: BigInteger
      begin
        if Length(args.Value) > 1 then
          Result := args.Value[1].toUInt256
        else
          Result := web3.Infinite;
      end)();
      if value > 0 then
      begin
        web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; _: IError)
        begin
          if not Assigned(token) then
            next(checked)
          else
            thread.synchronize(procedure
            begin
              approve.show(chain, token, args.Value[0].ToAddress, value, procedure(allow: Boolean)
              begin
                if allow then
                  next(checked + [TChangeType.Approve])
                else
                  block;
              end);
            end);
        end);
        EXIT;
      end;
    end;
  end;
  next(checked);
end;

// transfer(address,uint256)
procedure TFrmMain.Step2(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  const func = getTransactionFourBytes(tx.Data);
  if func.IsOk and SameText(fourBytestoHex(func.Value), '0xA9059CBB') then
  begin
    const args = getTransactionArgs(tx.Data);
    if args.IsOk and (Length(args.Value) > 1) then
    begin
      const quantity = args.Value[1].toUInt256;
      if quantity > 0 then
      begin
        const apiKey = FServer.apiKey(port);
        if apiKey.IsOk then
        begin
          tx.Simulate(apiKey.Value, chain, procedure(changes: IAssetChanges; _: IError)
          begin
            if not Assigned(changes) then
            begin
              next(checked);
              EXIT;
            end;
            const index = changes.IndexOf(tx.&To);
            if (index > -1) and (changes.Item(index).Amount > 0) then
              thread.synchronize(procedure
              begin
                approve.show(chain, changes.Item(index), procedure(allow: Boolean)
                begin
                  if allow then
                    next(checked + [TChangeType.Transfer])
                  else
                    block;
                end);
              end)
            else
              thread.synchronize(procedure
              begin
                untransferable.show(chain, tx.&To, args.Value[0].ToAddress, procedure(allow: Boolean)
                begin
                  if allow then
                    next(checked)
                  else
                    block;
                end);
              end);
          end);
          EXIT;
        end;
      end;
    end;
  end;
  next(checked);
end;

// are we transacting with (a) smart contract and (b) not verified with etherscan?
procedure TFrmMain.Step3(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  tx.ToEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) or isEOA then
    begin
      next(checked);
      EXIT;
    end;
    etherscan.getContractSourceCode(tx.&To, procedure(src: string; _: IError)
    begin
      if src <> '' then
        next(checked)
      else
        thread.synchronize(procedure
        begin
          unverified.show(chain, tx.&To, procedure(allow: Boolean)
          begin
            if allow then
              next(checked)
            else
              block;
          end);
        end);
    end);
  end);
end;

// are we transferring more than $5k in ERC-20, translated to USD?
procedure TFrmMain.Step4(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  const func = getTransactionFourBytes(tx.Data);
  if func.IsOk and SameText(fourBytestoHex(func.Value), '0xA9059CBB') then
  begin
    const args = getTransactionArgs(tx.Data);
    if args.IsOk and (Length(args.Value) > 1) then
    begin
      const quantity = args.Value[1].toUInt256;
      if quantity > 0 then
      begin
        web3.defillama.price(chain, tx.&To, procedure(price: Double; _: IError)
        begin
          if (price = 0) or (quantity.BitLength > 64) then
            next(checked)
          else begin
            const amount = quantity.AsUInt64 * price;
            if amount < common.LIMIT then
              next(checked)
            else
              common.Symbol(chain, tx.&To, procedure(symbol: string; _: IError)
              begin
                thread.synchronize(procedure
                begin
                  limit.show(chain, symbol, args.Value[0].ToAddress, amount, procedure(allow: Boolean)
                  begin
                    if allow then
                      next(checked)
                    else
                      block;
                  end);
                end);
              end);
          end;
        end);
        EXIT;
      end;
    end;
  end;
  next(checked);
end;

// are we sending more than $5k in ETH, translated to USD?
procedure TFrmMain.Step5(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  if tx.Value > 0 then
  begin
    const client: IWeb3 = TWeb3.Create(chain);
    client.LatestPrice(procedure(price: Double; _: IError)
    begin
      if (price = 0) or (tx.Value.BitLength > 64) then
        next(checked)
      else begin
        const amount = tx.Value.AsUInt64 * price;
        if amount < common.LIMIT then
          next(checked)
        else
          thread.synchronize(procedure
          begin
            limit.show(chain, chain.Symbol, tx.&To, amount, procedure(allow: Boolean)
            begin
              if allow then
                next(checked)
              else
                block;
            end);
          end);
      end;
    end);
    EXIT;
  end;
  next(checked);
end;

// are we transacting with a spam contract?
procedure TFrmMain.Step6(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  tx.ToEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) or isEOA then
    begin
      next(checked);
      EXIT;
    end;
    const apiKey = FServer.apiKey(port);
    if apiKey.IsErr then
    begin
      next(checked);
      EXIT;
    end;
    web3.eth.alchemy.api.detect(apiKey.Value, chain, tx.&To, procedure(contractType: TContractType; _: IError)
    begin
      case contractType of
        TContractType.Airdrop: // probably an unwarranted airdrop (most of the owners are honeypots)
          thread.synchronize(procedure
          begin
            airdrop.show(chain, tx.&To, procedure(allow: Boolean)
            begin
              if allow then
                next(checked)
              else
                block;
            end);
          end);
        TContractType.Spam: // probably spam (contains duplicate NFTs, or lies about its own token supply)
          thread.synchronize(procedure
          begin
            spam.show(chain, tx.&To, procedure(allow: Boolean)
            begin
              if allow then
                next(checked)
              else
                block;
            end);
          end);
      else
        next(checked);
      end;
    end);
  end);
end;

// have we transacted with this address before?
procedure TFrmMain.Step7(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  const from = tx.From;
  if from.IsErr then
  begin
    next(checked);
    EXIT;
  end;
  etherscan.getTransactions(from.Value, procedure(txs: ITransactions; _: IError)
  begin
    if not Assigned(txs) then
    begin
      next(checked);
      EXIT;
    end;
    txs.FilterBy(tx.&To);
    if txs.Count > 0 then
    begin
      next(checked);
      EXIT;
    end;
    thread.synchronize(procedure
    begin
      firsttime.show(chain, tx.&To, procedure(allow: Boolean)
      begin
        if allow then
          next(checked)
        else
          block;
      end);
    end);
  end);
end;

// are we transacting with a sanctioned address?
procedure TFrmMain.Step8(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  web3.eth.breadcrumbs.sanctioned({$I breadcrumbs.api.key}, chain, tx.&To, procedure(value: Boolean; _: IError)
  begin
    if not value then
      next(checked)
    else
      thread.synchronize(procedure
      begin
        sanctioned.show(chain, tx.&To, procedure(allow: Boolean)
        begin
          if allow then
            next(checked)
          else
            block;
        end);
      end);
  end);
end;

// simulate transaction
procedure TFrmMain.Step9(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  const apiKey = FServer.apiKey(port);
  if apiKey.IsOk then
  begin
    const from = tx.From;
    if from.IsErr then
    begin
      next(checked);
      EXIT;
    end;
    tx.Simulate(apiKey.Value, chain, procedure(changes: IAssetChanges; _: IError)
    begin
      if not Assigned(changes) then
      begin
        next(checked);
        EXIT;
      end;
      const approvals = (function: Integer
      begin
        Result := 0;
        for var I := 0 to Pred(changes.Count) do
          if changes.Item(I).Change = TChangeType.Approve then Inc(Result);
      end)();
      const transfers = (function: Integer
      begin
        Result := 0;
        for var I := 0 to Pred(changes.Count) do
          if changes.Item(I).Change = TChangeType.Transfer then Inc(Result);
      end)();
      var step: TProc<Integer, TProc>;
      step := procedure(index: Integer; done: TProc)
      begin
        if index >= changes.Count then
          done
        else
          if (changes.Item(index).Amount = 0) or from.Value.SameAs(changes.Item(index).&To) then
            step(index + 1, done)
          else
            // if we have prompted for this approval before in step 1
            if ((changes.Item(index).Change = TChangeType.Approve) and (approvals = 1) and (TChangeType.Approve in checked))
            // or we have prompted for this transfer before in step 2
            or ((changes.Item(index).Change = TChangeType.Transfer) and (transfers = 1) and (TChangeType.Transfer in checked)) then
              step(index + 1, done)
            else
              thread.synchronize(procedure
              begin
                approve.show(chain, changes.Item(index), procedure(allow: Boolean)
                begin
                  if allow then
                    step(index + 1, done)
                  else
                    block;
                end);
              end);
      end;
      step(0, procedure
      begin
        next(checked);
      end);
    end);
    EXIT;
  end;
  next(checked);
end;

// include this step if you want every transaction to fail (debug only)
procedure TFrmMain.Block(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
begin
  block;
end;

procedure TFrmMain.DoRPC(aContext: TIdContext; aPayload: IPayload; callback: TProc<Boolean>);
type
  TStep  = reference to procedure(port: TIdPort; chain: TChain; tx: transaction.ITransaction; etherscan: IEtherscan; checked: TChecked; block: TProc; next: TProc<TChecked>);
  TSteps = array of TStep;
  TNext  = reference to procedure(steps: TSteps; index: Integer; etherscan: IEtherscan; checked: TChecked; block: TProc; done: TProc);
begin
  if not Assigned(aPayload) then
  begin
    callback(True);
    EXIT;
  end;

  Self.Dismiss;

  if SameText(aPayload.Method, 'eth_sendRawTransaction') then
    if (aPayload.Params.Count > 0) and (aPayload.Params[0] is TJsonString) then
    begin
      const tx = decodeRawTransaction(web3.utils.fromHex(TJsonString(aPayload.Params[0]).Value));
      if tx.IsOk then
      begin
        const chain = FServer.chain(aContext.Binding.Port);
        if Assigned(chain) then
        begin
          common.beforeTransaction;

          var next: TNext;
          next := procedure(steps: TSteps; index: Integer; etherscan: IEtherscan; input: TChecked; block: TProc; done: TProc)
          begin
            if index >= Length(steps) then
              done
            else
              steps[index](aContext.Binding.Port, chain^, tx.Value, etherscan, input, block, procedure(output: TChecked)
              begin
                next(steps, index + 1, etherscan, output, block, done)
              end);
          end;

          const done: TProc<Boolean> = procedure(allow: Boolean)
          begin
            common.afterTransaction;
            callback(allow);
          end;

          next([Step1, Step2, Step3, Step4, Step5, Step6, Step7, Step8, Step9], 0, web3.eth.etherscan.create(chain^, ''), [],
            procedure
            begin
              done(False);
            end,
            procedure
            begin
              Self.Notify(aContext.Binding.Port, chain^, tx.Value);
              done(True);
            end);

          EXIT;
        end;
      end;
    end;

  callback(True);
end;

procedure TFrmMain.DoLog(const request: string; const response: string);
begin
  if Assigned(FFrmLog) then
    thread.synchronize(procedure
    begin
      FFrmLog.Memo.Lines.BeginUpdate;
      try
        FFrmLog.Memo.Lines.Add('REQUEST : ' + request);
        FFrmLog.Memo.Lines.Add('RESPONSE: ' + response);
      finally
        FFrmLog.Memo.Lines.EndUpdate;
      end;
      FFrmLog.Memo.Model.CaretPosition := TCaretPosition.Create(FFrmLog.Memo.Model.Lines.Count - 1, 0);
    end);
end;

procedure TFrmMain.btnCopyMouseEnter(Sender: TObject);
begin
  const L = Self.URL[TButton(Sender).Tag];
  if Assigned(L) then
    L.TextSettings.Font.Style := L.TextSettings.Font.Style + [TFontStyle.fsUnderline];
end;

procedure TFrmMain.btnCopyMouseLeave(Sender: TObject);
begin
  const L = Self.URL[TButton(Sender).Tag];
  if Assigned(L) then
    L.TextSettings.Font.Style := L.TextSettings.Font.Style - [TFontStyle.fsUnderline];
end;

procedure TFrmMain.btnCopyClick(Sender: TObject);
begin
  var S: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, S) then
  begin
    const L = Self.URL[TButton(Sender).Tag];
    if Assigned(L) then
      S.SetClipboard(L.Text);
  end;
end;

procedure TFrmMain.btnDismissClick(Sender: TObject);
begin
  Self.Dismiss;
end;

end.
