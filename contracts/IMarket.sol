// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

interface IMarket {
    enum Stage {
        ASK,
        BUY,
        SETTLEMENT,
        INACTIVE
    }

    function changeStage() external;

    function getStage() external view returns (Stage);

    function setMarketPrice(uint256 _price) external;

    function oracleDeductDeposit(
        address participant,
        uint256 amountDeducted,
        uint256 volumeNotDelivered
    ) external;

    function approveParticipant(address publicKey, uint8 locationGroup)
        external;

    function retractApproval(address publicKey) external;
}
