import hre from "hardhat";
import addressUtil from "../../utils/addressUtils";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";

export interface FarmConfig {
  coreContract: string;
  operator: string;
  poolAddress: string;
  borrowTokenAddress: string;
  aTokenAddress: string;
  tokenAddress: string;
  ticketAddress: string;
}

export async function deployHandler(farmconfig: FarmConfig) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

  const contract = await hre.viem.deployContract("Handler", [farmconfig]);

  await addressUtil.saveAddresses(hre.network.name, {
    Handler: contract.address,
  });

  return contract;
}

export async function deployMockPool(aTokenAddress: `0x${string}`) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

  const contract = await hre.viem.deployContract("MockPool", [aTokenAddress]);

  await addressUtil.saveAddresses(hre.network.name, {
    MockPool: contract.address,
  });

  return contract;
}
