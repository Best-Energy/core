// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./IMarket.sol";

contract MarketUpkeep is KeeperCompatibleInterface {
    mapping(IMarket.Stage => uint32) public times;
    uint32 public interval;
    uint256 public lastTimeStamp;
    IMarket market;

    constructor(address marketContractAddress, IMarket.Stage initStage) {
        times[IMarket.Stage.ASK] = 60;
        times[IMarket.Stage.BUY] = 60;
        times[IMarket.Stage.SETTELMENT] = 60;
        times[IMarket.Stage.INACTIVE] = 60;
        market = IMarket(marketContractAddress);
        lastTimeStamp = block.timestamp;
        interval = times[initStage];
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
    ) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        require(
            (block.timestamp - lastTimeStamp) > interval,
            "Not ready for upkeep"
        );

        lastTimeStamp = block.timestamp;
        IMarket.Stage stage = market.getStage();
        interval = times[stage];
        if (stage == IMarket.Stage.ASK) {
            market.setStage(IMarket.Stage.BUY);
        } else if (stage == IMarket.Stage.BUY) {
            market.setStage(IMarket.Stage.SETTELMENT);
        } else if (stage == IMarket.Stage.SETTELMENT) {
            market.setStage(IMarket.Stage.INACTIVE);
        } else {
            market.reset();
        }
    }
}
