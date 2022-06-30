// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IMarket {
    // Declare here every function which you want to invoke
    // from other contracts (i.e., not from the off-chain).

    enum Stage {
        ASK,
        BUY,
        INACTIVE
    }

    function setStage(Stage _stage) external;

    function getStage() external view returns (Stage);

    function reset() external;
}
