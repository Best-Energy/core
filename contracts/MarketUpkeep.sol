// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./IMarket.sol";

contract MarketUpkeep is KeeperCompatibleInterface, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address public registryAddress = 0x4Cb093f226983713164A62138C3F718A5b595F73;
    uint32 public timeAskToBuy = 60;
    uint32 public timeBuyToInactive = 60;
    uint32 public timeInactiveToAsk = 60;
    uint32 public interval;
    uint256 public lastTimeStamp;
    bytes32 private jobId;
    uint256 private fee;
    IMarket market;

    modifier isRegistry() {
        require(
            msg.sender == registryAddress,
            "Only registry can perform upkeep"
        );
        _;
    }

    constructor(address marketContractAddress, IMarket.Stage initStage) {
        //CLIENT
        setChainlinkToken(0xa36085F69e2889c224210F603D836748e7dC0088);
        setChainlinkOracle(0x74EcC8Bdeb76F2C6760eD2dc8A46ca5e581fA656);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10;

        //KEEPER
        market = IMarket(marketContractAddress);
        lastTimeStamp = block.timestamp;
        if (initStage == IMarket.Stage.ASK) {
            interval = timeAskToBuy;
        } else if (initStage == IMarket.Stage.BUY) {
            interval = timeBuyToInactive;
        } else {
            interval = timeInactiveToAsk;
        }
    }

    function requestPrice() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillPrice.selector
        );

        // Set the URL to perform the GET request on
        req.add("get", "https://price.deno.dev");

        req.add("path", "price");
        int256 timesAmount = 1;
        req.addInt("times", timesAmount);

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function fulfillPrice(bytes32 _requestId, uint256 price)
        public
        recordChainlinkFulfillment(_requestId)
    {
        market.setMarketPrice(price);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override isRegistry {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - lastTimeStamp) < interval) {
            return;
        }

        lastTimeStamp = block.timestamp;
        IMarket.Stage stage = market.getStage();
        if (stage == IMarket.Stage.ASK) {
            market.setStage(IMarket.Stage.BUY);
            interval = timeBuyToInactive;
        } else if (stage == IMarket.Stage.BUY) {
            market.setStage(IMarket.Stage.INACTIVE);
            interval = timeInactiveToAsk;
        } else {
            market.reset();
            interval = timeAskToBuy;
        }
    }
}
