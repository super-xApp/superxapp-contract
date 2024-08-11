## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
## Deployed Addresses 

| **Contract\Networks** | **Sepolia**                                    | **Arbitrum Sepolia**                           | **BASE SEPOLIA**                               | **OPTIMISM SEPOLIA**                           |
| --------------------- | ---------------------------------------------- | ---------------------------------------------- | ---------------------------------------------- | ---------------------------------------------- |
| _SuperxOracle_        | _`0x6364eC95659863D87b1150c7B6342C1A5D185273`_ | _`0x6A1831C9E48cd407dB1c7e9AaC6ae79C16d3462F`_ | _`0x13CfEA2CcC182C55Ee4A7954e23f8207F093eee9`_ | _`0x5c55DfB5f4eB4cE81b5416A071d96248c0E35aBa`_ |
| _SuperxApp_           | _`0x0d36DD97b829069b48F97190DA264b87C3558e3b`_ | _`0x13CfEA2CcC182C55Ee4A7954e23f8207F093eee9`_ | _`0xbb3D975B2F00Be37CBCBC5917649Fe7f9E30fFA3`_ | _`0x002D3C87e568C8b8387378c7ca11bB4DdDb2A554`_ |