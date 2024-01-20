import hre from "hardhat";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";

export async function deployCoreContract(
  ticketAddress: string,
  vrfAddress: string,
  usdc: string
) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

  const contract = await hre.viem.deployContract("GhostieCore", [
    usdc,
    ticketAddress,
    vrfAddress,
  ]);

  return { coreContract: contract };
}
