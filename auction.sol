// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    IERC20 public token;

    address payable public seller;
    uint public endAt;
    bool public started;
    bool public ended;

    address public highestBidder;
    uint public highestBid;
    mapping(address => uint) public bids;

    constructor(IERC20 _token, uint _startingBid) {
        token = _token;
        seller = payable(msg.sender);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");

        started = true;
        endAt = block.timestamp + 7 days;

        emit Start();
    }

    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint bal = bids[msg.sender];
        require(bal > 0, "no bid");
        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);
        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            // transfer tokens to highest bidder
            token.transfer(highestBidder, token.balanceOf(address(this)));

            seller.transfer(highestBid);
        } else {
            // return tokens to seller
            token.transfer(seller, token.balanceOf(address(this)));
        }

        emit End(highestBidder, highestBid);
    }
}
