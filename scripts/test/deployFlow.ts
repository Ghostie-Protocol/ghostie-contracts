import { formatEther, parseEther } from "viem";
import hre from "hardhat";
import { deployCoreContract } from "../deploy/core";
import { privateKeyToAccount } from "viem/accounts";
import accountUtils from "../../utils/accountUtils";
import addressUtils from "../../utils/addressUtils";
import { deployTicket } from "../deploy/ticket";
import { deployVRF } from "../deploy/vrf";
import { deployHandler, deployMockPool, FarmConfig } from "../deploy/handler";
import deployToken from "../deploy/token";

async function main() {
  const [myWallet] = await hre.viem.getWalletClients();

  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

  const mumbai = {
    usdtMumbai: "0x28F3fED00E6AB1714E43860e2A31449E357Bc358",
    coordinator: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
    keyHash:
      "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
  };

  const sepolia = {
    usdcAddress: "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    coordinator: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
    keyHash:
      "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
  };

  const usdc = await deployToken("USDC", "USDC", 18); // USDC
  console.log("======> usdc pass", usdc.address);
  const aUSDC = await deployToken("aUSDC", "aUSDC", 18); // aUSDC
  console.log("======> aUSDC pass", aUSDC.address);
  const GHO = await deployToken("GHO", "GHO", 18); // GHO
  console.log("======> GHO pass", GHO.address);

  const { vrfContract } = await deployVRF(mumbai.coordinator, mumbai.keyHash);
  console.log("======> VRF pass", vrfContract.address);

  const { ticketContract } = await deployTicket(
    "Ghostie Protocal Tickets",
    "GHOSTIE",
    signer.address
  );
  console.log("======> Ticket pass", ticketContract.address);

  const { coreContract } = await deployCoreContract(
    ticketContract.address,
    vrfContract.address,
    usdc.address,
    GHO.address
  );
  console.log("======> Core pass", coreContract.address);

  await ticketContract.write.transferOwnership([coreContract.address]);
  console.log("======> transferOwnership pass");

  const mockPool = await deployMockPool(aUSDC.address);
  console.log("======> Pool pass", mockPool.address);

  const farmConfig: FarmConfig = {
    coreContract: coreContract.address,
    operator: signer.address,
    poolAddress: mockPool.address,
    borrowTokenAddress: GHO.address,
    aTokenAddress: aUSDC.address,
    tokenAddress: usdc.address,
    ticketAddress: ticketContract.address,
  };

  const handler = await deployHandler(farmConfig);

  console.log("======> Handler pass", handler.address);

  const contractAddress = {
    usdcAddress: usdc.address,
    aUSDCAddress: aUSDC.address,
    ghoAddress: GHO.address,
    handlerAddress: handler.address,
    vrfAddress: vrfContract.address,
    ...farmConfig,
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
