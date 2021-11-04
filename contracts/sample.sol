//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract PandasMatrix {

    struct Player {
        uint id;
        address referrer;
        uint patners;
        
        mapping(uint8 => bool) activeP4Levels;
        mapping(uint8 => bool) activeP5Levels;
        
        mapping(uint8 => P4) p4Matrix;
        mapping(uint8 => P5) p5Matrix;
    }
    
    struct P4 {
        address firstReferrer;
        address[] referrals;
        bool blocked;
        uint reinvestCount;
    }
    
    struct P5 {
        address currentReferrer;
        address[] p5referrals;
        bool blocked;
        uint reinvestCount;
        address closedPart;
    }

    uint128 public constant SLOT_FINAL_LEVEL = 15;
    
    mapping(address => Player) public players;
    mapping(uint => address) public idToAddress;
    mapping(uint => address) public userIds;
    mapping(address => uint) public balances; 

    uint public lastUserId = 2;
    address public owner;
    
    mapping(uint8 => uint) public levelPrice;

    constructor(address ownerAddress) {
        levelPrice[1] =25*1e14;
        for (uint8 i = 2; i <= SLOT_FINAL_LEVEL; i++) {
            levelPrice[i] = levelPrice[i-1] * 2;
        }
        
        owner = ownerAddress;
        
        players[ownerAddress].id = 1;
        players[ownerAddress].referrer = address(0);
        players[ownerAddress].patners = uint(0);
        
        idToAddress[1] = ownerAddress;
        
        for (uint8 i = 1; i <= SLOT_FINAL_LEVEL; i++) {
            players[ownerAddress].activeP4Levels[i] = true;
            players[ownerAddress].activeP5Levels[i] = true;
        }
        userIds[1] = ownerAddress;
    }

    function playersActivep4Levels(address userAddress, uint8 level) public view returns(bool) {
        return players[userAddress].activeP4Levels[level];
    }

    function playersActivep5Levels(address userAddress, uint8 level) public view returns(bool) {
        return players[userAddress].activeP5Levels[level];
    }

    function playersp4Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool) {
        return (players[userAddress].p4Matrix[level].firstReferrer,
                players[userAddress].p4Matrix[level].referrals,
                players[userAddress].p4Matrix[level].blocked);
    }

    function playersp5Matrix(address userAddress, uint8 level) public view returns(address, address[] memory, bool, address) {
        return (players[userAddress].p5Matrix[level].currentReferrer,
                players[userAddress].p5Matrix[level].p5referrals,
                players[userAddress].p5Matrix[level].blocked,
                players[userAddress].p5Matrix[level].closedPart);
    }
    //checks if the user already exists
    function isUserExists(address user) public view returns (bool) {
        return (players[user].id != 0);
    }

    function updatep4Referrer(address userAddress, address referrerAddress, uint8 level) private {
        players[referrerAddress].p4Matrix[level].referrals.push(userAddress);

        if (players[referrerAddress].p4Matrix[level].referrals.length < 3) {
            //emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(users[referrerAddress].x3Matrix[level].referrals.length));
            return sendTrnReturns(referrerAddress, userAddress, 1, level);
        }
        
        //emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
        //close matrix
        players[referrerAddress].p4Matrix[level].referrals = new address[](0);
        if (!players[referrerAddress].activeP4Levels[level+1] && level != SLOT_FINAL_LEVEL) {
            players[referrerAddress].p4Matrix[level].blocked = true;
        }

        //create new one by recursion
        if (referrerAddress != owner) {
            //check referrer active level
            address freeReferrerAddress = findFreep4Referrer(referrerAddress, level);
            if (players[referrerAddress].p4Matrix[level].firstReferrer != freeReferrerAddress) {
                players[referrerAddress].p4Matrix[level].firstReferrer = freeReferrerAddress;
            }
            
            players[referrerAddress].p4Matrix[level].reinvestCount++;
            //emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updatep4Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendTrnReturns(owner, userAddress, 1, level);
            players[owner].p4Matrix[level].reinvestCount++;
            //emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }

    function findFreep4Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (players[players[userAddress].referrer].activeP4Levels[level]) {
                return players[userAddress].referrer;
            }
            
            userAddress = players[userAddress].referrer;
        }
    }
    
    function findFreep5Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (players[players[userAddress].referrer].activeP5Levels[level]) {
                return players[userAddress].referrer;
            }
            
            userAddress = players[userAddress].referrer;
        }
    }
    
   function seekTronReceiver(address userAddress, address _from, uint8 matrix, uint8 level) private returns(address, bool) {
        address receiver = userAddress;
        bool isExtraDividends;
        if (matrix == 1) {
            while (true) {
                if (players[receiver].p4Matrix[level].blocked) {
                    //emit MissedEthReceive(receiver, _from, 1, level);
                    isExtraDividends = true;
                    receiver = players[receiver].p4Matrix[level].firstReferrer;
                } else {
                    return (receiver, isExtraDividends);
                }
            }
        } else {
            while (true) {
                if (players[receiver].p5Matrix[level].blocked) {
                    //emit MissedEthReceive(receiver, _from, 2, level);
                    isExtraDividends = true;
                    receiver = players[receiver].p5Matrix[level].currentReferrer;
                } else {
                    return (receiver, isExtraDividends);
                }
            }
        }
    }

    function sendTrnReturns(address userAddress, address _from, uint8 matrix, uint8 level) private {
        (address receiver, bool isExtraDividends) = seekTronReceiver(userAddress, _from, matrix, level);

        if (!payable(address(uint160(receiver))).send(levelPrice[level])) {
            return payable(address(uint160(receiver))).transfer(address(this).balance);
        }
        
        if (isExtraDividends) {
            //emit SentExtraEthDividends(_from, receiver, matrix, level);
        }
    }


} 