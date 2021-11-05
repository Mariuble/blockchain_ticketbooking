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
    Ticket t = new Ticket();

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
        require(balance < seat.price, "Balance is too low!");
        t.mint(buyer);
    }
}

abstract contract Ticket is ERC721 {
    address public minter = msg.sender;
    Seat seat;
    mapping (address => uint256) public balances;
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    tokenId=0;
        // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;
    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;
    
    
    //Generate new token
    /*
    function mint(address to) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        require(_checkOnERC721Received(address(0), to, tokenId, _data)
        _holderTokens[to].add(tokenId);
        _tokenOwners.set(tokenId, to);
        emit Transfer(address(0), to, tokenId);
    }
    */
    function mint(address recipient) internal virtual
    returns (uint256)
    {
    unit256 newItemId= tokenId;
    _mint(recipient, newItemId);
    tokenId +=1;
    return newItemId;
    }
}

abstract contract Poster is ERC721 {
    //
}
