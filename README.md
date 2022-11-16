# ![image](icon_150x150.png) Militereum&nbsp;&nbsp;[![GitHub release](https://img.shields.io/github/release/svanas/Militereum)](https://github.com/svanas/Militereum/releases/latest) [![macOS](https://img.shields.io/badge/os-macOS-green)](https://github.com/svanas/Militereum/releases/latest/download/macOS.zip) [![Windows](https://img.shields.io/badge/os-Windows-green)](https://github.com/svanas/Militereum/releases/latest/download/Windows.zip)

* blocks suspicious transactions
* works with every EVM-compatible wallet, including browser-based _and_ desktop wallets
* no cookie warnings, no ads
* not susceptible to fishing (there is no web site to visit)
* not susceptible to copycat extensions (there is no browser extension)
* supports Ethereum and many other chains, including Polygon and BNB Chain
* available for [Windows](https://github.com/svanas/Militereum/releases/latest/download/Windows.zip) and [macOS](https://github.com/svanas/Militereum/releases/latest/download/macOS.zip)

## Setup

1. Download Militereum for [Windows](https://github.com/svanas/Militereum/releases/latest/download/Windows.zip) or [macOS](https://github.com/svanas/Militereum/releases/latest/download/macOS.zip)
2. Launch Militereum. The following window appears. Click on `Copy`
![image](assets/main.png)
4. Unlock MetaMask in your web browser
5. Navigate to _Settings_ > _Networks_ > [Add a network](https://svanas.github.io/add-network.html)
6. The following tab appears. Paste Militereum's network URL in `New RPC URL`. Click on `Save`
<br>

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;;&nbsp;![image](assets/MetaMask.png)

## Running

As soon as your wallet has connected to Militereum, the firewall gets minimized and keeps running in the background.

Every raw transactions passes through Militereum and if it is suspicious, Militereum will block the transaction and prevent it from leaving your device.

Here's an example. Navigate to [Uniswap](https://app.uniswap.org/) or [Balancer](https://app.balancer.fi/). Initiate a swap from one of your tokens to another. Before Uniswap or Balancer can swap your token, you'll need to sign a so-called token allowance.

Every time you approve a token allowance, you are potentially exposing your wallet to an exploit. Uniswap and Balancer are very reputable, but any other dapp can potentially fish you and drain your tokens from your wallet.

After MetaMask has prompted you for the allowance, Militereum will intercept the transaction and prompt you with this window. From here, you can allow the transaction to happen, or prevent it from leaving your device.

![image](assets/approve.png)

## License

Distributed under the [GNU AGP v3.0](https://github.com/svanas/Militereum/blob/master/LICENSE) with [Commons Clause](https://commonsclause.com/) license.

## Disclaimer

Militereum is provided free of charge. There is no warranty. The authors do not assume any responsibility for bugs, vulnerabilities, or any other technical defects. Use at your own risk.
