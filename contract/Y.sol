pragma solidity 0.4.18;


contract Y {
    address owner;
    mapping(address => uint) public nums; // donation proportion numerators
    mapping(address => uint) public denoms; // donation proportion denominators
    // TODO cheaper to use mapping(address => Proportion), where Proportion is struct {uint num, uint denom}?
    // TODO function to delete contract from blockchain (only owner can call it)
    // TODO is there a gas cost difference between external and public labels on functions?

    function Y () {
        owner = msg.sender;
    }

    // * num and denom are valid if num is more than 0 and less than denom, and denom is less than or equal to Solidity's maximum uint.

    /// Only use payAndDonate if num is more than 0 and less than denom, msg.value multiplied by num will be less than or equal to Solidity's maximum uint, and donation will not be 0 (e.g. 1 / 2 is 0, as 0.5 is not a uint). Donation may not be exactly donation percent multiplied by msg.value (e.g. 7.9% of 100 will be 7, as 7.9 is not a uint).
    function payAndDonate(address payee, address donee) external payable {
        uint donation = (msg.value * nums[payee]) / denoms[payee];
        donee.transfer(donation);
        payee.transfer(msg.value - donation);
    }

    /// Only use setNumAndDenom if _num and _denom are valid*.
    function setNumAndDenom(uint _num, uint _denom) external {
        nums[msg.sender] = _num;
        denoms[msg.sender] = _denom;
    }

    /// For e.g. 4% (1/25) to 8% (2/25). Use as per setNumAndDenom.
    function setNum(uint _num) external {
        nums[msg.sender] = _num;
    }

    /// For e.g. 1% (1/100) to 2% (1/50). Use as per setNumAndDenom.
    function setDenom(uint _denom) external {
        denoms[msg.sender] = _denom;
    }

    function close() external {
        require(msg.sender == owner);
        selfdestruct(owner);
    }
}
