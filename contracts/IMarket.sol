// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IMarket {
    enum Stage {
        ASK,
        BUY,
        INACTIVE
    }

    function setStage(Stage _stage) external;

    function getStage() external view returns (Stage);

    function reset() external;

    function setMarketPrice(uint256 _price) external;
}
