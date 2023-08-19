const { ethers } = require("hardhat");
require('dotenv').config();

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const [deployer] = await ethers.getSigners();

  // Deploy the NFT Contract
  const NFTContract = await ethers.getContractFactory("CryptoDevsNFT");
  const nftContract = await NFTContract.deploy();
  await nftContract.deployed();
  console.log("CryptoDevsNFT deployed to:", nftContract.address);

  // Deploy the Fake Marketplace Contract
  const MarketplaceContract = await ethers.getContractFactory("NFTMarketplace");
  const nftMarketplaceContract = await MarketplaceContract.deploy();
  await nftMarketplaceContract.deployed();
  console.log("NFTMarketplace deployed to:", nftMarketplaceContract.address);

  // Deploy the DAO Contract
  const amount = ethers.utils.parseEther("0.1");
  const DAOContract = await ethers.getContractFactory("CryptoDevsDAO");
  const daoContract = await DAOContract.deploy(nftMarketplaceContract.address, nftContract.address, { value: amount });
  await daoContract.deployed();
  console.log("CryptoDevsDAO deployed to:", daoContract.address);

  // Sleep for 30 seconds to let Etherscan catch up with the deployments
  await sleep(30 * 1000);

  // Verify the NFT Contract
  await hre.run("verify:verify", {
    address: nftContract.address,
    constructorArguments: [],
  });

  // Verify the Marketplace Contract
  await hre.run("verify:verify", {
    address: nftMarketplaceContract.address,
    constructorArguments: [],
  });

  // Verify the DAO Contract
  await hre.run("verify:verify", {
    address: daoContract.address,
    constructorArguments: [
      nftMarketplaceContract.address,
      nftContract.address,
    ],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
