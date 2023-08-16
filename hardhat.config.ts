import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";

import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";

// dynamically alters endpoints for local tests
const zkSyncTestnet =
  process.env.NODE_ENV == "test"
    ? {
      url: "http://localhost:3050",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    }
    : {
      url: "https://zksync2-testnet.zksync.dev",
      ethNetwork: "goerli",
      zksync: true,
      verifyURL: "https://zksync2-testnet-explorer.zksync.dev/contract_verification", // Verification endpoint
    };

const config: HardhatUserConfig = {
  zksolc: {
    version: "latest", // Uses latest available in https://github.com/matter-labs/zksolc-bin/
    settings: {},
  },
  defaultNetwork: "zkSyncTestnet",
  networks: {
    hardhat: {
      zksync: false,
    },
    zkSyncTestnet,
  },
  // etherscan: { // Optional - If you plan on verifying a smart contract on Ethereum within the same project
  //   apiKey: //<Your API key for Etherscan>,
  // },
  solidity: {
    version: "0.8.19",
  },
};

export default config;