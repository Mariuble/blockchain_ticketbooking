
// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

//Creates shows and keeps the poster for all shows
contract MasterContract{
    Poster public poster;
    address public owner;
    address[] public created_shows;

    constructor(){
        poster = new Poster();
        owner = msg.sender;
    }

    modifier onlySalesManager() {
        require(msg.sender == owner, "MasterContract: Only the sales manager may perform this action");
        _;
    }
    
    function createShow (
        string memory show_title, 
        uint256 _date,
        uint256 _price,
        uint256 _seat_row, 
        uint256 _seats_per_row,
        string  memory _information) public onlySalesManager returns(address){      
        TicketBookingSystem t = new TicketBookingSystem(show_title,_date, _price,_seat_row, _seats_per_row, _information, poster, msg.sender);
        created_shows.push(address(t));
        return address(t);
    }
    // A function to get all posters of an address. 
    function getPosters(address recipient) public returns (string[] memory){ 
        return poster.getPosters(recipient);
    }
}

// A booking system unique for each show
contract TicketBookingSystem is ERC721{
    string public show_title;
    uint256 public date;
    uint256 public seatPrice;
    address public owner;
    string public information;
    Poster private poster;
    uint256 private seatRow;
    uint256 private seatPerRow;
    bool private cancel;
    uint256 private ticketId;
    Seat[] public taken_seats;
    SalesObject[] public for_sale;

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

    //Object structure for ticket trading and selling
    struct SalesObject{ 
        uint256 tokenIdforsale;
        uint256 price;
        bool swap;
        uint256 seatNumberAim;
        uint256 seatRowAim;
        bool traded;
    }

    mapping(uint256 => address payable) owners; //map owners of bought tickets. Could use ownerOf instead
    mapping(uint256 => uint256) tokenIdforsale_Price; //Maps price of seat for sale

    constructor(
        string memory _show_title, 
        uint256 _date,
        uint256 _price,
        uint256 _seat_row, 
        uint256 _seats_per_row,
        string memory _information,
        Poster _poster, 
        address deployer
    ) ERC721("ShowTicket", "ST") {
        show_title = _show_title;
        seatPrice = _price;
        seatRow = _seat_row;
        seatPerRow = _seats_per_row;
        owner = deployer;
        information = _information;
        date = _date;
        cancel = false;
        poster = _poster;
        ticketId = 1;
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
    
    //Creates ticket
    function mintST(address recipient) internal returns(uint256){
        uint256 newItemId = ticketId;
        _safeMint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        ticketId +=1;
        return newItemId;
    }

    function setSeatPrice(uint _seatPrice) public onlyOwner {
        seatPrice = _seatPrice;
    }

    //Put ticket up to sale
    function sellTicket(uint256 _selltokenId, uint256 _price, bool _swap, uint256 _seatRowAim, uint256 _setNumberAim) public{
        //Check if token is valid
        require(verify(_selltokenId, msg.sender), "Something went wrong with the selling process.");
        require(!checkTicketForSale(_selltokenId), "This ticket is already for sale.");
        require(_seatRowAim<=seatRow && _setNumberAim<=seatPerRow && _seatRowAim*_setNumberAim>0, "Seat does not exist");

        SalesObject memory o =  SalesObject(_selltokenId, _price, _swap, _seatRowAim, _setNumberAim, false);
        tokenIdforsale_Price[_selltokenId]=_price;
        for_sale.push(o);
        approve(address(this), _selltokenId);
    }

    function checkTicketForSale(uint256 _tokenID) internal view returns(bool) {
        bool exist = false;
        for (uint i=0; i< for_sale.length; i++){
            //Check if ticket is for sale and not sold yet. 
            if (for_sale[uint(i)].tokenIdforsale==_tokenID && !for_sale[uint(i)].traded) {
                exist = true;
                break;
            }
        }
        return exist;    
    }
    
    //Check if seller open for trading with your ticket (used in swap)
    function checkTicketForTrade(uint256 _buyertokenID, uint256 seatNrAim, uint256 seatRowAim) internal view returns(bool){
        for (uint i=0; i< taken_seats.length; i++){
            Seat memory Item = taken_seats[uint(i)];
            if (Item.tokenId==_buyertokenID && Item.number==seatNrAim && Item.row==seatRowAim){ //checks correct seat nrs in buyers seat
                return true;
                }   
        }
        return false;
    }

    //Enables C and D to safely trade tickets. Price difference doesnt matter
    function tradeTicket(uint256 _sellertokenID, uint256 _buyertokenID) payable public {
        address payable ticketowner = payable(ownerOf(_sellertokenID));
        require(checkTicketForSale(_sellertokenID), "The ticket you are asking for is not for sale.");        
        
        //Trade tickets when _buyertokenID != 0
        if (_buyertokenID != 0) {
            uint256 row;
            uint256 nr;
            require(_sellertokenID != _buyertokenID, "Can't swap token with itself.");
            require(ownerOf(_buyertokenID)==msg.sender, "You cannot swap this token, because you are not the owner.");         
            for (uint i=0; i< for_sale.length; i++){
                if (for_sale[uint(i)].tokenIdforsale==_sellertokenID){
                    row = for_sale[uint(i)].seatRowAim;
                    nr = for_sale[uint(i)].seatNumberAim;
                    require(for_sale[uint(i)].swap, "They only want to trade for coins, set _sellerTokenId to 0");
                }
            }
            require(checkTicketForTrade(_buyertokenID, row, nr), "They dont want to trade with you"); // check seatAim and seatNumber
            
            // Transfer tickets
            safeTransferFrom(msg.sender, ticketowner, _buyertokenID); // Guarantee transferred
            this.safeTransferFrom(ticketowner, msg.sender, _sellertokenID);
            //Mapping used in refund
            owners[_sellertokenID] = payable(ownerOf(_sellertokenID));
            owners[_buyertokenID] = payable(ownerOf(_buyertokenID));
        }
        
        //Trade ticket for ether, when _buyertokenID == 0
        else{
            require(tokenIdforsale_Price[_sellertokenID] <= msg.sender.balance, "The balance is too low to buy this ticket.");
            require(ownerOf(_sellertokenID)!= msg.sender, "You cannot buy your own ticket.");
            //Transfer money from buyer to ticketowner
            ticketowner.transfer(tokenIdforsale_Price[_sellertokenID]); // Guarantees transfered
            //Remove the ticket from the listingsOnSale
            delete tokenIdforsale_Price[_sellertokenID];
            this.safeTransferFrom(ticketowner, msg.sender, _sellertokenID);
            require(ownerOf(_sellertokenID) == msg.sender);
        }
        //Marks ticket as traded
        for (uint i=0; i< for_sale.length; i++){
            if (for_sale[i].tokenIdforsale == _sellertokenID){
                for_sale[i].traded=true;
                owners[_sellertokenID] = payable(ownerOf(_sellertokenID));
            }
        }
    }
    
    // Checks if seat is taken
    function seatAvailable(uint256 seatrow, uint256 seatnumber) internal view returns(bool){
        for (uint i=0; i< taken_seats.length; i++){
            if((taken_seats[uint(i)].row ==seatrow) && (taken_seats[uint(i)].number ==seatnumber)){
                return false;
            }
        }
        return true;
    }
    
    // buy a specific seat if available
    function buy(uint256 seatrow, uint256 seatnumber) payable public returns(uint256){
        require(cancel == false, "The show is cancelled. You cannot buy a ticket for it.");
        require(seatrow<=seatRow && seatnumber<=seatPerRow && seatrow*seatnumber>0, "Seat does not exist");
        address buyer = payable(msg.sender);
               
        require(seatAvailable(seatrow, seatnumber),"The seat is already taken and cannot be bought.");
        uint256 balance = buyer.balance;
        require(balance >= seatPrice, "Balance is too low!");
        // Mint Ticket
        uint256 tokenId = mintST(buyer);
        //Create seat to be occupied
        require(_exists(tokenId), "Token has not been minted"); //Redundant check, guaranteed in _safeMint
        owners[tokenId] = payable(buyer);
        Seat memory seat = Seat(show_title, date, seatPrice, seatnumber, seatrow, "www.seatplan.com/showtitle", true, tokenId);
        taken_seats.push(seat);
        
        //transfers ether
        payable(owner).transfer(seatPrice);
        emit Buy(buyer, seatPrice);
         
        return tokenId;
    }
    
    //Check validity of tokenId and address
    function verify(uint256 tokenId, address tokenOwner) public view returns (bool) {
        // Check if token exists and therefore is minted, but not spent.
        require(_exists(tokenId), "Token has not been minted or is burned"); 
        require(ownerOf(tokenId) == tokenOwner, "This is not the owner");
        require(block.timestamp < date, "Your ticket has expired :(");
        return true;
    }
    
    // Refund tickets from show if a show gets cancelled
    function refund() public payable onlyOwner { 
        for (uint i=0; i< taken_seats.length; i++){
            uint256 tokenId = taken_seats[uint(i)].tokenId;
            if(ownerOf(tokenId) == owners[tokenId]){ //correct owner address and not address 0
                owners[tokenId].transfer(taken_seats[uint(i)].price); //transfer the seatprice that the owner bought the ticket for from owner to ticketowner
                _burn(tokenId);
            }
        }
        cancel = true; //no more tickets may be sold       
    }

    //Use ticket and mint poster
    function validate(uint256 tokenId, address tokenOwner) public onlyOwner{
        require(verify(tokenId, tokenOwner), "Ticket is not valid");
        uint256 OneDayBefore = date - 86400; // only available one day before show
        require(block.timestamp > OneDayBefore, "Too early to validate");
        _burn(tokenId);
        releasePoster(tokenOwner);
    }

    function releasePoster(address reciever) private {
        poster.mintPoster(reciever, show_title);
    }
}

//Proof of attendance
contract Poster is ERC721 {
    uint256 posterId;
    //mapping posterId - show
    mapping(uint256 => string) MapPosterIdShow;
    
    string[] public shows; 

    constructor() ERC721("Poster", "POS"){
         posterId = 1;
     }
    function mintPoster(address recipient, string memory show_title) external returns(uint256) {
        uint256 newItemId = posterId;
        _safeMint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        MapPosterIdShow[newItemId] = show_title; 
        posterId += 1;
        return newItemId;
        }

    function getPosters(address recipient) public returns (string[] memory){
        delete shows;
        for (uint i=1; i< posterId; i++){
            if (recipient == ownerOf(i)){
                shows.push(MapPosterIdShow[i]);
            }
        }
        return shows;
    }

}
