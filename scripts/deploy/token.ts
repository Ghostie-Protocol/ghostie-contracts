import hre from "hardhat";
import addressUtil from "../../utils/addressUtils";
import accountUtils from "../../utils/accountUtils";
import { privateKeyToAccount } from "viem/accounts";

export default async function deployToken(
  name: string,
  symbol: string,
  decimal: number
) {
  const contract = await hre.viem.deployContract("Token", [
    name,
    symbol,
    decimal,
  ]);

  await addressUtil.saveAddresses(hre.network.name, {
    [name]: contract.address,
  });

  return contract;
}
