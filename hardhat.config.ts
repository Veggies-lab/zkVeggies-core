import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";

module.exports = {
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkSync",
  etherscan: {
    apiKey: "[ZKSYNC_EXPLORER_API_KEY]",
  },
  networks: {
    goerli: {
      url: "[GOERLI_RPC]" // URL of the Ethereum Web3 RPC (optional)
    },
    zkTestnet: {
      url: "https://zksync2-testnet.zksync.dev", // URL of the zkSync network RPC
      ethNetwork: "goerli", // Can also be the RPC URL of the Ethereum network (e.g. `https://goerli.infura.io/v3/<API_KEY>`)
      zksync: true,
      verifyURL: 'https://zksync2-testnet-explorer.zksync.dev/contract_verification'
    },
    zkSync: {
      url: "https://mainnet.era.zksync.io", // URL of the zkSync network RPC
      ethNetwork: "[MAINNET_RPC]",
      zksync: true,
      verifyURL: 'https://explorer.zksync.io/contract_verification'
    },
  },
  solidity: {
    version: "0.8.18",
  },
};