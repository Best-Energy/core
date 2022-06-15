// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract P2PMarket {
    struct Ask {
        address seller;
        uint256 price;
        uint256 volume;
        bool renewable;
    }

    struct Receipt {
        address buyer;
        address seller;
        uint256 price;
        uint256 amount;
    }

    struct Participant {
        string username;
        string avatarUrl;
        uint256 energyBought;
        uint256 energySold;
        uint256 renewablesBought;
        uint256 renewablesSold;
        //Does the participant produce renewable energy?
        bool renewable;
        //Use for the mapping to check if the participant exists
        bool isValue;
    }

    enum Stage {
        ASK,
        BUY,
        INACTIVE
    }

    Stage stage = Stage.INACTIVE;
    address private owner;
    mapping(address => Participant) private participants;
    Ask[] private asks;
    Receipt[] private receipts;

    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    event ParticipantAdded(address indexed participant);
    event ParticipantRemoved(address indexed participant);
    event AskAdded(uint256 indexed askIndex);
    event AskPriceUpdated(uint256 indexed askIndex, uint256 newPrice);
    event AskVolumeUpdated(uint256 indexed askIndex, uint256 newVolume);
    event AskBought(uint256 indexed receiptIndex);
    event ResetEvent();
    event StageChanged(Stage newStage);
    event UsernameChanged(address indexed participant);
    event AvatarUrlChanged(address indexed participant);

    modifier canAsk() {
        require(stage != Stage.INACTIVE, "Market is inactive");
        _;
    }

    modifier canBuy() {
        require(stage == Stage.BUY, "Market is not in buy stage");
        _;
    }

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
     * @dev Set current stage of the market
     */
    function setStage(Stage _stage) public isOwner {
        stage = _stage;
        emit StageChanged(stage);
    }

    /**
     * @dev Get current stage of the market
     */
    function getStage() public view returns (Stage) {
        return stage;
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        owner = newOwner;
        emit OwnerSet(owner, newOwner);
    }

    /**
     * @dev Return owner address
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    function getParticipant(address adr)
        external
        view
        returns (Participant memory)
    {
        return participants[adr];
    }

    function amParticipant() external view returns (bool) {
        return participants[msg.sender].isValue;
    }

    function addParticipant(
        string memory username,
        string memory avatarUrl,
        address publicKey,
        bool renewable
    ) external isOwner {
        participants[publicKey] = Participant(
            username,
            avatarUrl,
            0,
            0,
            0,
            0,
            renewable,
            true
        );
        emit ParticipantAdded(publicKey);
    }

    function removeParticipant(address publicKey) external isOwner {
        participants[publicKey].isValue = false;
        emit ParticipantRemoved(publicKey);
    }

    function reset() external isOwner {
        delete asks;
        delete receipts;
        stage = Stage.ASK;
        emit ResetEvent();
        emit StageChanged(Stage.ASK);
    }

    function sendAsk(uint256 price, uint256 volume)
        external
        isParticipant
        canAsk
        returns (uint256)
    {
        asks.push(
            Ask(msg.sender, price, volume, participants[msg.sender].renewable)
        );
        uint256 askIndex = asks.length - 1;
        emit AskAdded(askIndex);
        return askIndex;
    }

    function getAsk(uint256 askIndex) external view returns (Ask memory) {
        return asks[askIndex];
    }

    function getAsks() external view returns (Ask[] memory) {
        return asks;
    }

    function buy(uint256 askIndex, uint256 volume)
        external
        payable
        isParticipant
        canBuy
    {
        Ask storage ask = asks[askIndex];
        require(ask.volume >= volume, "Volume exceeds ask volume");
        uint256 totalPrice = ask.price * volume;
        require(totalPrice == msg.value, "Incorrect payment value");
        ask.volume -= volume;
        payable(ask.seller).transfer(msg.value);

        participants[msg.sender].energyBought += volume;
        participants[ask.seller].energySold += volume;
        if (ask.renewable) {
            participants[msg.sender].renewablesBought += volume;
            participants[ask.seller].renewablesSold += volume;
        }

        receipts.push(Receipt(msg.sender, ask.seller, ask.price, volume));
        emit AskBought(receipts.length - 1);
    }

    function updateAskPrice(uint256 askIndex, uint256 price)
        external
        isParticipant
        canAsk
    {
        Ask storage ask = asks[askIndex];
        require(ask.seller == msg.sender, "You are not the seller of this ask");
        ask.price = price;
        emit AskPriceUpdated(askIndex, price);
    }

    function updateAskVolume(uint256 askIndex, uint256 volume)
        external
        isParticipant
        canAsk
    {
        Ask storage ask = asks[askIndex];
        require(ask.seller == msg.sender, "You are not the seller of this ask");
        ask.volume = volume;
        emit AskVolumeUpdated(askIndex, volume);
    }

    function changeUsername(string memory username) external isParticipant {
        participants[msg.sender].username = username;
        emit UsernameChanged(msg.sender);
    }

    function changeAvatarUrl(string memory avatarUrl) external isParticipant {
        participants[msg.sender].avatarUrl = avatarUrl;
        emit AvatarUrlChanged(msg.sender);
    }

    function getReceipts() external view returns (Receipt[] memory) {
        return receipts;
    }
}
