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

// add status of property - not rented, rented
// allow for shared property, multiple tenants, remove selected tenant based on index
// 3. put for sale
// 4. buy nft
// 5. burn the token at end of sale

contract RealEstateToken is ERC20, Ownable, ERC721Holder {
    using SafeMath for uint256;

    address[] public stakeholders;

    mapping(address => uint256) public revenues;
    string public status;
    uint256 public tokenPrice;
    uint256 public accumulated;
    uint256 public rent;
    address public tenantAddress;

    IERC721 public collection;
    uint256 public tokenId;
    bool public initialized = false;

    constructor(address _owner, string memory name_, string memory symbol_) ERC20(name_, symbol_)
        public
    {   
        stakeholders.push(_owner);
        // _mint(_owner, _supply);
    }

    function initialize(address _collection, uint256 _tokenId, uint256 _amount, uint256 _tokenPrice, uint256 _rent ) external onlyOwner {
        require(!initialized, "Already initialized");
        require(_amount > 0, "Amount needs to be more than 0");
        collection = IERC721(_collection);
        collection.safeTransferFrom(msg.sender, address(this), _tokenId);
        tokenId = _tokenId;
        initialized = true;
        tokenPrice = _tokenPrice;
        rent = _rent*10**18;
        status = "notRented";
        _mint(msg.sender, _amount);
    }

    function deposit()
        external
        payable
    {
        accumulated += msg.value;
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
            accumulated = accumulated.sub(revenue);
            revenues[stakeholder] = revenues[stakeholder].add(revenue);
        }
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            address stakeholder = stakeholders[s];
            uint256 revenue = revenues[stakeholder];
            revenues[stakeholder] = 0;
            payable(stakeholder).transfer(revenue);
        }
    }

    function withdrawStake()
        public
    {
        uint256 index;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            if(stakeholders[s]==msg.sender){
                index = s;
            }
        }
        // payout(stakeholders[index])
        _transfer(msg.sender, stakeholders[0], balanceOf(stakeholders[index]));
    }


    // only owner can rent out the estate
    function rentToTenant(address _tenantAddress) 
        public 
        onlyOwner
        returns(bool)
    {
        tenantAddress = _tenantAddress;
        return true;
    }

    // only tenant can pay the rent
    function rentPayment()
        public payable
        returns(bool)
    {
        uint256 money = msg.value;
        require(msg.sender==tenantAddress, "Only Tenant can pay rent");
        require(money==rent, "Send Exact Rent");
        accumulated+=money;        
    }

// which tenant to be removed
    function removeTenant()
        public
        onlyOwner
    {
        require(tenantAddress!=address(0));
        tenantAddress=address(0);
        // sets it as 0x0000000000000000000000000000000000000000
    }


    // 
}
