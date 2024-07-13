// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MarketplaceEscrow {
    struct Item {
        string name;
        uint price;
        address payable seller;
        address buyer;
        bool sold;
        bool fundsReleased;
    }

    address public arbiter;
    mapping(string => Item) public items;

    enum State { AWAITING_PAYMENT, AWAITING_CONFIRMATION, COMPLETE, DISPUTE }
    mapping(string => State) public itemState;

    modifier onlyBuyer(string memory itemName) {
        require(msg.sender == items[itemName].buyer, "Only buyer can call this method");
        _;
    }

    modifier onlySeller(string memory itemName) {
        require(msg.sender == items[itemName].seller, "Only seller can call this method");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter can call this method");
        _;
    }

    modifier inState(string memory itemName, State expectedState) {
        require(itemState[itemName] == expectedState, "Invalid state");
        _;
    }

    constructor(address _arbiter) {
        arbiter = _arbiter;
    }

    function listItem(string memory itemName, uint itemPrice) external {
        require(items[itemName].seller == address(0), "Item already listed");
        items[itemName] = Item({
            name: itemName,
            price: itemPrice,
            seller: payable(msg.sender),
            buyer: address(0),
            sold: false,
            fundsReleased: false
        });
        itemState[itemName] = State.AWAITING_PAYMENT;
    }

    function buyItem(string memory itemName) external payable inState(itemName, State.AWAITING_PAYMENT) {
        Item storage item = items[itemName];
        require(msg.value == item.price, "Incorrect amount sent");
        item.buyer = msg.sender;
        item.sold = true;
        itemState[itemName] = State.AWAITING_CONFIRMATION;
    }

    function confirmReceived(string memory itemName) external onlyBuyer(itemName) inState(itemName, State.AWAITING_CONFIRMATION) {
        Item storage item = items[itemName];
        item.fundsReleased = true;
        item.seller.transfer(item.price);
        itemState[itemName] = State.COMPLETE;
    }

    function raiseDispute(string memory itemName) external onlyBuyer(itemName) inState(itemName, State.AWAITING_CONFIRMATION) {
        itemState[itemName] = State.DISPUTE;
    }

    function resolveDispute(string memory itemName, bool releaseFundsToSeller) external onlyArbiter inState(itemName, State.DISPUTE) {
        Item storage item = items[itemName];
        if (releaseFundsToSeller) {
            item.seller.transfer(item.price);
        } else {
            payable(item.buyer).transfer(item.price);
        }
        itemState[itemName] = State.COMPLETE;
    }

    function cancelListing(string memory itemName) external onlySeller(itemName) inState(itemName, State.AWAITING_PAYMENT) {
        delete items[itemName];
        itemState[itemName] = State.COMPLETE;
    }
}
