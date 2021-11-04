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

    constructor() {

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

}