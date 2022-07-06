// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./IMarket.sol";

contract CollateralOracle {
    address public administrator;
    IMarket market;

    constructor(address _market) {
        market = IMarket(_market);
    }

    event OracleInvoked();

    modifier onlyAdmin() {
        require(
            msg.sender == administrator,
            "Only admin can operate in this contract"
        );
        _;
    }

    modifier onlyMarket() {
        require(
            msg.sender == address(market),
            "Only Market contract can invoke the oracle"
        );
        _;
    }

    function invokeOracle() external onlyMarket {
        emit OracleInvoked();
    }

    function deductDeposit(
        address participant,
        uint256 amountDeducted,
        uint256 volumeNotDelivered
    ) external onlyAdmin {
        market.oracleDeductDeposit(
            participant,
            amountDeducted,
            volumeNotDelivered
        );
    }

    function fulfillPrice(uint256 _price) external onlyAdmin {
        market.setMarketPrice(_price);
    }
}
