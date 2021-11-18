// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract MasterContract{
    Poster public poster;
    address public owner;
    address public showAddress;

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
       // available_shows.push(t);
        showAddress = address(t);

        return address(t);
    }
    // A function to get all posters of an address. 
    function getPosters(address recipient) public returns (string[] memory){ 
        return poster.getPosters(recipient);
    }
}

// A booking system unique for each show
contract TicketBookingSystem {
    string public show_title;
    uint256 public date;
    uint256 public seatPrice;
    address public owner;
    string public information;
    Seat[] public available_seats;
    SalesObject[] public for_sale;
    Ticket private ticket;
    Poster public poster;
    uint256 private seatRow;
    uint256 private seatPerRow;
    bool private cancel;

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

    struct SalesObject{
        uint256 tokenIdforsale;
        uint256 price;
        bool swap;
        uint256 seatNumberAim;
        uint256 seatRowAim;
        bool traded;
    }

    mapping(uint256 => address payable) owners; //token id til adresse dictionary
    mapping(uint256 => uint256) tokenIdforsale_Price;

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
        seatRow = _seat_row;
        seatPerRow = _seats_per_row;
        owner = deployer;
        information = _information;
        date = _date;
        ticket = new Ticket();
        cancel = false;
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

    //Put ticket up to sale
    function sellTicket(uint256 _selltokenId, uint256 _price, bool _swap, uint256 _seatRowAim, uint256 _setNumberAim) public{
        //Check is token is valid, by checking if it exists, owner and timestamp
        require(verify(_selltokenId, msg.sender), "Something went wrong with the selling process.");
        require(!checkTicketForSale(_selltokenId), "This ticket is already on sale.");
        SalesObject memory o =  SalesObject(_selltokenId, _price, _swap, _seatRowAim, _setNumberAim, false);
        tokenIdforsale_Price[_selltokenId]=_price;
        for_sale.push(o);
        ticket.approve(address(this), _selltokenId);
    }

    function checkTicketForSale(uint256 _tokenID) public view returns(bool) {
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
    
    //Check if the tokenID the given seatRow and seatNr (used in swap)
    function checkTicketForTrade(uint256 _tokenID, uint256 seatRowAim, uint256 seatNrAim) public view returns(bool){
        for (uint i=0; i< available_seats.length; i++){ // Bytte liste til for_sale
            Seat memory Item = available_seats[uint(i)];
            if (Item.tokenId==_tokenID && Item.number==seatNrAim && Item.row==seatRowAim){
                return true;
            } 
        }
        return false;
    }

    //Buyer calls this function, if !_swaptokenID==0 trade otherwise buy
    function tradeTicket(uint256 _tokenID, uint256 _swaptokenID) payable public {
        //Swap tickets, price difference doesnt matter.
        address payable ticketowner = payable(ticket.ownerOf(_tokenID));
        require(checkTicketForSale(_tokenID), "The ticket you are asking for is not for sale.");        
        if (_swaptokenID != 0) {
            uint256 row;
            uint256 nr;
            require(_tokenID != _swaptokenID, "Can't swap token with itself.");
            require(getOwner(_swaptokenID)==msg.sender, "You cannot swap this token, because you are not the owner.");         
            for (uint i=0; i< available_seats.length; i++){
                Seat memory Item = available_seats[uint(i)];
                if (Item.tokenId==_tokenID){
                    row = Item.row;
                    nr = Item.number;
                }
            }
            require(checkTicketForTrade(_swaptokenID, row, nr), "They dont want to trade with you"); // check seatAim and seatNumber
            
            // Transfer tickets
            getTicket().safeTransferFrom(msg.sender, ticketowner, _swaptokenID); // Guarantee transferred
            this.getTicket().safeTransferFrom(ticketowner, msg.sender, _tokenID);
        }
        
        //Buy ticket
        else{
            require(tokenIdforsale_Price[_tokenID] <= msg.sender.balance, "The balance is too low to buy this ticket.");
            //Transfer money from buyer to ticketowner
            ticketowner.transfer(tokenIdforsale_Price[_tokenID]); // Guarantees transfered
            //Remove the ticket from the listingsOnSale
            delete tokenIdforsale_Price[_tokenID];
            this.getTicket().safeTransferFrom(ticketowner, msg.sender, _tokenID);
            require(ticket.ownerOf(_tokenID) == msg.sender);
        }
        //Marks ticket as traded
        for (uint i=0; i< for_sale.length; i++){
            SalesObject memory item = for_sale[i];
            if (item.tokenIdforsale == _tokenID){
                item.traded=true;
            }
        }
    }
    
    // buy a specific seat. Function call costs
    function buy(uint256 _seatrow, uint256 _seatnumber) payable public returns(uint256){
        require(cancel == false, "The show is cancelled. You cannot buy a ticket for it.");
        require(_seatrow<=seatRow && _seatnumber<=seatPerRow && _seatrow*_seatnumber>0, "Seat does not exist");
        address buyer = payable(msg.sender);
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
                owners[tokenId] = payable(buyer);
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

    function getOwner(uint256 ticketId) public view returns (address) {
        return ticket.ownerOf(ticketId);
    }


    function verify(uint256 tokenId, address tokenOwner) public view returns (bool) {
        // Check if token exists and therefore is minted, but not spent.
        require(ticket.exists(tokenId), "Token has not been minted or is burned"); 
        require(ticket.ownerOf(tokenId) == tokenOwner, "This is not the owner");
        require(block.timestamp < date, "Your ticket has expired :(");
        return true;
    }
    
    // Refund tickets from show host if a show gets cancelled
    function refund() public payable onlyOwner { //assumes show has money because it is a kjent theater
        for (uint i=0; i< available_seats.length; i++){
            if (available_seats[uint(i)].occupied){
                uint256 tokenId = available_seats[uint(i)].tokenId;
                if(ticket.ownerOf(tokenId) == owners[tokenId]){ //correct owner address
                    owners[tokenId].transfer(available_seats[uint(i)].price); //transfer seatprice from owner to ticketowner
                    ticket.burn(tokenId);
                }
            }
        }
        cancel = true;        
    }


    function getBalance() public view returns (uint) {
        return owner.balance;
    }

    
    function validate(uint256 tokenId, address tokenOwner) public onlyOwner{
        require(verify(tokenId, tokenOwner), "");
        uint256 OneDayBefore = date - 86400;
        require(block.timestamp > OneDayBefore, "Too early to validate");
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
    uint256 private tokenId;
    
    constructor() ERC721("ShowTicket", "ST"){
        tokenId = 1;
    }



    function mintST(address recipient) external returns(uint256){
        uint256 newItemId = tokenId;
        _safeMint(recipient, newItemId); // ERC721: Internal method to mint, emit and transfer minted token
        tokenId +=1;
        // Buy function, calls minting of ticket, set ticketOwner variable, emit event to notify
        return newItemId;
    }
    
    function exists(uint256 _tokenId) view public returns (bool) {
        return _exists(_tokenId);
    }

    function burn(uint256 _tokenId) external {
        _burn(_tokenId);
    }
}

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
        MapPosterIdShow[newItemId] = show_title; //vurdere å teste om posterID finnes.
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
