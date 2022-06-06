// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract P2PMarket {
    struct Ask {
        address seller;
        uint256 price;
        uint256 volume;
    }

    struct Participant {
        //Does the participant produce renewable energy?
        bool renewable;
        //Use for the mapping to check if the participant exists
        bool isValue;
    }

    address private owner;
    mapping(address => Participant) private participants;
    Ask[] private asks;

    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);

    // modifier to check if caller is owner
    modifier isOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier isParticipant() {
        require(
            participants[msg.sender].isValue,
            "Caller is not network participant"
        );
        _;
    }

    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    function amParticipant() external view returns (bool) {
        return participants[msg.sender].isValue;
    }

    function addParticipant(address publicKey, bool renewable)
        external
        isOwner
    {
        participants[publicKey] = Participant(renewable, true);
    }

    function removeParticipant(address publicKey) external isOwner {
        participants[publicKey].isValue = false;
    }

    function sendAsk(uint256 price, uint256 volume) external isParticipant {
        asks.push(Ask(msg.sender, price, volume));
    }

    function getAsks() external view returns (Ask[] memory) {
        return asks;
    }

    function buy(uint256 askIndex, uint256 volume)
        external
        payable
        isParticipant
    {
        Ask storage ask = asks[askIndex];
        require(ask.volume >= volume, "Volume exceeds ask volume");
        uint256 totalPrice = ask.price * volume;
        require(totalPrice == msg.value, "Incorrect payment value");
        ask.volume -= volume;
        payable(ask.seller).transfer(msg.value);
    }
}
