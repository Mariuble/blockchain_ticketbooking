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
    uint256 public seatPrice;
    address public owner;
    string information;
    Ticket t = new Ticket();

    constructor(string memory _show_title, uint256 _seat_row, uint256 _seats_per_row string memory _information) {
        show_title = _show_title; 
        available_seats = _available_seats;
        information = _information;
        owner = msg.sender;
    }

    function setSeatPrice(uint _seatPrice) public {
    require(msg.sender == owner, "Only the owner may perform this action");
    seatPrice = _seatPrice;
    }

    function buy(address payable buyer, Seat memory seat) public {
        // Generate and transfer unique ticket
        uint256 balance = buyer.balance;
        require(balance < seat.price, "Balance is too low!");
        t.mintST(buyer);
    }
}

contract Ticket is ERC721 {
    address public Minter_address;
    uint256 private tokenId;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    
    constructor() ERC721("ShowTicket", "ST"){
        tokenId = 0;
    }
    
    function mintST(address recipient) public returns(uint256){
        uint256 newItemId = tokenId;
        _mint(recipient, newItemId);
        tokenId +=1;
        return newItemId;
    }
}

abstract contract Poster is ERC721 {
    //
}

