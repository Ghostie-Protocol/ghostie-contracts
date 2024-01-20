import hre from "hardhat";
import { privateKeyToAccount } from "viem/accounts";
import { VRFs__factory } from "../../typechain-types/factories/contracts/VRF.sol";
import accountUtils from "../../utils/accountUtils";

export async function deployVRF() {
  const contract = await hre.viem.deployContract("VRFs", [7146]);

  return { VrfContract: contract };
}
