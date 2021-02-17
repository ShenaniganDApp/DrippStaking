// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const DrippStaking = await hre.ethers.getContractFactory("Dripp Staking");
  const ERC20 = await hre.ethers.getContractFactory("ERC20");
  const drippStaking = await DrippStaking.deploy();
  const erc20Capped= await ERC20.deploy("Shweatpants", "SHWEATPANTS");

  await drippStaking.deployed();
  await erc20Capped.deployed();

  console.log("Dripp Staking deployed to:", drippStaking.address);
  console.log("ERC20 deployed to:", erc20Capped.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
