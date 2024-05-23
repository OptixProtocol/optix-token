import { createConfig } from "@ponder/core";
import { http } from "viem";
import { erc20ABI } from "./abis/erc20ABI";

export default createConfig({
  networks: {
    anvil: {
      chainId: 31337,
      transport: http(process.env.PONDER_RPC_URL_1),
    },
  },
  contracts: {
    ERC20: {
      network: "anvil",
      abi: erc20ABI,
      address: "0xF32D39ff9f6Aa7a7A64d7a4F00a54826Ef791a55",
      startBlock: 0,
    },
  },
});
