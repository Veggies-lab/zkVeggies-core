import { utils, Wallet } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { log } from "console";

/* -------------------------------------------------------------------------- */
/*                          Deploy proxy + zkVeggies                          */
/* -------------------------------------------------------------------------- */

// The deploy script that will deploy a proxy and the ZkVeggies contract and init the proxy.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the ZkSeeds contract`);

  if(process.env.DEPLOYER_KEY == null) throw "No DEPLOYER_KEY in environment variables";
  if(process.env.ADMIN_KEY == null) throw "No ADMIN_KEY in environment variables";

  // Initialize the wallets
  const deployerWallet = new Wallet(process.env.DEPLOYER_KEY);
  const adminWallet = new Wallet(process.env.ADMIN_KEY);
  
  // Create deployer
  const deployer = new Deployer(hre, deployerWallet);

  /* ----------------------------- Deploy zkSeeds ----------------------------- */
  const zkSeedsArtifacts = await deployer.loadArtifact("ZkSeeds");

  console.log("Deploying ZkSeeds contract...");

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const zkSeedsName = "zkSeeds";
  const zkSeedsSymbol = "ZKS";
  const zkSeedsBaseUri = "https://api.zkveggies.com/zkSeeds/";
  const zkSeedsContractURI = "https://api.zkveggies.com/zkSeeds";
  const maxMintPerAccount = 1;
  const zkSeeds = await deployer.deploy(zkSeedsArtifacts, [zkSeedsName, zkSeedsSymbol, zkSeedsBaseUri, zkSeedsContractURI, maxMintPerAccount]);

  // Show the contract info.
  console.log(`${zkSeedsArtifacts.contractName} was deployed to ${zkSeeds.address}\n`);

  /* --------------------- Deploy ZkVeggies implementation -------------------- */

  console.log("Deploying ZkVeggies implementation contract...");

  const zkVeggiesArtifact = await deployer.loadArtifact("ZkVeggies");

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const zkVeggiesName = "zkVeggies";
  const zkVeggiesSymbol = "ZKV";
  const zkVeggiesBaseUri = "https://api.zkveggies.com/zkVeggies/";
  const zkVeggiescontractURI = "https://api.zkveggies.com/zkVeggies";
  const zkVeggies = await deployer.deploy(zkVeggiesArtifact, [zkVeggiesName, zkVeggiesSymbol, zkVeggiesBaseUri, zkVeggiescontractURI, zkSeeds.address]);

  // Show the contract info.
  console.log(`${zkVeggiesArtifact.contractName} was deployed to ${zkVeggies.address}\n`);

  /* ------------------------------ Deploy proxy ------------------------------ */

  console.log("Deploying proxy contract...");

  const proxyArtifacts = await deployer.loadArtifact("ZkVeggiesProxy");

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const proxy = await deployer.deploy(proxyArtifacts, [zkVeggies.address, adminWallet.address, null]);

  // Show the contract info.
  console.log(`${proxyArtifacts.contractName} was deployed to ${proxy.address}\n`);
  console.log(`\tYou have to initialize the proxy to setup his default state.`);
}
