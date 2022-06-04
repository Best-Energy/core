const P2PMarket = artifacts.require("P2PMarket");

module.exports = function (deployer) {
  deployer.deploy(P2PMarket);
};
