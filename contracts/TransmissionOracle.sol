// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./IMarket.sol";

contract TransmissionOracle {
    address public administrator;
    IMarket market;
    mapping(uint8 => mapping(uint8 => uint256)) public transmissionCosts;
    uint256 public sameLocationCost;
    uint8 public immutable locationsCount = 5;

    constructor(address _market, address admin) {
        market = IMarket(_market);
        administrator = admin;
    }

    event CostsRefresh();

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

    modifier onlyInRange(uint8 loc1, uint8 loc2) {
        require(
            loc1 < locationsCount && loc2 < locationsCount,
            "Locations outside of range"
        );
        _;
    }

    function refreshCosts() external onlyMarket {
        emit CostsRefresh();
    }

    function fulfillSameLocation(uint256 _sameLocationCost) external onlyAdmin {
        sameLocationCost = _sameLocationCost;
    }

    function fulfillCost(
        uint8 loc1,
        uint8 loc2,
        uint256 cost
    ) external onlyAdmin onlyInRange(loc1, loc2) {
        require(loc1 != loc2, "Locations can't be equal");

        (uint8 l1, uint8 l2) = orderLocations(loc1, loc2);

        transmissionCosts[l1][l2] = cost;
    }

    function getTransmissionCosts(uint8 loc1, uint8 loc2)
        external
        view
        onlyInRange(loc1, loc2)
        returns (uint256)
    {
        if (loc1 == loc2) {
            return sameLocationCost;
        }

        (uint8 l1, uint8 l2) = orderLocations(loc1, loc2);
        return transmissionCosts[l1][l2];
    }

    function orderLocations(uint8 loc1, uint8 loc2)
        public
        pure
        returns (uint8, uint8)
    {
        if (loc1 < loc2) {
            return (loc1, loc2);
        }

        return (loc2, loc1);
    }
}
