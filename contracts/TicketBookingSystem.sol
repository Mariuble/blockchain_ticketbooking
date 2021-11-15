// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract MasterContract{
    Poster public poster;
    address public owner;
    address public ticketowner;

    constructor(){
        poster = new Poster();
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner may perform this action");
        _;
    }

    function createShow(
        string memory show_title, 
        uint256 _date,
        uint256 _price,
        uint256 _seat_row, 
        uint256 _seats_per_row,
        string  memory _information) public returns(address){      
        TicketBookingSystem t = new TicketBookingSystem(show_title,_date, _price,_seat_row, _seats_per_row, _information, poster, msg.sender);
        ticketowner= address(t);
        return address(t);
    }


    
}

// A smart contract unique for each show
contract TicketBookingSystem {
    // Variables
    string public show_title;
    uint256 public date;
    uint256 public seatPrice;
    address public owner;
    string public information;
    Seat[] public available_seats;
    Ticket private ticket;
    Poster public poster;

    struct Seat {
        string title;
        uint256 date; //epoch time
        uint256 price;
        uint256 number;
        uint256 row;
        string seat_view;
        bool occupied;
        uint256 tokenId;
    }

    mapping(uint256 => address payable) owners; //token id til adresse dictionary
    mapping(address => uint256) balanceOf; 

    constructor(
        string memory _show_title, 
        uint256 _date,
        uint256 _price,
        uint256 _seat_row, 
        uint256 _seats_per_row,
        string memory _information,
        Poster _poster, 
        address deployer
    ) {
        show_title = _show_title;
        seatPrice = _price;
        owner = deployer;
        information = _information;
        date = _date;
        ticket = new Ticket();
        poster = _poster;

        for (uint i=0; i< _seat_row; i++){
            for (uint j=0; j< _seats_per_row; j++){
                Seat memory seat = Seat(show_title, _date, _price, j+1, i+1, "www.seatplan.com/showtitle", false, 0);
                available_seats.push(seat);
            }
        }
    }

    event Buy(address indexed user, uint256 etherAmount);
    event Refund(
        address indexed user,
        uint256 etherAmount,
        uint256 depositTime,
        uint256 interest
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner may perform this action");
        _;
    }

    function setSeatPrice(uint _seatPrice) public onlyOwner {
        require(msg.sender == owner, "Only the owner may perform this action");
        seatPrice = _seatPrice;
        for (uint i=0; i< available_seats.length; i++){
            if (!available_seats[uint(i)].occupied) {
                available_seats[uint(i)].price = _seatPrice;
            }
        } 
    }

    // function getMySeat() public returns (Seat) {
    //     // require(owners[msg.sender], "No seats found")
    //     return owners[msg.sender]; // null default
    // }
    

    
    // buy a specific seat. Function call costs
    //TODO edit seat object in the input to be row and number and add checks.
    function buy(address payable buyer, uint256 _seatrow, uint256 _seatnumber) payable public returns(uint256){
        uint256 tokenIdreturn;
        for (uint i=0; i< available_seats.length; i++){
            if ((available_seats[uint(i)].row ==_seatrow) && (available_seats[uint(i)].number ==_seatnumber)) {
                require(!available_seats[uint(i)].occupied, "Seat already taken");
                uint256 balance = buyer.balance;
                require(balance >= available_seats[uint(i)].price, "Balance is too low!");
                // Mint Ticket
                uint256 tokenId = ticket.mintST(buyer);

                //Set seat to be occupied
                require(ticket.exists(tokenId), "Token has not been minted");
                owners[tokenId] = buyer;
                available_seats[uint(i)].occupied = true;
                available_seats[uint(i)].tokenId = tokenId;
                tokenIdreturn = tokenId;
                payable(owner).transfer(available_seats[uint(i)].price);
                emit Buy(buyer, available_seats[uint(i)].price);
                
                break;
            }
        }
        return tokenIdreturn;
        
    }

    function verify(uint256 tokenId, address tokenOwner) public view returns (bool) {
        // Check if token exists and therefore is minted, but not spent.
        require(ticket.exists(tokenId), "Token has not been minted");
        require(ticket.ownerOf(tokenId) == tokenOwner, "This is not the owner");
        require(block.timestamp > date, "Your ticket has expired :(");
        return true;
    }
    

    function refund() public onlyOwner { //assumes show has money because it is a kjent theater
        for (uint i=0; i< available_seats.length; i++){
            if (available_seats[uint(i)].occupied){
                uint256 tokenId = available_seats[uint(i)].tokenId;
                if(ticket.ownerOf(tokenId) == owners[tokenId]){ //correct owner address
                    owners[tokenId].transfer(available_seats[uint(i)].price); //transfer seatprice from owner to ticketowner
                    ticket.burn(tokenId);
                }
            }
        }
        
    }

    function getBalance() public view returns (uint) {
        return owner.balance;
    }
    
    function validate(uint256 tokenId, address tokenOwner) public onlyOwner{
        require(verify(tokenId, tokenOwner));
        uint256 OneDayBefore = date - 86400;
        require(date < OneDayBefore, "Too early to validate");
        ticket.burn(tokenId);
        releasePoster(tokenOwner);
    }

    function releasePoster(address reciever) private {
        poster.mintPoster(reciever, show_title);
    }

}
contract Ticket is ERC721 {
    address public Minter_address;
    uint256 private tokenId;
    
    // mapping(uint256 => address) private owners;
    // mapping(address => uint256) private balances;
    
    constructor() ERC721("ShowTicket", "ST"){
        tokenId = 1;
    }



    function mintST(address recipient) public returns(uint256){
        uint256 newItemId = tokenId;
        _safeMint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        tokenId +=1;
        // Buy function, calls minting of ticket, set ticketOwner variable, emit event to notify
        return newItemId;
    }
    
    function exists(uint256 _tokenId) view public returns (bool) {
        return _exists(_tokenId);
    }

    function burn(uint256 _tokenId) public {
        _burn(_tokenId);
    }
}

contract Poster is ERC721 {
    // An overview of which shows the addresses have participated in
    // mapping(address => String[]) public participated_shows;
    //mapping(address => String[]) public hallOfFame;
    uint256 posterId;
    //mapping posterId - show
    mapping(uint256 => string) MapPosterIdShow;
    
    string[] public shows; 

    constructor() ERC721("Poster", "POS"){
         posterId = 1;
     }
    function mintPoster(address recipient, string memory show_title) public returns(uint256) {
        uint256 newItemId = posterId;
        _safeMint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        MapPosterIdShow[newItemId] = show_title; //vurdere å teste om posterID finnes.
        posterId += 1;
        return newItemId;
        }

    function getPosters(address recipient) public returns (string[] memory){
        delete shows;
        for (uint i=1; i<= posterId; i++){
            if (recipient == ownerOf(i)){
                shows.push(MapPosterIdShow[i]);
            }
        }
        return shows;
    }

}
