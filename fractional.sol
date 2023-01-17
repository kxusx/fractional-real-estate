pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2

contract RealEstateToken is ERC20, Ownable {
    using SafeMath for uint256;

    address[] public stakeholders;

    mapping(address => uint256) public revenues;
    uint256 public tokenPrice;
    uint256 public accumulated;

    constructor(address _owner, uint256 _supply, string memory name_, string memory symbol_, uint256 _tokenPrice ) ERC20(name_, symbol_)
        public
    {   
        tokenPrice = _tokenPrice;
        stakeholders.push(_owner);
        _mint(_owner, _supply);
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

        (bool isStakeholder, ) = isStakeholder(msg.sender);
        require(isStakeholder);
        // stakeholders[0] is owner
        (bool sent, ) = stakeholders[0].call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        // owner transfers tokens
        _transfer(stakeholders[0],msg.sender, money/(tokenPrice*10**18));
        return true;
        // payable(owner).transfer(purchasePrice);
    }

    // //  Transfers are only allowed to registered stakeholders.
    // function transfer(address _recipient, uint256 _amount)
    //     public override
    //     returns (bool)
    // {
    //     (bool isStakeholder, ) = isStakeholder(_recipient);
    //     require(isStakeholder);
    //     _transfer(msg.sender, _recipient, _amount);
    //     return true;
    // }

    // ---------- STAKEHOLDERS ----------

    
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
    }

    function withdraw()
        public
    {
        uint256 revenue = revenues[msg.sender];
        revenues[msg.sender] = 0;
        payable(msg.sender).transfer(revenue);
    }
}
