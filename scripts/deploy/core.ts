import hre from "hardhat";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";

export async function deployCoreContract(
  ticketAddress: string,
  vrfAddress: string
) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);
  const usdcAddress = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";

  const contract = await hre.viem.deployContract("GhostieCores", [
    usdcAddress,
    ticketAddress,
    signer.address,
    vrfAddress,
  ]);

  return { coreContract: contract };
}
