import hre from "hardhat";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";

export async function deployCoreContract(
  ticketAddress: string,
  vrfAddress: string
) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);
  const usdcAddress = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  const pxrAddress = "0x42176584235C839Af270Ef97D65b36Bb1c19Bb6e";

  const contract = await hre.viem.deployContract("GhostieCores", [
    usdcAddress,
    ticketAddress,
    signer.address,
    vrfAddress,
  ]);

  return { coreContract: contract };
}
