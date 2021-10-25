// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

struct Seat {
    string title;
    string date;
    uint256 price;
    uint256 number;
    uint256 row;
    string seat_view;
}

// A smart contract for each show
contract TicketBookingSystem {
    // Variables
    string show_title;
    Seat[] available_seats;
    address public owner;
    string information;

    constructor(
        string memory _show_title,
        Seat[] memory _available_seats,
        string memory _information
    ) {
        show_title = _show_title;
        available_seats = _available_seats;
        information = _information;
        owner = msg.sender;
    }

    function buy(address payable buyer, Seat memory seat) public {
        // Generate and transfer unique ticket
        uint256 balance = buyer.balance;
        if (balance < seat.price) {
            // throw;
        }
    }
}

abstract contract Ticket is ERC721 {
    address public minter = msg.sender;
    Seat seat;

    function mint(address to) public {
        //
    }
}

abstract contract Poster is ERC721 {
    //
}
