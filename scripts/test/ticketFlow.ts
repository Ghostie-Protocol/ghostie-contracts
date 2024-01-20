import { deployTicket } from "../deploy/ticket";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";

const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

export default async function main() {
  const { ticketContract: ticketsContract } = await deployTicket(
    "Ghostie Protocal Tickets",
    "GHOSTIE",
    signer.address
  );

  console.log("ticketsContract.address", ticketsContract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
