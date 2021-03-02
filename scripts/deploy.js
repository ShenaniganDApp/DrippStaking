/* eslint no-use-before-define: "warn" */
const fs = require('fs');
const chalk = require('chalk');
const { config, ethers } = require('hardhat');
const { utils, BigNumber } = require('ethers');
const R = require('ramda');

const main = async () => {
	console.log('\n\n 📡 Deploying...\n');

	// const shweatpantsERC20 = await deploy('ShweatpantsToken', [BigNumber.from('100000000000000000000')]); // <-- add in constructor args like line 19 vvvv
	// const shweatpantsERC20 = await deploy('TestpantsToken', [BigNumber.from('100000000000000000000')]); // <-- add in constructor args like line 19 vvvv
	// const agaaveERC20 = await deploy('AlvinToken', [BigNumber.from('100000000000000000000')]); // <-- add in constructor args like line 19 vvvv
	const drippStaking = await deploy('DrippStaking', [
		['0x898e8897437d7245a2d09a29b2cd06a2c1ca388b', '0x3008Ff3e688346350b0C07B8265d256dddD97215'],
		['0xb5d592f85ab2d955c25720ebe6ff8d4d1e1be300', '0x71850b7e9ee3f13ab46d67167341e4bdc905eef9'],
		['0xaaefc56e97624b57ce98374eb4a45b6fd5ffb982', '0xaaefc56e97624b57ce98374eb4a45b6fd5ffb982'],
		[2592000, 2592000],
		["50000000000000000000", "50000000000000000000"],
	]); // <-- add in constructor args like line 19 vvvv

	//const secondContract = await deploy("SecondContract")

	// const exampleToken = await deploy("ExampleToken")
	// const examplePriceOracle = await deploy("ExamplePriceOracle")
	// const smartContractWallet = await deploy("SmartContractWallet",[exampleToken.address,examplePriceOracle.address])

	/*
  //If you want to send value to an address from the deployer
  const deployerWallet = ethers.provider.getSigner()
  await deployerWallet.sendTransaction({
    to: "0x34aA3F359A9D614239015126635CE7732c18fDF3",
    value: ethers.utils.parseEther("0.001")
  })
  */

	/*
  //If you want to send some ETH to a contract on deploy (make your constructor payable!)
  const yourContract = await deploy("YourContract", [], {
  value: ethers.utils.parseEther("0.05")
  });
  */

	/*
  //If you want to link a library into your contract:
  // reference: https://github.com/austintgriffith/scaffold-eth/blob/using-libraries-example/packages/hardhat/scripts/deploy.js#L19
  const yourContract = await deploy("YourContract", [], {}, {
   LibraryName: **LibraryAddress**
  });
  */

	console.log(
		' 💾  Artifacts (address, abi, and args) saved to: ',
		chalk.blue('packages/hardhat/artifacts/'),
		'\n\n'
	);
};

const deploy = async (contractName, _args = [], overrides = {}, libraries = {}) => {
	console.log(` 🛰  Deploying: ${contractName}`);

	const contractArgs = _args || [];
	const contractArtifacts = await ethers.getContractFactory(contractName, { libraries: libraries });
	const deployed = await contractArtifacts.deploy(...contractArgs, overrides);
	const encoded = abiEncodeArgs(deployed, contractArgs);
	fs.writeFileSync(`artifacts/${contractName}.address`, deployed.address);

	console.log(' 📄', chalk.cyan(contractName), 'deployed to:', chalk.magenta(deployed.address));

	if (!encoded || encoded.length <= 2) return deployed;
	fs.writeFileSync(`artifacts/${contractName}.args`, encoded.slice(2));

	return deployed;
};

// ------ utils -------

// abi encodes contract arguments
// useful when you want to manually verify the contracts
// for example, on Etherscan
const abiEncodeArgs = (deployed, contractArgs) => {
	// not writing abi encoded args if this does not pass
	if (!contractArgs || !deployed || !R.hasPath(['interface', 'deploy'], deployed)) {
		return '';
	}
	const encoded = utils.defaultAbiCoder.encode(deployed.interface.deploy.inputs, contractArgs);
	return encoded;
};

// checks if it is a Solidity file
const isSolidity = (fileName) =>
	fileName.indexOf('.sol') >= 0 && fileName.indexOf('.swp') < 0 && fileName.indexOf('.swap') < 0;

const readArgsFile = (contractName) => {
	let args = [];
	try {
		const argsFile = `./contracts/${contractName}.args`;
		if (!fs.existsSync(argsFile)) return args;
		args = JSON.parse(fs.readFileSync(argsFile));
	} catch (e) {
		console.log(e);
	}
	return args;
};

function sleep(ms) {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
