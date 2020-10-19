{"GTRX.sol":{"content":"\r\npragma solidity ^0.4.25;\r\n\r\ncontract Token {\r\n\r\n    function totalSupply() constant returns (uint256 supply) {}\r\n    function balanceOf(address _owner) constant returns (uint256 balance) {}\r\n    function transfer(address _to, uint256 _value) returns (bool success) {}\r\n    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}\r\n    function approve(address _spender, uint256 _value) returns (bool success) {}\r\n    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}\r\n\r\n    event Transfer(address indexed _from, address indexed _to, uint256 _value);\r\n    event Approval(address indexed _owner, address indexed _spender, uint256 _value);\r\n\r\n}\r\n\r\ncontract StandardToken is Token {\r\n\r\n    function transfer(address _to, uint256 _value) returns (bool success) {\r\n        if (balances[msg.sender] \u003e= _value \u0026\u0026 _value \u003e 0) {\r\n            balances[msg.sender] -= _value;\r\n            balances[_to] += _value;\r\n            Transfer(msg.sender, _to, _value);\r\n            return true;\r\n        } else { return false; }\r\n    }\r\n\r\n    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {\r\n        if (balances[_from] \u003e= _value \u0026\u0026 allowed[_from][msg.sender] \u003e= _value \u0026\u0026 _value \u003e 0) {\r\n            balances[_to] += _value;\r\n            balances[_from] -= _value;\r\n            allowed[_from][msg.sender] -= _value;\r\n            Transfer(_from, _to, _value);\r\n            return true;\r\n        } else { return false; }\r\n    }\r\n\r\n    function balanceOf(address _owner) constant returns (uint256 balance) {\r\n        return balances[_owner];\r\n    }\r\n\r\n    function approve(address _spender, uint256 _value) returns (bool success) {\r\n        allowed[msg.sender][_spender] = _value;\r\n        Approval(msg.sender, _spender, _value);\r\n        return true;\r\n    }\r\n\r\n    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {\r\n      return allowed[_owner][_spender];\r\n    }\r\n\r\n    mapping (address =\u003e uint256) balances;\r\n    mapping (address =\u003e mapping (address =\u003e uint256)) allowed;\r\n    uint256 public totalSupply;\r\n}\r\n\r\ncontract GTRX is StandardToken { \r\n    string public name;                  \r\n    uint8 public decimals;                \r\n    string public symbol;                 \r\n    string public version = \u0027H1.0\u0027;\r\n    uint256 public unitsOneEthCanBuy;     \r\n    uint256 public totalEthInWei;         \r\n    address public fundsWallet;           \r\n\r\n    function GTRX() {\r\n        balances[msg.sender] = 100000000000000000000000;            \r\n        totalSupply = 100000000000000000000000;                     \r\n        name = \"Grid Trade\";                                  \r\n        decimals = 18;                                               \r\n        symbol = \"GTRX\";                                             \r\n        unitsOneEthCanBuy = 100;                                  \r\n        fundsWallet = msg.sender;                                   \r\n    }\r\n\r\n    function() public payable{\r\n        totalEthInWei = totalEthInWei + msg.value;\r\n        uint256 amount = msg.value * unitsOneEthCanBuy;\r\n        require(balances[fundsWallet] \u003e= amount);\r\n\r\n        balances[fundsWallet] = balances[fundsWallet] - amount;\r\n        balances[msg.sender] = balances[msg.sender] + amount;\r\n\r\n        Transfer(fundsWallet, msg.sender, amount); \r\n        fundsWallet.transfer(msg.value);                             \r\n    }\r\n\r\n    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {\r\n        allowed[msg.sender][_spender] = _value;\r\n        Approval(msg.sender, _spender, _value);\r\n\r\n        if(!_spender.call(bytes4(bytes32(sha3(\"receiveApproval(address,uint256,address,bytes)\"))), msg.sender, _value, this, _extraData)) { throw; }\r\n        return true;\r\n    }\r\n}"},"timelock.sol":{"content":"pragma solidity ^0.4.25;\r\n\r\nimport \"./GTRX.sol\";\r\n\r\ncontract TokenTimelock {\r\n\r\n  GTRX public token;\r\n  address public beneficiary;\r\n  uint256 public releaseTime;\r\n\r\n  constructor(\r\n    GTRX _token,\r\n    address _beneficiary,\r\n    uint256 _releaseTime\r\n  )\r\n    public\r\n  {\r\n    require(_releaseTime \u003e block.timestamp);\r\n    token = _token;\r\n    beneficiary = _beneficiary;\r\n    releaseTime = _releaseTime;\r\n  }\r\n\r\n  function release() public {\r\n    require(block.timestamp \u003e= releaseTime);\r\n\r\n    uint256 amount = token.balanceOf(address(this));\r\n    require(amount \u003e 0);\r\n\r\n    token.transfer(beneficiary, amount);\r\n  }\r\n}"}}