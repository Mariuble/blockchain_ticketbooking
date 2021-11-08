// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


// A smart contract for each show
contract TicketBookingSystem {
    // Variables
    string public show_title;
    uint256 public seatPrice;
    address public owner;
    string public information;
    Seat[] public available_seats;
    Ticket private ticket;

    struct Seat {
        string title;
        string date;
        uint256 price;
        uint256 number;
        uint256 row;
        string seat_view;
        bool occupied;
    }

    mapping(uint256 => address) owners;

    constructor(
        string memory _show_title, 
        string memory _date,
        uint256 _price,
        uint256 _seat_row, 
        uint256 _seats_per_row,
        string memory _information
    ) {
        show_title = _show_title;
        seatPrice = _price;
        owner = msg.sender;
        information = _information;

        for (uint i=0; i< _seat_row; i++){
            for (uint j=0; j< _seats_per_row; j++){
                Seat memory seat = Seat(show_title, _date, _price, j+1, i+1, "www.seatplan.com/showtitle", false);
                available_seats.push(seat);
            }
        }
    }

    function setSeatPrice(uint _seatPrice) public {
        require(msg.sender == owner, "Only the owner may perform this action");
        seatPrice = _seatPrice;
        for (uint i=0; i< available_seats.length; i++){
            available_seats[uint(i)].price = _seatPrice;
        } 
    }

    // function getMySeat() public returns (Seat) {
    //     // require(owners[msg.sender], "No seats found")
    //     return owners[msg.sender]; // null default
    // }
    
    // Each call costs
    function buy(address buyer, Seat memory seat) payable public {
        // Generate and transfer unique ticket
        require(!seat.occupied, "Seat already taken");
        uint256 balance = buyer.balance;
        require(balance < seat.price, "Balance is too low!");
        // Mint Ticket
        uint256 tokenId = ticket.mintST(buyer);
        //Set seat to be occupied
        if(tokenId >= 0){ // require mint complete
            owners[tokenId] = buyer;
            seat.occupied = true;
        }
    }

    function verify(uint256 tokenId, address tokenOwner) public view returns (bool) {
        require(ownerOf(tokenId) == tokenOwner, "This is not the owner");
        return true;
    }
    

    function refund() public {
        require(owner == msg.sender ,"Only owner can refund");
        //
    }
}

abstract contract Ticket is ERC721 { //TODO bruker ser hva ticket er
    address public Minter_address;
    uint256 private tokenId;
    // mapping(uint256 => address) private owners;
    // mapping(address => uint256) private balances;
    
    constructor() ERC721("ShowTicket", "ST"){
        tokenId = 0;
    }

    function mintST(address recipient) public returns(uint256){
        uint256 newItemId = tokenId;
        _mint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        tokenId +=1;
        // Buy function, calls minting of ticket, set ticketOwner variable, emit event to notify
        return newItemId;
    }
}

abstract contract Poster is ERC721 {

    // An overview of which shows the addresses have participated in
    // mapping(address => String[]) public participated_shows;
}
