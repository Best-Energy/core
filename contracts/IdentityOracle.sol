// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./IMarket.sol";

contract IdentityOracle {
    address public administrator;
    IMarket market;

    constructor(address _market, address admin) {
        market = IMarket(_market);
        administrator = admin;
    }

    event ApproveRequest(address indexed publicKey);

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

    function requestApproval(address publicKey) external onlyMarket {
        emit ApproveRequest(publicKey);
    }

    function approve(address publicKey, uint8 locationGroup)
        external
        onlyAdmin
    {
        market.approveParticipant(publicKey, locationGroup);
    }

    function retractApproval(address publicKey) external onlyAdmin {
        market.retractApproval(publicKey);
    }
}
