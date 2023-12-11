// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./SafeMath.sol";

contract IDOLaunchpad {
    using SafeMath for uint256;

    address public owner;
    uint256 public tokenPrice;
    uint256 public minInvestment;
    uint256 public maxInvestment;
    uint256 public saleDurationInSeconds;
    uint256 public totalTokensSold;
    bool public isSaleActive;
    IERC20 public memeCoinToken;

    uint256 public saleStartTime;
    uint256 public saleEndTime;

    mapping (address => uint256) public investments;
    mapping (address => uint256) public tokensPurchased;

    event SaleStarted(uint256 startTime, uint256 endTime);
    event SaleStopped(uint256 endTime);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function"); 
        _;
    }

    constructor(address _tokenAddress, uint256 _price, uint256 _minInvestment, uint256 _maxInvestment, uint256 _durationInDays) {
        owner = msg.sender;
        memeCoinToken = IERC20(_tokenAddress);
        tokenPrice = _price;
        minInvestment = _minInvestment;
        maxInvestment = _maxInvestment;
        saleDurationInSeconds = _durationInDays * 1 days;
        isSaleActive = false;
    }

    function startSale() external onlyOwner {
        require(!isSaleActive, "Sale is already active");
        saleStartTime = block.timestamp;
        saleEndTime = saleStartTime + saleDurationInSeconds;
        isSaleActive = true;
        emit SaleStarted(saleStartTime, saleEndTime);
    }

    function stopSale() external onlyOwner {
        require(isSaleActive, "Sale is not active");
        isSaleActive = false;
        emit SaleStopped(block.timestamp);
    }

    function buyTokens(uint256 _amount) external payable {
        require(isSaleActive, "Sale is not active");
        require(block.timestamp <= saleEndTime, "Sale has ended");
        require(msg.value >= minInvestment, "Amount sent is below the minimum investment");
        require(msg.value <= maxInvestment, "Amount sent exceeds the maximum investment");
        require(totalTokensSold.add(_amount) <= memeCoinToken.balanceOf(address(this)), "Insufficient tokens available for sale");

        uint256 cost = _amount.mul(tokenPrice);
        require(msg.value >= cost, "Insufficient funds sent");

        memeCoinToken.transfer(msg.sender, _amount);
        investments[msg.sender] = investments[msg.sender].add(msg.value);
        tokensPurchased[msg.sender] = tokensPurchased[msg.sender].add(_amount);
        totalTokensSold = totalTokensSold.add(_amount);

        emit TokensPurchased(msg.sender, _amount, cost);
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(!isSaleActive, "Sale is still active");
        uint256 unsoldTokens = memeCoinToken.balanceOf(address(this)).sub(totalTokensSold);
        memeCoinToken.transfer(owner, unsoldTokens);
    }

    function claimTokens() external {
        require(!isSaleActive, "Sale is still active");
        require(tokensPurchased[msg.sender] > 0, "No tokens to claim");

        uint256 tokensToClaim = tokensPurchased[msg.sender];
        tokensPurchased[msg.sender] = 0;
        memeCoinToken.transfer(msg.sender, tokensToClaim);
    }

    function participateInGame(uint256 _amount) external {
        require(isSaleActive, "Sale is not active");
        require(_amount > 0, "Invalid amount");

        uint256 gasFee = tx.gasprice.mul(gasleft());

        uint256 tokensToReceive = _amount.mul(tokenPrice).div(1e18);
        uint256 totalInvestment = _amount.sub(gasFee);

        memeCoinToken.transferFrom(owner, msg.sender, tokensToReceive);

        investments[msg.sender] = investments[msg.sender].add(totalInvestment);
        tokensPurchased[msg.sender] = tokensPurchased[msg.sender].add(tokensToReceive);
        totalTokensSold = totalTokensSold.add(tokensToReceive);

        emit TokensPurchased(msg.sender, tokensToReceive, totalInvestment);
    }
}
