const hre = require('hardhat');
const fs = require('fs-extra');

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { account0 } = await getNamedAccounts();

  const baseUri = process.env.BASE_URI;
  const imxAddress =
    hre.network.name === 'ropsten'
      ? process.env.IMX_ADDRESS_TESTNET
      : process.env.IMX_ADDRESS_MAINNET;

  console.log('------');
  console.log('network name: ', hre.network.name);
  console.log('Deployer: ' + account0);
  console.log('baseUri: ' + baseUri);
  console.log('imxAddress: ' + imxAddress);
  console.log('------');

  const token = await deploy('TheGoodDogClubLLC', {
    from: account0,
    args: [],
    log: true,
  });

  fs.mkdirSync("./export/contracts", { recursive: true });

  const deployData = {
    contractAddress: token.address,
    tokenAmount: 7777,
    deployer: account0,
  };
  fs.writeFileSync(
    './export/contracts/config.json',
    JSON.stringify(deployData, null, 2)
  );

  const contractJson = require('../artifacts/contracts/TheGoodDogClubLLC.sol/TheGoodDogClubLLC.json');
  fs.writeFileSync(
    './export/contracts/TheGoodDogClubLLC.json',
    JSON.stringify(contractJson.abi, null, 2)
  );

  console.log('deployData:', deployData);
};

module.exports.tags = ['TheGoodDogClubLLC'];
