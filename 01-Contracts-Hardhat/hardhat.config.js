require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.4",
  settings:{
    optimizer: {
      enabled: true,
      runs:200
    }
  },
  networks: {
    kovan: {
      url: `https://rinkeby.infura.io/v3/` + `786671decfea4241a9e3c811abcdf3fe`,
      accounts: [`acd6b5c68604c17c6bb8f68f0b14e3a88067fc185886f35ecfd779d04ee5800b`]
    }
  }
};

