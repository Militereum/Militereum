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
    procedure Notify(const port: TIdPort; const chain: TChain; const tx: ITransaction); overload;
    procedure ShowLogWindow;
    procedure Step1(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step2(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step3(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step4(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step5(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step6(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step7(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step8(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Step9(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
    procedure Block(const port: TIdPort; const chain: TChain; const tx: ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
  strict protected
    procedure DoShow; override;
    procedure DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
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
  web3.eth.etherscan,
  web3.eth.tokenlists,
  web3.eth.types,
  web3.utils,
  // project
  airdrop,
  asset,
  common,
  firsttime,
  honeypot,
  limit,
  sanctioned,
  spam,
  thread,
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
  if ports.isErr then
  begin
    terminate;
    EXIT;
  end;

  const server = server.start(ports.Value);
  if server.isErr then
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
procedure TFrmMain.Notify(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction);
begin
  FServer.apiKey(port)
    .ifErr(procedure(_: IError)
    begin
      Self.Notify('Approved your transaction')
    end)
    .&else(procedure(apiKey: string)
    begin
      tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
      begin
        const item = (function(const changes: IAssetChanges): IAssetChange
        begin
          if Assigned(changes) then
            for var I := 0 to Pred(changes.Count) do
              if (changes.Item(I).Change = Transfer) and (changes.Item(I).Amount > 0) then
              begin
                Result := changes.Item(I);
                EXIT;
              end;
          Result := nil;
        end)(changes);
        if not Assigned(item) then
          Self.Notify('Approved your transaction')
        else
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
      end);
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
procedure TFrmMain.Step1(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError)
    begin
      next(checked)
    end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0x095EA7B3') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError)
          begin
            next(checked)
          end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const value = (function(const args: TArray<TArg>): BigInteger
              begin
                if Length(args) > 1 then
                  Result := args[1].toUInt256
                else
                  Result := web3.Infinite;
              end)(args);
              if value = 0 then
                next(checked)
              else
                web3.eth.tokenlists.token(chain, tx.&To, procedure(token: IToken; _: IError)
                begin
                  if not Assigned(token) then
                    next(checked)
                  else
                    thread.synchronize(procedure
                    begin
                      asset.approve(chain, token, args[0].ToAddress, value, procedure(allow: Boolean)
                      begin
                        if allow then
                          next(checked + [TChangeType.Approve])
                        else
                          block;
                      end);
                    end);
                end);
            end;
          end);
    end);
end;

// transfer(address,uint256)
procedure TFrmMain.Step2(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError)
    begin
      next(checked)
    end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError)
          begin
            next(checked)
          end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(checked)
              else
                FServer.apiKey(port)
                  .ifErr(procedure(_: IError)
                  begin
                    next(checked)
                  end)
                  .&else(procedure(apiKey: string)
                  begin
                    tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
                    begin
                      if not Assigned(changes) then
                        next(checked)
                      else begin
                        const index = changes.IndexOf(tx.&To);
                        if (index > -1) and (changes.Item(index).Amount > 0) then
                          thread.synchronize(procedure
                          begin
                            asset.show(chain, changes.Item(index), procedure(allow: Boolean)
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
                            honeypot.show(chain, tx.&To, args[0].ToAddress, procedure(allow: Boolean)
                            begin
                              if allow then
                                next(checked)
                              else
                                block;
                            end);
                          end);
                      end;
                    end);
                  end);
            end;
          end);
    end);
end;

// are we transacting with (a) smart contract and (b) not verified with etherscan?
procedure TFrmMain.Step3(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
  begin
    if Assigned(err) or isEOA then
      next(checked)
    else
      common.Etherscan(chain)
        .ifErr(procedure(_: IError)
        begin
          next(checked)
        end)
        .&else(procedure(etherscan: IEtherscan)
        begin
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
  end);
end;

// are we transferring more than $5k in ERC-20, translated to USD?
procedure TFrmMain.Step4(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  getTransactionFourBytes(tx.Data)
    .ifErr(procedure(_: IError)
    begin
      next(checked)
    end)
    .&else(procedure(func: TFourBytes)
    begin
      if not SameText(fourBytestoHex(func), '0xA9059CBB') then
        next(checked)
      else
        getTransactionArgs(tx.Data)
          .ifErr(procedure(_: IError)
          begin
            next(checked)
          end)
          .&else(procedure(args: TArray<TArg>)
          begin
            if Length(args) = 0 then
              next(checked)
            else begin
              const quantity = args[1].toUInt256;
              if quantity = 0 then
                next(checked)
              else
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
                          limit.show(chain, symbol, args[0].ToAddress, amount, procedure(allow: Boolean)
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
            end;
          end);
    end);
end;

// are we sending more than $5k in ETH, translated to USD?
procedure TFrmMain.Step5(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  if tx.Value = 0 then
    next(checked)
  else begin
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
  end;
end;

// are we transacting with a spam contract, or receiving spam tokens?
procedure TFrmMain.Step6(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
type
  TDetect = reference to procedure(const contracts: TArray<TAddress>; const index: Integer; const done: TProc);
begin
  FServer.apiKey(port)
    .ifErr(procedure(_: IError)
    begin
      next(checked)
    end)
    .&else(procedure(apiKey: string)
    begin
      var detect: TDetect;
      detect := procedure(const contracts: TArray<TAddress>; const index: Integer; const done: TProc)
      begin
        if index >= Length(contracts) then
          done
        else
          web3.eth.alchemy.api.detect(apiKey, chain, contracts[index], procedure(contractType: TContractType; _: IError)
          begin
            case contractType of
              TContractType.Airdrop: // probably an unwarranted airdrop (most of the owners are honeypots)
                thread.synchronize(procedure
                begin
                  airdrop.show(chain, tx.&To, procedure(allow: Boolean)
                  begin
                    if allow then
                      detect(contracts, index + 1, done)
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
                      detect(contracts, index + 1, done)
                    else
                      block;
                  end);
                end);
            else
              detect(contracts, index + 1, done);
            end;
          end);
      end;

      const step1 = procedure(const done: TProc) // tx.To
      begin
        tx.ToIsEOA(chain, procedure(isEOA: Boolean; err: IError)
        begin
          if Assigned(err) or isEOA then
            done
          else
            detect([tx.&To], 0, procedure
            begin
              done;
            end);
        end);
      end;

      const step2 = procedure(const done: TProc) // incoming tokens
      begin
        tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
        begin
          if not Assigned(changes) then
            done
          else
            tx.From
              .ifErr(procedure(_: IError)
              begin
                done
              end)
              .&else(procedure(from: TAddress)
              begin
                detect((function(const incoming: IAssetChanges): TArray<TAddress>
                begin
                  Result := [];
                  for var I := 0 to Pred(incoming.Count) do
                    if incoming.Item(I).Contract.SameAs(tx.&To) then
                      // ignore tx.To
                    else
                      Result := Result + [incoming.Item(I).Contract];
                end)(changes.Incoming(from)), 0, procedure
                begin
                  done;
                end);
              end);
        end);
      end;

      step1(procedure begin step2(procedure begin next(checked) end) end);
    end);
end;

// have we transacted with this address before?
procedure TFrmMain.Step7(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  tx.From
    .ifErr(procedure(_: IError)
    begin
      next(checked)
    end)
    .&else(procedure(from: TAddress)
    begin
      common.Etherscan(chain)
        .ifErr(procedure(_: IError)
        begin
          next(checked)
        end)
        .&else(procedure(etherscan: IEtherscan)
        begin
          etherscan.getTransactions(from, procedure(txs: ITransactions; _: IError)
          begin
            if not Assigned(txs) then
              next(checked)
            else begin
              txs.FilterBy(tx.&To);
              if txs.Count > 0 then
                next(checked)
              else
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
            end;
          end);
        end);
    end);
end;

// are we transacting with a sanctioned address?
procedure TFrmMain.Step8(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
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
procedure TFrmMain.Step9(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
type
  TStep = reference to procedure(const changes: IAssetChanges; const index: Integer; const done: TProc);
begin
  FServer.apiKey(port)
    .ifErr(procedure(err: IError)
    begin
      next(checked)
    end)
    .&else(procedure(apiKey: string)
    begin
      tx.From
        .ifErr(procedure(_: IError)
        begin
          next(checked)
        end)
        .&else(procedure(from: TAddress)
        begin
          tx.Simulate(apiKey, chain, procedure(changes: IAssetChanges; _: IError)
          begin
            if not Assigned(changes) then
              next(checked)
            else begin
              const approvals = (function(const changes: IAssetChanges): Integer
              begin
                Result := 0;
                for var I := 0 to Pred(changes.Count) do
                  if changes.Item(I).Change = TChangeType.Approve then Inc(Result);
              end)(changes);
              const transfers = (function(const changes: IAssetChanges): Integer
              begin
                Result := 0;
                for var I := 0 to Pred(changes.Count) do
                  if changes.Item(I).Change = TChangeType.Transfer then Inc(Result);
              end)(changes);
              var step: TStep;
              step := procedure(const changes: IAssetChanges; const index: Integer; const done: TProc)
              begin
                if index >= changes.Count then
                  done
                else
                  // ignore incoming transactions
                  if (changes.Item(index).Amount = 0) or not from.SameAs(changes.Item(index).From) then
                    step(changes, index + 1, done)
                  else
                    // if we have prompted for this approval before in step 1
                    if ((changes.Item(index).Change = TChangeType.Approve) and (approvals = 1) and (TChangeType.Approve in checked))
                    // or we have prompted for this transfer before in step 2
                    or ((changes.Item(index).Change = TChangeType.Transfer) and (transfers = 1) and (TChangeType.Transfer in checked)) then
                      step(changes, index + 1, done)
                    else
                      thread.synchronize(procedure
                      begin
                        asset.show(chain, changes.Item(index), procedure(allow: Boolean)
                        begin
                          if allow then
                            step(changes, index + 1, done)
                          else
                            block;
                        end);
                      end);
              end;
              step(changes, 0, procedure
              begin
                next(checked);
              end);
            end;
          end);
        end);
    end);
end;

// include this step if you want every transaction to fail (debug only)
procedure TFrmMain.Block(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
begin
  block;
end;

procedure TFrmMain.DoRPC(const aContext: TIdContext; const aPayload: IPayload; const callback: TProc<Boolean>);
type
  TStep  = reference to procedure(const port: TIdPort; const chain: TChain; const tx: transaction.ITransaction; const checked: TChecked; const block: TProc; const next: TProc<TChecked>);
  TSteps = array of TStep;
  TNext  = reference to procedure(const steps: TSteps; const index: Integer; const checked: TChecked; const block: TProc; const done: TProc);
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
      if tx.isOk then
      begin
        const chain = FServer.chain(aContext.Binding.Port);
        if Assigned(chain) then
        begin
          common.beforeTransaction;

          var next: TNext;
          next := procedure(const steps: TSteps; const index: Integer; const input: TChecked; const block: TProc; const done: TProc)
          begin
            if index >= Length(steps) then
              done
            else
              steps[index](aContext.Binding.Port, chain^, tx.Value, input, block, procedure(output: TChecked)
              begin
                next(steps, index + 1, output, block, done)
              end);
          end;

          const done: TProc<Boolean> = procedure(allow: Boolean)
          begin
            common.afterTransaction;
            callback(allow);
          end;

          next([Step1, Step2, Step3, Step4, Step5, Step6, Step7, Step8, Step9], 0, [],
            procedure // block
            begin
              done(False);
            end,
            procedure // allow
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
