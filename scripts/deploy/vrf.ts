import hre from "hardhat";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";

export async function deployVRF(coordinator: string, keyhash: string) {
  const contract = await hre.viem.deployContract("VRF", [
    6975,
    coordinator,
    keyhash,
  ]);

  return { vrfContract: contract };
}
