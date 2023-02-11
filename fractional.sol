pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
//0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db

contract RealEstateToken is ERC20, Ownable, ERC721Holder {
    using SafeMath for uint256;

    address[] public stakeholders;

    // status, can change to enum
    uint public status;
    // 0-> unrented
    // 1-> rented
    // 2 -> for sale

    mapping(address => uint256) public revenues;
    uint256 public tokenPrice;
    uint256 public accumulated;

    IERC721 public collection;
    uint256 public tokenId;
    bool public initialized = false;

    bool public forSale = false;
    uint256 public salePrice;
    bool public canRedeem = false;

    struct tenant{
        address tenantAddress;
        uint rent;
    }
    tenant[] public tenants;

    struct stakeSale{
        address stakeholder;
        uint256 noOfTokens;
        uint256 priceOfToken;
    }
    stakeSale[] public stakeSales;

    function sellStake(uint256 _noOfTokens, uint256 _priceOfToken) external returns(bool){
        require(_noOfTokens > 0, "Amount needs to be more than 0");
        require(_priceOfToken > 0, "Price needs to be more than 0");
        require(balanceOf(msg.sender) >= _noOfTokens, "Not enough tokens to sell");
        stakeSales.push(stakeSale(msg.sender, _noOfTokens, _priceOfToken));
        return true;
    }

    function buyStake(uint256 _index) external payable returns(bool){
        require(_index < stakeSales.length, "Index out of bounds");
        require(msg.value >= stakeSales[_index].priceOfToken*stakeSales[_index].noOfTokens, "Not enough money");
        require(balanceOf(stakeSales[_index].stakeholder) >= stakeSales[_index].noOfTokens, "Not enough tokens to sell");
        _transfer(stakeSales[_index].stakeholder, msg.sender, stakeSales[_index].noOfTokens);
        address payable _stakeholder = payable(stakeSales[_index].stakeholder);
        (bool sent, ) = _stakeholder.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        stakeSales.pop();
        return true;
    }


    constructor(address _owner, string memory name_, string memory symbol_) ERC20(name_, symbol_)
        public
    {   
        stakeholders.push(_owner);
    }

    function initialize(address _collection, uint256 _tokenId, uint256 _noOfTokens, uint256 _tokenPrice) external onlyOwner {
        require(!initialized, "Already initialized");
        require(_noOfTokens > 0, "Amount needs to be more than 0");
        collection = IERC721(_collection);
        collection.safeTransferFrom(msg.sender, address(this), _tokenId);
        tokenId = _tokenId;
        initialized = true;
        tokenPrice = _tokenPrice;
        status = 0; // unrented
        _mint(msg.sender, _noOfTokens);
    }

    function buy()
        public
        payable
        returns(bool)
    {
        uint256 money = msg.value;

        // stakeholders[0] is owner
        (bool sent, ) = stakeholders[0].call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        // owner transfers tokens
        _transfer(stakeholders[0],msg.sender, money/(tokenPrice*10**18));
        
        // if sender is not a stakeholder, add him
        (bool _isStakeholder, ) = isStakeholder(msg.sender);
        if (!_isStakeholder) stakeholders.push(msg.sender);
        return true;
    }

    
    function isStakeholder(address _address)
        public
        view
        returns(bool, uint256)
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            if (_address == stakeholders[s]) return (true, s);
        }
        return (false, 0);
    }

    function addStakeholder(address _stakeholder)
        public
        onlyOwner
    {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if (!_isStakeholder) stakeholders.push(_stakeholder);
    }

    function removeStakeholder(address _stakeholder)
        public
        onlyOwner
    {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if (_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }

    
    function getShare(address _stakeholder)
        public
        view
        returns(uint256)
    {
        return balanceOf(_stakeholder) / totalSupply();
    }


    function distribute()
        public
        onlyOwner
    {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 revenue = address(this).balance * balanceOf(stakeholder) / totalSupply(); 
            revenues[stakeholder] = revenues[stakeholder].add(revenue);
        }
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 revenue = revenues[stakeholder];
            revenues[stakeholder] = 0;
            payable(stakeholder).transfer(revenue);
        }
    }

    // ---------------------------------------------------------------
    // RENT STUFF
    // array of tenant requests
    address[] public tenantRequests;

