var RKCToken = artifacts.require("./RKCToken.sol");


var Web3 = require("../node_modules/web3/");
web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));


/*
 * migrations/2_deploy_contracts.js:
 */
module.exports = function(deployer) {
    deployer.deploy(RKCToken);
};
