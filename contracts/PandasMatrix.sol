//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract PandasMatrix is ReentrancyGuard {

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
    
    //Events
    event SignUp(address indexed player, address indexed referrer, uint indexed userId, uint referrerId);
    event Reinvest(address indexed player, address indexed currentReferrer, address indexed caller, uint8 matrix, uint8 level);
    event Upgrade(address indexed player, address indexed referrer, uint8 matrix, uint8 level);
    event NewUserPlace(address indexed players, address indexed referrer, uint8 matrix, uint8 level, uint8 place);
    event MissedTronReceive(address indexed receiver, address indexed from, uint8 matrix, uint8 level);
    event SentExtraTronDividends(address indexed from, address indexed receiver, uint8 matrix, uint8 level);

    constructor(address ownerAddress) {
        levelPrice[1] = 200*1e18;
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
    function registration(address userAddress, address referrerAddress) private {
        require(msg.value == levelPrice[1]*2, "registration cost 200Trn");
        require(!isPlatformUser(userAddress), "user exists");
        require(isPlatformUser(referrerAddress), "referrer not exists");
        
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        require(size == 0, "cannot be a contract");
        
        
        players[userAddress].id = lastUserId;
        players[userAddress].referrer = referrerAddress;
        players[userAddress].patners = 0;
        
        idToAddress[lastUserId] = userAddress;
        
        players[userAddress].referrer = referrerAddress;
        
        players[userAddress].activeP4Levels[1] = true; 
        players[userAddress].activeP5Levels[1] = true;
        
        
        userIds[lastUserId] = userAddress;
        lastUserId++;
        
        players[referrerAddress].patners++;

        address freep4Referrer = findFreep4Referrer(userAddress, 1);
        players[userAddress].p4Matrix[1].firstReferrer = freep4Referrer;
        
        
        updatep4Referrer(userAddress, freep4Referrer, 1);

        updatep5Referrer(userAddress, findFreep5Referrer(userAddress, 1), 1);
        
        emit SignUp(userAddress, referrerAddress, players[userAddress].id, players[referrerAddress].id);
    }

    function rg() external payable {
        if(msg.data.length == 0) {
            return registration(msg.sender, owner);
        }
        
        registration(msg.sender, bytesToAddress(msg.data));
    }

    function registrationExt(address referrerAddress) external payable nonReentrant {
        registration(msg.sender, referrerAddress);
    }


    function buyNewLevel(uint8 matrix, uint8 level) external payable nonReentrant {
        require(isPlatformUser(msg.sender), "register first");
        require(matrix == 1 || matrix == 2, "invalid choice");
        require(msg.value == levelPrice[level], "invalid amount");
        require(level > 1 && level <= SLOT_FINAL_LEVEL, "invalid level");

        if (matrix == 1) {
            require(!players[msg.sender].activeP4Levels[level], "already active");

            if (players[msg.sender].p4Matrix[level-1].blocked) {
                players[msg.sender].p4Matrix[level-1].blocked = false;
            }
    
            address freep4Referrer = findFreep4Referrer(msg.sender, level);
            players[msg.sender].p4Matrix[level].firstReferrer = freep4Referrer;
            players[msg.sender].activeP4Levels[level] = true;
            updatep4Referrer(msg.sender, freep4Referrer, level);
            
            emit Upgrade(msg.sender, freep4Referrer, 1, level);

        } else {
            require(!players[msg.sender].activeP5Levels[level], "already active"); 

            if (players[msg.sender].p5Matrix[level-1].blocked) {
                players[msg.sender].p5Matrix[level-1].blocked = false;
            }

            address freep5Referrer = findFreep5Referrer(msg.sender, level);
            
            players[msg.sender].activeP5Levels[level] = true;
            updatep5Referrer(msg.sender, freep5Referrer, level);
            
            emit Upgrade(msg.sender, freep5Referrer, 2, level);
        }
    }

    function updatep4Referrer(address userAddress, address referrerAddress, uint8 level) private {
        players[referrerAddress].p4Matrix[level].referrals.push(userAddress);

        if (players[referrerAddress].p4Matrix[level].referrals.length < 3) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(players[referrerAddress].p4Matrix[level].referrals.length));
            return sendTrnReturns(referrerAddress, userAddress, 1, level);
        }
        
        emit NewUserPlace(userAddress, referrerAddress, 1, level, 3);
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
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updatep4Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendTrnReturns(owner, userAddress, 1, level);
            players[owner].p4Matrix[level].reinvestCount++;
            emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }

    function updatep5Referrer(address userAddress, address referrerAddress, uint8 level) private {
        players[referrerAddress].p5Matrix[level].p5referrals.push(userAddress);

        if (players[referrerAddress].p5Matrix[level].p5referrals.length <= 4) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(players[referrerAddress].p4Matrix[level].referrals.length));
            return sendTrnReturns(referrerAddress, userAddress, 2, level);
        }
        if (players[referrerAddress].p5Matrix[level].p5referrals.length == 5) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(players[referrerAddress].p4Matrix[level].referrals.length));
            return sendTrnReturns(players[referrerAddress].referrer, userAddress, 2, level);
        }
        if (players[referrerAddress].p5Matrix[level].p5referrals.length == 6) {
            emit NewUserPlace(userAddress, referrerAddress, 1, level, uint8(players[referrerAddress].p4Matrix[level].referrals.length));
            return sendTrnReturns(players[players[referrerAddress].referrer].referrer, userAddress, 2, level);
        }
        
        
        
        emit NewUserPlace(userAddress, referrerAddress, 2, level, 6);
        //close matrix
        players[referrerAddress].p5Matrix[level].p5referrals = new address[](0);
        if (!players[referrerAddress].activeP5Levels[level+1] && level != SLOT_FINAL_LEVEL) {
            players[referrerAddress].p5Matrix[level].blocked = true;
        }

        //create new one by recursion
        if (referrerAddress != owner) {
            //check referrer active level
            address freeReferrerAddress = findFreep5Referrer(referrerAddress, level);
            if (players[referrerAddress].p5Matrix[level].currentReferrer != freeReferrerAddress) {
                players[referrerAddress].p5Matrix[level].currentReferrer = freeReferrerAddress;
            }
            
            players[referrerAddress].p5Matrix[level].reinvestCount++;
            emit Reinvest(referrerAddress, freeReferrerAddress, userAddress, 1, level);
            updatep5Referrer(referrerAddress, freeReferrerAddress, level);
        } else {
            sendTrnReturns(owner, userAddress, 1, level);
            players[owner].p5Matrix[level].reinvestCount++;
            emit Reinvest(owner, address(0), userAddress, 1, level);
        }
    }

    function findFreep4Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (players[players[userAddress].referrer].activeP4Levels[level]) {
                return players[userAddress].referrer;
            }
            
            userAddress = players[userAddress].referrer;
        }
        return userAddress;
    }

    function findFreep5Referrer(address userAddress, uint8 level) public view returns(address) {
        while (true) {
            if (players[players[userAddress].referrer].activeP5Levels[level]) {
                return players[userAddress].referrer;
            }
            
            userAddress = players[userAddress].referrer;
        }
        return userAddress;
    }

    function seekTronReceiver(address userAddress, address _from, uint8 matrix, uint8 level) private returns(address, bool) {
        address receiver = userAddress;
        bool isExtraDividends;
        if (matrix == 1) {
            while (true) {
                if (players[receiver].p4Matrix[level].blocked) {
                    emit MissedTronReceive(receiver, _from, 1, level);
                    isExtraDividends = true;
                    receiver = players[receiver].p4Matrix[level].firstReferrer;
                } else {
                    return (receiver, isExtraDividends);
                }
            }
        } else {
            while (true) {
                if (players[receiver].p5Matrix[level].blocked) {
                    emit MissedTronReceive(receiver, _from, 2, level);
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
            emit SentExtraTronDividends(_from, receiver, matrix, level);
        }
    }


    function playersActivep4Levels(address userAddress, uint8 level) public view returns(bool) {
        return players[userAddress].activeP4Levels[level];
    }

    function playersActivep5Levels(address userAddress, uint8 level) public view returns(bool) {
        return players[userAddress].activeP5Levels[level];
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
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
    function isPlatformUser(address player) public view returns (bool) {
        return (players[player].id != 0);
    }

}