//  tenant requests to rent
    function requestToRent()
        public
        returns(bool)
    {
        tenantRequests.push(msg.sender);
        return true;
    }

    // owner accepts the request
    function acceptRequest(uint _index, uint _rent)
        public
        onlyOwner
        returns(bool)
    {
        require(_index < tenantRequests.length, "Index out of bounds");
        tenants.push(tenant(tenantRequests[_index], _rent));

        tenantRequests[_index] = tenantRequests[tenantRequests.length - 1];
        tenantRequests.pop();
        return true;
    }

    // owner rejects the request
    function rejectRequest(uint _index)
        public
        onlyOwner
        returns(bool)
    {
        require(_index < tenantRequests.length, "Index out of bounds");
        tenantRequests[_index] = tenantRequests[tenantRequests.length - 1];
        tenantRequests.pop();
        return true;
    }


    // only tenant can pay the rent
    function rentPayment()
        public payable
    {
        uint256 moneySent = msg.value;
        uint rent;
        
        // check for isTenant
        bool isTenant = false;
        for(uint i = 0; i< tenants.length; i++){
            if(msg.sender == tenants[i].tenantAddress){
                isTenant = true;
                rent = tenants[i].rent;
            }
        }
        require(isTenant==true, "Only Tenant can pay rent");

        // check for exact rent
        // require(money==rent/tenantAddresses.length, "Send Exact Rent");
        require(moneySent == rent, "Send Exact Rent");

        accumulated+=moneySent;
    }
    // ---------------------------------------------------------------

    // PUT FOR SALE
    function putForSale(uint256 price) external onlyOwner {
        salePrice = price*10**18;
        forSale = true;
    }

    // ---------------------------------------------------------------
    // Multi Sig Process

    // 1. Owner calls putForSale()
    // 2. Interested buyers can call submitProposalToBuy to submit their offers
    // 3. Stakeholders vote on each proposal by calling confirmProposal()
    // 4. Owner approves on of the eligibile proposals 
    // 5. Buyer completes the sale process by paying to the contract and receiving the nft
    // 6. Stakeholders can redeem their payouts

    uint proposedPrice=0;
    bool proposalRecieved = false;
    uint noOfConfirmations;
    address finalBuyer;
    uint finalSalePrice;
    bool sold = false;

    struct Proposal{
        address buyer;
        uint proposedPrice;
        uint noOfConfirmations;
    }

    Proposal[] public proposals;
    
    // create a mapping to store the confirmations of each transaction by each stakeholder
    mapping(uint => mapping(address => bool)) public isConfirmed;

    function submitProposalToBuy(uint _value) 
        public 
    {
        require(forSale, "Not for sale");
        proposedPrice = _value*10**18;
        if(forSale==true && proposedPrice>salePrice){
            proposalRecieved = true;
            proposals.push(Proposal(msg.sender, proposedPrice, 0));
        }
        // emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

     function confirmProposal(uint _txIndex)
        public
    {
        require(forSale,"Not for Sale");
        require(_txIndex<proposals.length, "Invalid Transaction Index");
        (bool _isStakeholder, uint256 s) = isStakeholder(msg.sender);
        require(_isStakeholder, "Not a stakeholder");
        require(isConfirmed[_txIndex][msg.sender]==false, "Already Confirmed");

        Proposal storage proposal = proposals[_txIndex];
        isConfirmed[_txIndex][msg.sender] = true;
        proposal.noOfConfirmations++;
    }

    function executeTransaction(uint _txIndex)
        public
    {
        require(forSale,"Not for Sale");
        require(_txIndex<proposals.length, "Invalid Transaction Index");

        Proposal storage proposal = proposals[_txIndex];
        require(proposal.noOfConfirmations>=stakeholders.length, "Not enough confirmations");
        sold = true;
        
        forSale = false;
        finalSalePrice = proposal.proposedPrice;
        finalBuyer = proposal.buyer;
    }

    function purchaseBuyer() external payable {
        require(sold, "Not Sold Yet");
        require(msg.sender==finalBuyer, "Not the final buyer");
        require(msg.value >= finalSalePrice, "Not enough ether sent");

        // collection.transferFrom(address(this), msg.sender, tokenId);

        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 revenue = address(this).balance * balanceOf(stakeholder) / totalSupply(); 
            revenues[stakeholder] = revenues[stakeholder].add(revenue);
            payable(stakeholder).transfer(revenue);
            revenues[stakeholder] = 0;
        }

        forSale = false;
        canRedeem = true;
    }

    // ---------------------------------------------------------------

    // 1. Owner calls putForSale
    // 2. Owner deposits salePrice funds into contract
    // 3. Stakeholder redeem their stake, and transfer their tokens to owner
    // 4. Now buyer can purchase only if owner has all the tokens
    
    function deposit()
        external
        onlyOwner
        payable
    {
        require(msg.value >= salePrice, "Not enough ether sent");
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 revenue = address(this).balance * balanceOf(stakeholder) / totalSupply(); 
            revenues[stakeholder] = revenues[stakeholder].add(revenue);
        }
        canRedeem = true;
    }

// change owner of contract
    function purchase() external payable {
        require(forSale, "Not for sale");
        require(msg.value >= salePrice, "Not enough ether sent");
        require(balanceOf(stakeholders[0])==totalSupply(),"Owner still does not have all tokens");

        collection.transferFrom(address(this), msg.sender, tokenId);
         _burn(stakeholders[0], balanceOf(stakeholders[0]));

        (bool sent, ) = stakeholders[0].call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        forSale = false;
        canRedeem = false;
    }

    function redeem() external {
        require(canRedeem, "Redemption not available");
        uint256 index;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            if(stakeholders[s]==msg.sender){
                index = s;
            }
        }

        address stakeholder = stakeholders[index];
        uint256 revenue = revenues[stakeholder];
        revenues[stakeholder] = 0;
        payable(stakeholder).transfer(revenue);
         _transfer(msg.sender,stakeholders[0], balanceOf(stakeholder));
    }
}
