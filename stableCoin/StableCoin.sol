pragma solidity ^0.8.0;

contract StableCoin {
    mapping(address => uint) public balanceOf;
    mapping(address => uint) public lockedBalanceOf;
    uint public totalSupply;
    uint public targetPrice;
    uint public lockedSupply;
    uint public lastRebaseTimestamp;
    mapping(address => bool) public isLocked;

    constructor() public {
        totalSupply = 1000000;
        balanceOf[msg.sender] = totalSupply;
        targetPrice = 100;
        lockedSupply = 0;
        lastRebaseTimestamp = now;
    }

    function lock(uint _value) public {
        require(balanceOf[msg.sender] >= _value && _value > 0, "Not enough balance");
        lockedBalanceOf[msg.sender] += _value;
        balanceOf[msg.sender] -= _value;
        lockedSupply += _value;
        isLocked[msg.sender] = true;
    }

    function unlock() public {
        require(isLocked[msg.sender], "Account not locked");
        require(now >= lastRebaseTimestamp + 30 days, "Cannot unlock before 30 days");
        balanceOf[msg.sender] += lockedBalanceOf[msg.sender];
        lockedBalanceOf[msg.sender] = 0;
        lockedSupply -= lockedBalanceOf[msg.sender];
        isLocked[msg.sender] = false;
    }

    function adjustSupply() public {
        if (now >= lastRebaseTimestamp + 24 hours) {
        lastRebaseTimestamp = now;
        uint currentPrice = getCurrentPrice();
        if (currentPrice > targetPrice*1.05) {
        totalSupply = totalSupply.mul(targetPrice*1.05).div(currentPrice);
        lockedSupply = lockedSupply.mul(targetPrice*1.05).div(currentPrice);
        for (address a: addresses) {
        if (isLocked[a]) {
        balanceOf[a] = balanceOf[a].mul(targetPrice*1.05).div(currentPrice);
        }
        }
        } else if (currentPrice < targetPrice*0.95) {
        totalSupply = totalSupply.mul(targetPrice*0.95).div(currentPrice);
        lockedSupply = lockedSupply.mul(targetPrice*0.95).div(currentPrice);
        for (address a: addresses) {
            if (isLocked[a]) {
            lockedBalanceOf[a] = lockedBalanceOf[a].mul(targetPrice*0.95).div(currentPrice);
            } else {
            balanceOf[a] = balanceOf[a].mul(targetPrice*0.95).div(currentPrice);
            }

        }
        }

    }
    }

    function getCurrentPrice() private view returns (uint) {
        // This function would need to be implemented to return the current market price of the stablecoin
    }

    function restrictCirculation() public {
        require(msg.sender == address(this), "Only contract owner can call this function");
        require(totalSupply > lockedSupply, "Cannot restrict circulation when all tokens are locked");
        uint circulatingSupply = totalSupply - lockedSupply;
        if (circulatingSupply > targetPrice * 1.5) {
            totalSupply = targetPrice * 1.5;
            for (address a: addresses) {
                if (isLocked[a]) {
                continue;
                }
            balanceOf[a] = balanceOf[a].mul(targetPrice * 1.5).div(circulatingSupply);
            }
        }
    }

    function rewardLongTermHolders() public {
        require(msg.sender == address(this), "Only contract owner can call this function");
        for (address a: addresses) {
        if (isLocked[a] && now >= lastRebaseTimestamp + 6 months) {
        balanceOf[a] += lockedBalanceOf[a] * 0.1;
        }
        }
    }
}



