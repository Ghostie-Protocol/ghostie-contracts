import { deployTicket } from "../deploy/ticket";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";
import { deployHandler, deployMockPool } from "../deploy/handler";
import { FarmConfig } from "../deploy/handler";
import deployToken from "../deploy/token";

const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

export default async function main() {
  const token = await deployToken("USDC", "USDC", 18); // USDC
  console.log("USDC.address >>> ", token.address);

  const aToken = await deployToken("aUSDC", "aUSDC", 18); // aUSDC
  console.log("aUSDC.address >>> ", aToken.address);

  const borrowToken = await deployToken("GHO", "GHO", 18); // GHO
  console.log("GHO.address >>> ", borrowToken.address);

  const mockPool = await deployMockPool(aToken.address);
  console.log("mockPool.address >>> ", mockPool.address);

  const { ticketContract: ticket } = await deployTicket(
    "Ghostie Protocal Tickets",
    "GHOSTIE",
    signer.address
  );
  console.log("ticket.address >>> ", ticket.address);

  const farmConfig: FarmConfig = {
    coreContract: signer.address,
    operator: signer.address,
    poolAddress: mockPool.address,
    borrowTokenAddress: borrowToken.address,
    aTokenAddress: aToken.address,
    tokenAddress: token.address,
    ticketAddress: ticket.address,
  };

  const handler = await deployHandler(farmConfig);

  console.log("handler.address >>> ", handler.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
