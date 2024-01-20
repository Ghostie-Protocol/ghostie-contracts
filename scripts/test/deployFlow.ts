import { formatEther, parseEther } from "viem";
import hre from "hardhat";
import { deployCoreContract } from "../deploy/core";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";
import addressUtils from "../../utils/addressUtils";
import { deployTicket } from "../deploy/ticket";
import { deployVRF } from "../deploy/vrf";

async function main() {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);
  const vrfAddress = "0xb7e50b4961d3d00b60789ac4a3f1db1041ca8f06";

  const { VrfContract } = await deployVRF();

  const { ticketContract } = await deployTicket(
    "Ghostie Protocal Tickets",
    "GHOSTIE",
    signer.address
  );
  const { coreContract } = await deployCoreContract(
    ticketContract.address,
    VrfContract.address
  );

  // const hash = await VrfContract.write.updateOwner([coreContract.address]);
  // console.log({ hashUpdateVRFOwner: hash });

  const contractAddress = {
    Tickets: ticketContract.address,
    Core: coreContract.address,
    VRF: VrfContract.address,
  };

  await addressUtils.saveAddresses(hre.network.name, contractAddress);

  console.log(`deploy newwork => ${hre.network.name}`, contractAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
