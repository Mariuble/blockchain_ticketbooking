// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

Struct Seat {
    string title;
    string date;
    uint price;
    uint number;
    uint row;
    string seat_view;
}

contract TicketBookingSystem {
    string show_title;
    Seat[] seats;
    // Other information
    
    function buy() public {
        
    }
}

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract Ticket {

    uint256 number;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }
}

contract Poster {
    
}