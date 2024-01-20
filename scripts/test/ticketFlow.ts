import deployTicket from "../deploy/ticket";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";
import { ticketAbi } from "../../const/ticketAbi";
import { createWalletClient, getContract, http, parseAbi } from "viem";
import { localhost, mainnet } from "viem/chains";

const signer = privateKeyToAccount(`0x${accountUtils.getAccounts()}`);

export default async function main() {
  const deployedTicketsContract = await deployTicket(
    "Ghostie Protocal Tickets",
    "GHOSTIE",
    signer.address
  );

  console.log("#####################");
  console.log("ticketsContract.address", deployedTicketsContract.address);

  // const walletClient = createWalletClient({
  //   chain: localhost,
  //   transport: http(),
  // });

  // const contract = getContract({
  //   address: deployedTicketsContract.address,
  //   abi: deployedTicketsContract.abi,
  //   walletClient,
  // });

  // const tx = await walletClient.writeContract({
  //   address: contract.address,
  //   abi: contract.abi,
  //   functionName: 'mint',
  //   account: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  //   args: ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", BigInt(2000000), ["654321","123456"]]
  // })
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
