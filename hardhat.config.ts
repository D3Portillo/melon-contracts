import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "dotenv/config"

const RPC_URL = process.env.RPC_URL!

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY!,
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io",
        },
      },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: RPC_URL,
        enabled: true,
      },
    },
    arbitrumSepolia: {
      url: RPC_URL,
      accounts: [process.env.DEPLOYER_PK!],
    },
  },
}

export default config
