// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract MasterContract{
    Poster public poster;
    address public owner;
    address public ticketowner;
    uint256 private nextSaleId;
    uint256 public saleID;
    TicketBookingSystem[] public available_shows;
    SalesObject[] public forSale;

    //mapping(uint256 => SalesObject) public forSale;
   // uint256 private nextShowID;
    //mapping(uint256 => TicketBookingSystem) public ticketBookingSystems;


    constructor(){
        poster = new Poster();
        owner = msg.sender;
        //Each salesobject has their unique id.
        //nextSaleId = 0;
        //Each show has unique id.
        //nextShowId = 0;
    }

    struct SalesObject {
        uint256 price;
        TicketBookingSystem ticketBookingSystem;
        uint256 tokenId;
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
        available_shows.push(t);
        ticketowner= address(t);

        return address(t);
    }

/*
    function getAvailableShows public pure returns (bytes32[]) {
        return available_shows;
    }

    function getShowName(uint256 showIndex) public returns(string){
        require(available_shows.length >= showIndex, "The index you specified does not exist");
        String showname = available_shows[showIndex].title;
        return showname;
    }
    
    function getAllSalesobject public pure returns (bytes32[]) {
        return forSale;
    }
    
    function getSalesObject(uint256 indexforSale) public returns(SalesObject){
        require(forSale.length >= indexforSale, "Index you specified does not exist");
        SalesObject o = forSale[showIndex];
        return o;
    }
*/
    
    /*
    function tradeTicket(address from, address to, uint256 ticketIdFrom, uint256 _ticketIdTo) {
        require(t.owners[ticketIdFrom] == msg.sender, "Only the owner of the ticket can trade this ticket");
        require(t.owners[_ticketIdTo] == to, "Only the owner of the ticket can trade this ticket");
        require(forSale[ticketId]); // Alltid true

    }*/
    
    //Put ticket to sale, by specifying showId, price you want to sell to, tokenId
    function sellTicket(uint256 showIndex, uint256 price, uint256 tokenId) public{
        //Check if show exists
        require(available_shows.length >= showIndex, "The index you specified does not exist");
        //Check if tokenId is valid        
        require(available_shows[showIndex].verify(tokenId, msg.sender));
        SalesObject memory o = SalesObject(price, available_shows[showIndex], tokenId);
        forSale.push(o);
        //nextSaleId += 1;
        
    }

    //We assume that the
    function buyTicketFromUser(uint256 indexforSale, uint price) public payable {
        address buyer = msg.sender;
        uint256 balance = buyer.balance;
        //The following requirements are used to check that you get the ticket you specify. 
        require(price == forSale[indexforSale].price, "The price you have specified does not match the price for the ticket.");
        //require(keccak256(abi.encodePacket(showName)) == keccak256(abi.encodePacket(forSale[indexforSale].ticketBookingSystem.show_title)), "The title of the show does not match your wanted title.");
        //require(date = forSale[indexforSale].ticketBookingSystem.date, "The date of the show does not match your wanted date.");
        //Require that the index exists in the list.
        require(indexforSale < forSale.length, "This element is not for sale");
        //Require that the buyer has enough money to buy the ticket element. 
        require(balance >= forSale[indexforSale].price, "Balance is too low!");
        //Transfer money from owner to buyer
        payable(forSale[indexforSale].ticketBookingSystem.getTicket().ownerOf(forSale[indexforSale].tokenId)).transfer(forSale[indexforSale].price);
        //Change TokenID owner
        forSale[indexforSale].ticketBookingSystem.getTicket().safeTransferFrom(buyer, owner, forSale[indexforSale].tokenId);
        //Remove ticket from forSale list. 
        forSale[indexforSale] = forSale[forSale.length - 1];
        delete forSale[forSale.length - 1];
        forSale.pop();
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
                    // Hvis error med payable, parse slik "payable(owners[tokenId]).tran..."
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

    function getTicket() public view returns (Ticket) {
        return ticket;
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
/*
    function safeTransferFrom(address from, address to, uint256 tokenId) view public {
        safeTransferFrom(from, to, tokenId);
    }
    */
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
