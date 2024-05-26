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
      address: "0xFD6F7A6a5c21A3f503EBaE7a473639974379c351",
      startBlock: 0,
    },
  },
});
