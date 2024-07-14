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
    string[] private itemNames; // Changed visibility to private

    enum State { AWAITING_PAYMENT, AWAITING_CONFIRMATION, COMPLETE, DISPUTE }
    mapping(string => State) public itemState;

    modifier onlyBuyer(string memory itemName) {
        require(msg.sender == items[itemName].buyer, "Only buyer can call");
        _;
    }

    modifier onlySeller(string memory itemName) {
        require(msg.sender == items[itemName].seller, "Only seller can call");
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

    // Seller Methods

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
        itemNames.push(itemName); // Update itemNames array
    }

    function cancelListing(string memory itemName) external onlySeller(itemName) inState(itemName, State.AWAITING_PAYMENT) {
        delete items[itemName];
        itemState[itemName] = State.COMPLETE;
        removeItemName(itemName); // Remove item name from itemNames array
    }

    // Buyer Methods

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

    // Arbiter Methods

    function resolveDispute(string memory itemName, bool releaseFundsToSeller) external onlyArbiter inState(itemName, State.DISPUTE) {
        Item storage item = items[itemName];
        if (releaseFundsToSeller) {
            item.seller.transfer(item.price);
        } else {
            payable(item.buyer).transfer(item.price);
        }
        itemState[itemName] = State.COMPLETE;
    }

    // Getter Methods

    function getItemNames() external view returns (string[] memory) {
        return itemNames;
    }

    // Internal function to remove item name from array
    function removeItemName(string memory itemName) private {
        for (uint i = 0; i < itemNames.length; i++) {
            if (keccak256(bytes(itemNames[i])) == keccak256(bytes(itemName))) {
                if (i != itemNames.length - 1) {
                    itemNames[i] = itemNames[itemNames.length - 1];
                }
                itemNames.pop();
                break;
            }
        }
    }
}
