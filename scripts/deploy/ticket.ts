import hre from "hardhat";
import addressUtil from "../../utils/addressUtils";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";

export async function deployTicket(
  name: string,
  symbol: string,
  coreAddress: `0x${string}`
) {
  const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

  const contract = await hre.viem.deployContract("Tickets", [
    name,
    symbol,
    coreAddress,
    signer.address,
  ]);

  // await addressUtil.saveAddresses(hre.network.name, {
  //   Tickets: contract.address,
  // });

  return { ticketContract: contract };
}
