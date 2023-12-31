object dmDemo: TdmDemo
  Height = 480
  Width = 640
  object AL: TActionList
    Left = 304
    Top = 224
    object actApprove: TAction
      Text = 'You allowing someone else to spend all your money'
      OnExecute = actApproveExecute
      OnUpdate = actUpdate
    end
    object actLimit: TAction
      Text = 'You transferring more than 5k in US dollars'
      OnExecute = actLimitExecute
      OnUpdate = actUpdate
    end
    object actSanctioned: TAction
      Text = 'You transacting with a sanctioned address'
      OnExecute = actSanctionedExecute
      OnUpdate = actUpdate
    end
    object actUnverified: TAction
      Text = 
        'You transacting with a smart contract that has not been ethersca' +
        'n-verified'
      OnExecute = actUnverifiedExecute
      OnUpdate = actUpdate
    end
    object actFirsttime: TAction
      Text = 
        'You transacting with an address you have not transacted with bef' +
        'ore'
      OnExecute = actFirsttimeExecute
      OnUpdate = actUpdate
    end
    object actPhisher: TAction
      Text = 
        'You transacting with an address that has been identified as a ph' +
        'isher'
      OnExecute = actPhisherExecute
      OnUpdate = actUpdate
    end
    object actSetApprovalForAll: TAction
      Text = 
        'You trusting someone else to be able to transfer all your NFTs o' +
        'ut of your wallet'
      OnExecute = actSetApprovalForAllExecute
      OnUpdate = actUpdate
    end
    object actSpam: TAction
      Text = 'You buying a token that lies about its own token supply'
      OnExecute = actSpamExecute
      OnUpdate = actUpdate
    end
    object actHoneypot: TAction
      Text = 
        'You buying a honeypot token that is designed to pump but you can' +
        'not sell'
      OnExecute = actHoneypotExecute
      OnUpdate = actUpdate
    end
    object actUnsupported: TAction
      Text = 'You buying a token that is unsupported by Uniswap'
      OnExecute = actUnsupportedExecute
      OnUpdate = actUpdate
    end
    object actNoDexPair: TAction
      Text = 'You receiving a token without a DEX pair'
      OnExecute = actNoDexPairExecute
      OnUpdate = actUpdate
    end
    object actLowDexScore: TAction
      Text = 'You receiving a low-DEX-score token'
      OnExecute = actLowDexScoreExecute
      OnUpdate = actUpdate
    end
    object actAirdrop: TAction
      Text = 
        'You buying a suspicious token that is probably an unwarranted ai' +
        'rdrop'
      OnExecute = actAirdropExecute
      OnUpdate = actUpdate
    end
    object actCensorable: TAction
      Text = 'You buying a censorable token that can blacklist you'
      OnExecute = actCensorableExecute
      OnUpdate = actUpdate
    end
    object actPausable: TAction
      Text = 
        'You buying a pausable token that can prevent you from swapping o' +
        'r selling'
      OnExecute = actPausableExecute
      OnUpdate = actUpdate
    end
    object actDormant: TAction
      Text = 
        'You transacting with a dormant contract where the last transacti' +
        'on with the contract was more than 30 days ago'
      OnExecute = actDormantExecute
      OnUpdate = actUpdate
    end
    object actUnlock: TAction
      Text = 'You buying a token with an unlock event coming up'
      OnExecute = actUnlockExecute
      OnUpdate = actUpdate
    end
  end
end
