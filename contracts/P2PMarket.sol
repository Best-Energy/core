// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IMarket.sol";
import "./MarketUpkeep.sol";
import "./CollateralOracle.sol";
import "./IdentityOracle.sol";
import "./TransmissionOracle.sol";

contract P2PMarket is IMarket {
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
        uint256 collateral;
    }

    struct Participant {
        string username;
        string avatarUrl;
        uint256 energyBought;
        uint256 energySold;
        uint256 renewablesBought;
        uint256 renewablesSold;
        uint256 deposit;
        //Does the participant produce renewable energy?
        bool renewable;
        //Use for the mapping to check if the participant exists
        bool isValue;
        bool isApproved;
        uint8 locationGroup;
    }

    MarketUpkeep public upkeeper;
    CollateralOracle public collateralOracle;
    IdentityOracle public identityOracle;
    TransmissionOracle public transmissionOracle;

    Stage stage = Stage.INACTIVE;
    address private owner;
    mapping(address => Participant) private participants;
    Ask[] private asks;
    Receipt[] private receipts;
    uint256 iteration = 0;
    mapping(uint256 => mapping(address => bool)) private hasAsk;
    mapping(uint256 => mapping(address => uint256)) private askIndicies;
    //Market Price used for collateral calculation
    uint256 private marketPrice;

    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    event ParticipantApproved(address indexed participant);
    event ParticipantRemoved(address indexed participant);
    event AskAdded(uint256 indexed askIndex);
    event AskPriceUpdated(uint256 indexed askIndex, uint256 newPrice);
    event AskVolumeUpdated(uint256 indexed askIndex, uint256 newVolume);
    event AskBought(uint256 indexed receiptIndex);
    event ResetEvent();
    event StageChanged(Stage newStage);
    event UsernameChanged(address indexed participant);
    event AvatarUrlChanged(address indexed participant);
    event Keeper(address keeper);
    event DepositDeducted(
        address indexed participant,
        uint256 amountDeducted,
        uint256 volumeNotDelivered
    );

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
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier isUpkeeper() {
        require(msg.sender == address(upkeeper), "Caller is not upkeeper");
        _;
    }

    modifier isApproved() {
        require(
            participants[msg.sender].isApproved,
            "Caller is not network participant"
        );
        _;
    }

    modifier onlyCollateralOracle() {
        require(
            msg.sender == address(collateralOracle),
            "Only Collateral Oracle can call this function"
        );
        _;
    }

    modifier onlyIdentityOracle() {
        require(
            msg.sender == address(identityOracle),
            "Only Identity Oracle can call this function"
        );
        _;
    }

    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender;
        upkeeper = new MarketUpkeep(address(this), stage);
        collateralOracle = new CollateralOracle(address(this), msg.sender);
        identityOracle = new IdentityOracle(address(this), msg.sender);
        transmissionOracle = new TransmissionOracle(address(this), msg.sender);
        emit OwnerSet(address(0), owner);
        emit Keeper(address(upkeeper));
    }

    /**
     * @dev Set current stage of the market
     */
    function setStage(Stage _stage) private {
        stage = _stage;
        emit StageChanged(stage);
    }

    /**
     * @dev Get current stage of the market
     */
    function getStage() public view override returns (Stage) {
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

    function register(
        string memory username,
        string memory avatarUrl,
        bool renewable
    ) external {
        Participant storage participant = participants[msg.sender];
        require(participant.isValue == false, "You are already registered");
        participant.username = username;
        participant.avatarUrl = avatarUrl;
        participant.renewable = renewable;
        identityOracle.requestApproval(msg.sender);
    }

    function approveParticipant(address publicKey, uint8 locationGroup)
        external
        override
        onlyIdentityOracle
    {
        require(
            participants[publicKey].isApproved == false,
            "User is already approved"
        );
        participants[publicKey].isApproved = true;
        participants[publicKey].locationGroup = locationGroup;
        emit ParticipantApproved(publicKey);
    }

    function getCostsTo(address participant) external view returns (uint256) {
        return
            getCostsBetween(
                participants[msg.sender].locationGroup,
                participants[participant].locationGroup
            );
    }

    function getCostsBetween(uint8 loc1, uint8 loc2)
        public
        view
        returns (uint256)
    {
        return transmissionOracle.getTransmissionCosts(loc1, loc2);
    }

    function retractApproval(address publicKey)
        external
        override
        onlyIdentityOracle
    {
        participants[publicKey].isApproved = false;
        emit ParticipantRemoved(publicKey);
    }

    function fundDeposit() external payable isApproved {
        participants[msg.sender].deposit += msg.value;
    }

    function withdraw(uint256 amount) external isApproved {
        require(
            stage == Stage.INACTIVE,
            "You can't withdraw if not on the inactive stage"
        );
        Participant storage participant = participants[msg.sender];
        require(
            participant.deposit >= amount,
            "You can't withdraw more than deposit"
        );
        participant.deposit -= amount;
        payable(msg.sender).transfer(amount);
    }

    function changeStage() external override isUpkeeper {
        if (stage == Stage.ASK) {
            setStage(Stage.BUY);
            return;
        }
        if (stage == Stage.BUY) {
            startSettlement();
            return;
        }

        if (stage == Stage.SETTLEMENT) {
            setStage(Stage.INACTIVE);
            return;
        }

        reset();
    }

    function startSettlement() private {
        setStage(Stage.SETTLEMENT);
        collateralOracle.invokeOracle();
        transmissionOracle.refreshCosts();
    }

    function reset() private {
        delete asks;
        delete receipts;
        iteration++;
        setStage(Stage.ASK);
        emit ResetEvent();
    }

    function sendAsk(uint256 price, uint256 volume)
        external
        isApproved
        canAsk
        returns (uint256)
    {
        require(
            hasAsk[iteration][msg.sender] == false,
            "Participant already has an ask active."
        );
        uint256 collateral = calculateCollateral(volume);
        require(
            participants[msg.sender].deposit >= collateral,
            "Insufficient collateral"
        );
        asks.push(
            Ask(msg.sender, price, volume, participants[msg.sender].renewable)
        );
        uint256 askIndex = asks.length - 1;
        hasAsk[iteration][msg.sender] == true;
        askIndicies[iteration][msg.sender] = askIndex;
        emit AskAdded(askIndex);
        return askIndex;
    }

    function calculateCollateral(uint256 volume) public view returns (uint256) {
        return volume * marketPrice;
    }

    function getOwnAsk() external view returns (Ask memory) {
        require(hasAsk[iteration][msg.sender], "You don't have an ask active");
        uint256 askIndex = askIndicies[iteration][msg.sender];
        return asks[askIndex];
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
        isApproved
        canBuy
    {
        Ask storage ask = asks[askIndex];
        require(ask.volume >= volume, "Volume exceeds ask volume");
        uint256 totalPrice = ask.price * volume;
        require(totalPrice == msg.value, "Incorrect payment value");
        uint256 collateral = calculateCollateral(volume);
        ask.volume -= volume;
        participants[msg.sender].energyBought += volume;
        participants[ask.seller].energySold += volume;
        if (ask.renewable) {
            participants[msg.sender].renewablesBought += volume;
            participants[ask.seller].renewablesSold += volume;
        }

        receipts.push(
            Receipt(msg.sender, ask.seller, ask.price, volume, collateral)
        );
        payable(ask.seller).transfer(msg.value);
        emit AskBought(receipts.length - 1);
    }

    function updateAskPrice(uint256 askIndex, uint256 price)
        external
        isApproved
        canAsk
    {
        Ask storage ask = asks[askIndex];
        require(ask.seller == msg.sender, "You are not the seller of this ask");
        ask.price = price;
        emit AskPriceUpdated(askIndex, price);
    }

    function increaseAskVolume(uint256 volume) external isApproved canAsk {
        require(hasAsk[iteration][msg.sender], "You don't have an ask active");
        uint256 askIndex = askIndicies[iteration][msg.sender];
        Ask storage ask = asks[askIndex];
        require(ask.seller == msg.sender, "You are not the seller of this ask");
        uint256 newVolume = ask.volume + volume;
        uint256 collateral = calculateCollateral(newVolume);
        require(
            participants[msg.sender].deposit >= collateral,
            "Insufficient collateral"
        );
        ask.volume = newVolume;
        emit AskVolumeUpdated(askIndex, ask.volume);
    }

    function decreaseAskVolume(uint256 volume) external isApproved canAsk {
        require(hasAsk[iteration][msg.sender], "You don't have an ask active");
        uint256 askIndex = askIndicies[iteration][msg.sender];
        Ask storage ask = asks[askIndex];
        require(ask.seller == msg.sender, "You are not the seller of this ask");
        require(
            ask.volume >= volume,
            "Cannot decrease volume more than current volume"
        );
        ask.volume -= volume;
        emit AskVolumeUpdated(askIndex, ask.volume);
    }

    function changeUsername(string memory username) external isApproved {
        participants[msg.sender].username = username;
        emit UsernameChanged(msg.sender);
    }

    function changeAvatarUrl(string memory avatarUrl) external isApproved {
        participants[msg.sender].avatarUrl = avatarUrl;
        emit AvatarUrlChanged(msg.sender);
    }

    function getReceipts() external view returns (Receipt[] memory) {
        return receipts;
    }

    function getMarketPrice() external view returns (uint256) {
        return marketPrice;
    }

    function setMarketPrice(uint256 _price)
        external
        override
        onlyCollateralOracle
    {
        marketPrice = _price;
    }

    function getAsksCount() external view returns (uint256) {
        return asks.length;
    }

    function oracleDeductDeposit(
        address participant,
        uint256 amountDeducted,
        uint256 volumeNotDelivered
    ) external override onlyCollateralOracle {
        Participant storage p = participants[participant];
        require(
            p.deposit >= amountDeducted,
            "The participant doesn't have enough deposited"
        );

        p.deposit -= amountDeducted;
        emit DepositDeducted(participant, amountDeducted, volumeNotDelivered);
    }
}
