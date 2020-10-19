{"Context.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.0;\n\n/*\n * @dev Provides information about the current execution context, including the\n * sender of the transaction and its data. While these are generally available\n * via msg.sender and msg.data, they should not be accessed in such a direct\n * manner, since when dealing with GSN meta-transactions the account sending and\n * paying for execution may not be the actual sender (as far as an application\n * is concerned).\n *\n * This contract is only required for intermediate, library-like contracts.\n */\nabstract contract Context {\n    function _msgSender() internal view virtual returns (address payable) {\n        return msg.sender;\n    }\n\n    function _msgData() internal view virtual returns (bytes memory) {\n        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691\n        return msg.data;\n    }\n}\n"},"ContractRegistryAccessor.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./IContractRegistry.sol\";\nimport \"./WithClaimableRegistryManagement.sol\";\nimport \"./Initializable.sol\";\n\ncontract ContractRegistryAccessor is WithClaimableRegistryManagement, Initializable {\n\n    IContractRegistry private contractRegistry;\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) public {\n        require(address(_contractRegistry) != address(0), \"_contractRegistry cannot be 0\");\n        setContractRegistry(_contractRegistry);\n        _transferRegistryManagement(_registryAdmin);\n    }\n\n    modifier onlyAdmin {\n        require(isAdmin(), \"sender is not an admin (registryManger or initializationAdmin)\");\n\n        _;\n    }\n\n    function isManager(string memory role) internal view returns (bool) {\n        IContractRegistry _contractRegistry = contractRegistry;\n        return isAdmin() || _contractRegistry != IContractRegistry(0) \u0026\u0026 contractRegistry.getManager(role) == msg.sender;\n    }\n\n    function isAdmin() internal view returns (bool) {\n        return msg.sender == registryAdmin() || msg.sender == initializationAdmin() || msg.sender == address(contractRegistry);\n    }\n\n    function getProtocolContract() internal view returns (address) {\n        return contractRegistry.getContract(\"protocol\");\n    }\n\n    function getStakingRewardsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingRewards\");\n    }\n\n    function getFeesAndBootstrapRewardsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"feesAndBootstrapRewards\");\n    }\n\n    function getCommitteeContract() internal view returns (address) {\n        return contractRegistry.getContract(\"committee\");\n    }\n\n    function getElectionsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"elections\");\n    }\n\n    function getDelegationsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"delegations\");\n    }\n\n    function getGuardiansRegistrationContract() internal view returns (address) {\n        return contractRegistry.getContract(\"guardiansRegistration\");\n    }\n\n    function getCertificationContract() internal view returns (address) {\n        return contractRegistry.getContract(\"certification\");\n    }\n\n    function getStakingContract() internal view returns (address) {\n        return contractRegistry.getContract(\"staking\");\n    }\n\n    function getSubscriptionsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"subscriptions\");\n    }\n\n    function getStakingRewardsWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingRewardsWallet\");\n    }\n\n    function getBootstrapRewardsWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"bootstrapRewardsWallet\");\n    }\n\n    function getGeneralFeesWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"generalFeesWallet\");\n    }\n\n    function getCertifiedFeesWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"certifiedFeesWallet\");\n    }\n\n    function getStakingContractHandler() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingContractHandler\");\n    }\n\n    /*\n    * Governance functions\n    */\n\n    event ContractRegistryAddressUpdated(address addr);\n\n    function setContractRegistry(IContractRegistry newContractRegistry) public onlyAdmin {\n        require(newContractRegistry.getPreviousContractRegistry() == address(contractRegistry), \"new contract registry must provide the previous contract registry\");\n        contractRegistry = newContractRegistry;\n        emit ContractRegistryAddressUpdated(address(newContractRegistry));\n    }\n\n    function getContractRegistry() public view returns (IContractRegistry) {\n        return contractRegistry;\n    }\n\n}\n"},"FeesWallet.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./IERC20.sol\";\nimport \"./Math.sol\";\nimport \"./SafeMath.sol\";\n\nimport \"./IMigratableFeesWallet.sol\";\nimport \"./IFeesWallet.sol\";\nimport \"./ManagedContract.sol\";\n\n/// @title Fees Wallet contract interface, manages the fee buckets\ncontract FeesWallet is IFeesWallet, ManagedContract {\n    using SafeMath for uint256;\n\n    uint256 constant BUCKET_TIME_PERIOD = 30 days;\n    uint constant MAX_FEE_BUCKET_ITERATIONS = 24;\n\n    IERC20 public token;\n    mapping(uint256 =\u003e uint256) public buckets;\n    uint256 public lastCollectedAt;\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin, IERC20 _token) ManagedContract(_contractRegistry, _registryAdmin) public {\n        token = _token;\n        lastCollectedAt = now;\n    }\n\n    modifier onlyRewardsContract() {\n        require(msg.sender == rewardsContract, \"caller is not the rewards contract\");\n\n        _;\n    }\n\n    /*\n     *   External methods\n     */\n\n    /// @dev collect fees from the buckets since the last call and transfers the amount back.\n    /// Called by: only Rewards contract.\n    function collectFees() external override onlyRewardsContract returns (uint256 collectedFees)  {\n        (uint256 _collectedFees, uint[] memory bucketsWithdrawn, uint[] memory amountsWithdrawn, uint[] memory newTotals) = _getOutstandingFees();\n\n        for (uint i = 0; i \u003c bucketsWithdrawn.length; i++) {\n            buckets[bucketsWithdrawn[i]] = newTotals[i];\n            emit FeesWithdrawnFromBucket(bucketsWithdrawn[i], amountsWithdrawn[i], newTotals[i]);\n        }\n\n        lastCollectedAt = block.timestamp;\n\n        require(token.transfer(msg.sender, _collectedFees), \"FeesWallet::failed to transfer collected fees to rewards\"); // TODO in that case, transfer the remaining balance?\n        return _collectedFees;\n    }\n\n    function getOutstandingFees() external override view returns (uint256 outstandingFees)  {\n        (outstandingFees,,,) = _getOutstandingFees();\n    }\n\n    /// @dev Called by: subscriptions contract.\n    /// Top-ups the fee pool with the given amount at the given rate (typically called by the subscriptions contract).\n    function fillFeeBuckets(uint256 amount, uint256 monthlyRate, uint256 fromTimestamp) external override onlyWhenActive {\n        uint256 bucket = _bucketTime(fromTimestamp);\n        require(bucket \u003e= _bucketTime(block.timestamp), \"FeeWallet::cannot fill bucket from the past\");\n\n        uint256 _amount = amount;\n\n        // add the partial amount to the first bucket\n        uint256 bucketAmount = Math.min(amount, monthlyRate.mul(BUCKET_TIME_PERIOD - fromTimestamp % BUCKET_TIME_PERIOD).div(BUCKET_TIME_PERIOD));\n        fillFeeBucket(bucket, bucketAmount);\n        _amount = _amount.sub(bucketAmount);\n\n        // following buckets are added with the monthly rate\n        while (_amount \u003e 0) {\n            bucket = bucket.add(BUCKET_TIME_PERIOD);\n            bucketAmount = Math.min(monthlyRate, _amount);\n            fillFeeBucket(bucket, bucketAmount);\n\n            _amount = _amount.sub(bucketAmount);\n        }\n\n        require(token.transferFrom(msg.sender, address(this), amount), \"failed to transfer fees into fee wallet\");\n    }\n\n    /*\n     * Governance functions\n     */\n\n    /// @dev migrates the fees of bucket starting at startTimestamp.\n    /// bucketStartTime must be a bucket\u0027s start time.\n    /// Calls acceptBucketMigration in the destination contract.\n    function migrateBucket(IMigratableFeesWallet destination, uint256 bucketStartTime) external override onlyMigrationManager {\n        require(_bucketTime(bucketStartTime) == bucketStartTime,  \"bucketStartTime must be the  start time of a bucket\");\n\n        uint bucketAmount = buckets[bucketStartTime];\n        if (bucketAmount == 0) return;\n\n        buckets[bucketStartTime] = 0;\n        emit FeesWithdrawnFromBucket(bucketStartTime, bucketAmount, 0);\n\n        token.approve(address(destination), bucketAmount);\n        destination.acceptBucketMigration(bucketStartTime, bucketAmount);\n    }\n\n    /// @dev Called by the old FeesWallet contract.\n    /// Part of the IMigratableFeesWallet interface.\n    function acceptBucketMigration(uint256 bucketStartTime, uint256 amount) external override {\n        require(_bucketTime(bucketStartTime) == bucketStartTime,  \"bucketStartTime must be the  start time of a bucket\");\n        fillFeeBucket(bucketStartTime, amount);\n        require(token.transferFrom(msg.sender, address(this), amount), \"failed to transfer fees into fee wallet on bucket migration\");\n    }\n\n    /// @dev an emergency withdrawal enables withdrawal of all funds to an escrow account. To be use in emergencies only.\n    function emergencyWithdraw() external override onlyMigrationManager {\n        emit EmergencyWithdrawal(msg.sender);\n        require(token.transfer(msg.sender, token.balanceOf(address(this))), \"IFeesWallet::emergencyWithdraw - transfer failed (fee token)\");\n    }\n\n    /*\n    * Private methods\n    */\n\n    function fillFeeBucket(uint256 bucketId, uint256 amount) private {\n        uint256 bucketTotal = buckets[bucketId].add(amount);\n        buckets[bucketId] = bucketTotal;\n        emit FeesAddedToBucket(bucketId, amount, bucketTotal);\n    }\n\n    function _getOutstandingFees() private view returns (uint256 outstandingFees, uint[] memory bucketsWithdrawn, uint[] memory withdrawnAmounts, uint[] memory newTotals)  {\n        // TODO we often do integer division for rate related calculation, which floors the result. Do we need to address this?\n        // TODO for an empty committee or a committee with 0 total stake the divided amounts will be locked in the contract FOREVER\n\n        // Fee pool\n        uint _lastCollectedAt = lastCollectedAt;\n        uint nUpdatedBuckets = _bucketTime(block.timestamp).sub(_bucketTime(_lastCollectedAt)).div(BUCKET_TIME_PERIOD).add(1);\n        bucketsWithdrawn = new uint[](nUpdatedBuckets);\n        withdrawnAmounts = new uint[](nUpdatedBuckets);\n        newTotals = new uint[](nUpdatedBuckets);\n        uint bucketsPayed = 0;\n        while (bucketsPayed \u003c MAX_FEE_BUCKET_ITERATIONS \u0026\u0026 _lastCollectedAt \u003c block.timestamp) {\n            uint256 bucketStart = _bucketTime(_lastCollectedAt);\n            uint256 bucketEnd = bucketStart.add(BUCKET_TIME_PERIOD);\n            uint256 payUntil = Math.min(bucketEnd, block.timestamp);\n            uint256 bucketDuration = payUntil.sub(_lastCollectedAt);\n            uint256 remainingBucketTime = bucketEnd.sub(_lastCollectedAt);\n\n            uint256 bucketTotal = buckets[bucketStart];\n            uint256 amount = bucketTotal * bucketDuration / remainingBucketTime;\n            outstandingFees += amount;\n            bucketTotal = bucketTotal.sub(amount);\n\n            bucketsWithdrawn[bucketsPayed] = bucketStart;\n            withdrawnAmounts[bucketsPayed] = amount;\n            newTotals[bucketsPayed] = bucketTotal;\n\n            _lastCollectedAt = payUntil;\n            bucketsPayed++;\n        }\n    }\n\n    function _bucketTime(uint256 time) private pure returns (uint256) {\n        return time - time % BUCKET_TIME_PERIOD;\n    }\n\n    /*\n     * Contracts topology / registry interface\n     */\n\n    address rewardsContract;\n    function refreshContracts() external override {\n        rewardsContract = getFeesAndBootstrapRewardsContract();\n    }\n}\n"},"IContractRegistry.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ninterface IContractRegistry {\n\n\tevent ContractAddressUpdated(string contractName, address addr, bool managedContract);\n\tevent ManagerChanged(string role, address newManager);\n\tevent ContractRegistryUpdated(address newContractRegistry);\n\n\t/*\n\t* External functions\n\t*/\n\n\t/// @dev updates the contracts address and emits a corresponding event\n\t/// managedContract indicates whether the contract is managed by the registry and notified on changes\n\tfunction setContract(string calldata contractName, address addr, bool managedContract) external /* onlyAdmin */;\n\n\t/// @dev returns the current address of the given contracts\n\tfunction getContract(string calldata contractName) external view returns (address);\n\n\t/// @dev returns the list of contract addresses managed by the registry\n\tfunction getManagedContracts() external view returns (address[] memory);\n\n\tfunction setManager(string calldata role, address manager) external /* onlyAdmin */;\n\n\tfunction getManager(string calldata role) external view returns (address);\n\n\tfunction lockContracts() external /* onlyAdmin */;\n\n\tfunction unlockContracts() external /* onlyAdmin */;\n\n\tfunction setNewContractRegistry(IContractRegistry newRegistry) external /* onlyAdmin */;\n\n\tfunction getPreviousContractRegistry() external view returns (address);\n\n}\n"},"IERC20.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.0;\n\n/**\n * @dev Interface of the ERC20 standard as defined in the EIP.\n */\ninterface IERC20 {\n    /**\n     * @dev Returns the amount of tokens in existence.\n     */\n    function totalSupply() external view returns (uint256);\n\n    /**\n     * @dev Returns the amount of tokens owned by `account`.\n     */\n    function balanceOf(address account) external view returns (uint256);\n\n    /**\n     * @dev Moves `amount` tokens from the caller\u0027s account to `recipient`.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a {Transfer} event.\n     */\n    function transfer(address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Returns the remaining number of tokens that `spender` will be\n     * allowed to spend on behalf of `owner` through {transferFrom}. This is\n     * zero by default.\n     *\n     * This value changes when {approve} or {transferFrom} are called.\n     */\n    function allowance(address owner, address spender) external view returns (uint256);\n\n    /**\n     * @dev Sets `amount` as the allowance of `spender` over the caller\u0027s tokens.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * IMPORTANT: Beware that changing an allowance with this method brings the risk\n     * that someone may use both the old and the new allowance by unfortunate\n     * transaction ordering. One possible solution to mitigate this race\n     * condition is to first reduce the spender\u0027s allowance to 0 and set the\n     * desired value afterwards:\n     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729\n     *\n     * Emits an {Approval} event.\n     */\n    function approve(address spender, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Moves `amount` tokens from `sender` to `recipient` using the\n     * allowance mechanism. `amount` is then deducted from the caller\u0027s\n     * allowance.\n     *\n     * Returns a boolean value indicating whether the operation succeeded.\n     *\n     * Emits a {Transfer} event.\n     */\n    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);\n\n    /**\n     * @dev Emitted when `value` tokens are moved from one account (`from`) to\n     * another (`to`).\n     *\n     * Note that `value` may be zero.\n     */\n    event Transfer(address indexed from, address indexed to, uint256 value);\n\n    /**\n     * @dev Emitted when the allowance of a `spender` for an `owner` is set by\n     * a call to {approve}. `value` is the new allowance.\n     */\n    event Approval(address indexed owner, address indexed spender, uint256 value);\n}\n"},"IFeesWallet.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./IMigratableFeesWallet.sol\";\n\n/// @title Fees Wallet contract interface, manages the fee buckets\ninterface IFeesWallet {\n\n    event FeesWithdrawnFromBucket(uint256 bucketId, uint256 withdrawn, uint256 total);\n    event FeesAddedToBucket(uint256 bucketId, uint256 added, uint256 total);\n\n    /*\n     *   External methods\n     */\n\n    /// @dev Called by: subscriptions contract.\n    /// Top-ups the fee pool with the given amount at the given rate (typically called by the subscriptions contract).\n    function fillFeeBuckets(uint256 amount, uint256 monthlyRate, uint256 fromTimestamp) external;\n\n    /// @dev collect fees from the buckets since the last call and transfers the amount back.\n    /// Called by: only Rewards contract.\n    function collectFees() external returns (uint256 collectedFees) /* onlyRewardsContract */;\n\n    /// @dev Returns the amount of fees that are currently available for withdrawal\n    function getOutstandingFees() external view returns (uint256 outstandingFees);\n\n    /*\n     * General governance\n     */\n\n    event EmergencyWithdrawal(address addr);\n\n    /// @dev migrates the fees of bucket starting at startTimestamp.\n    /// bucketStartTime must be a bucket\u0027s start time.\n    /// Calls acceptBucketMigration in the destination contract.\n    function migrateBucket(IMigratableFeesWallet destination, uint256 bucketStartTime) external /* onlyMigrationManager */;\n\n    /// @dev Called by the old FeesWallet contract.\n    /// Part of the IMigratableFeesWallet interface.\n    function acceptBucketMigration(uint256 bucketStartTime, uint256 amount) external;\n\n    /// @dev an emergency withdrawal enables withdrawal of all funds to an escrow account. To be use in emergencies only.\n    function emergencyWithdraw() external /* onlyMigrationManager */;\n\n}\n"},"ILockable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ninterface ILockable {\n\n    event Locked();\n    event Unlocked();\n\n    function lock() external /* onlyLockOwner */;\n    function unlock() external /* onlyLockOwner */;\n    function isLocked() view external returns (bool);\n\n}\n"},"IMigratableFeesWallet.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\n/// @title An interface for Fee wallets that support bucket migration.\ninterface IMigratableFeesWallet {\n    /// @dev receives a bucket start time and an amount\n    function acceptBucketMigration(uint256 bucketStartTime, uint256 amount) external;\n}\n"},"Initializable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ncontract Initializable {\n\n    address private _initializationAdmin;\n\n    event InitializationComplete();\n\n    constructor() public{\n        _initializationAdmin = msg.sender;\n    }\n\n    modifier onlyInitializationAdmin() {\n        require(msg.sender == initializationAdmin(), \"sender is not the initialization admin\");\n\n        _;\n    }\n\n    /*\n    * External functions\n    */\n\n    function initializationAdmin() public view returns (address) {\n        return _initializationAdmin;\n    }\n\n    function initializationComplete() external onlyInitializationAdmin {\n        _initializationAdmin = address(0);\n        emit InitializationComplete();\n    }\n\n    function isInitializationComplete() public view returns (bool) {\n        return _initializationAdmin == address(0);\n    }\n\n}"},"Lockable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./ContractRegistryAccessor.sol\";\nimport \"./ILockable.sol\";\n\ncontract Lockable is ILockable, ContractRegistryAccessor {\n\n    bool public locked;\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) ContractRegistryAccessor(_contractRegistry, _registryAdmin) public {}\n\n    modifier onlyLockOwner() {\n        require(msg.sender == registryAdmin() || msg.sender == address(getContractRegistry()), \"caller is not a lock owner\");\n\n        _;\n    }\n\n    function lock() external override onlyLockOwner {\n        locked = true;\n        emit Locked();\n    }\n\n    function unlock() external override onlyLockOwner {\n        locked = false;\n        emit Unlocked();\n    }\n\n    function isLocked() external override view returns (bool) {\n        return locked;\n    }\n\n    modifier onlyWhenActive() {\n        require(!locked, \"contract is locked for this operation\");\n\n        _;\n    }\n}\n"},"ManagedContract.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./Lockable.sol\";\n\ncontract ManagedContract is Lockable {\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) Lockable(_contractRegistry, _registryAdmin) public {}\n\n    modifier onlyMigrationManager {\n        require(isManager(\"migrationManager\"), \"sender is not the migration manager\");\n\n        _;\n    }\n\n    modifier onlyFunctionalManager {\n        require(isManager(\"functionalManager\"), \"sender is not the functional manager\");\n\n        _;\n    }\n\n    function refreshContracts() virtual external {}\n\n}"},"Math.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.0;\n\n/**\n * @dev Standard math utilities missing in the Solidity language.\n */\nlibrary Math {\n    /**\n     * @dev Returns the largest of two numbers.\n     */\n    function max(uint256 a, uint256 b) internal pure returns (uint256) {\n        return a \u003e= b ? a : b;\n    }\n\n    /**\n     * @dev Returns the smallest of two numbers.\n     */\n    function min(uint256 a, uint256 b) internal pure returns (uint256) {\n        return a \u003c b ? a : b;\n    }\n\n    /**\n     * @dev Returns the average of two numbers. The result is rounded towards\n     * zero.\n     */\n    function average(uint256 a, uint256 b) internal pure returns (uint256) {\n        // (a + b) / 2 can overflow, so we distribute\n        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);\n    }\n}\n"},"SafeMath.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.0;\n\n/**\n * @dev Wrappers over Solidity\u0027s arithmetic operations with added overflow\n * checks.\n *\n * Arithmetic operations in Solidity wrap on overflow. This can easily result\n * in bugs, because programmers usually assume that an overflow raises an\n * error, which is the standard behavior in high level programming languages.\n * `SafeMath` restores this intuition by reverting the transaction when an\n * operation overflows.\n *\n * Using this library instead of the unchecked operations eliminates an entire\n * class of bugs, so it\u0027s recommended to use it always.\n */\nlibrary SafeMath {\n    /**\n     * @dev Returns the addition of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `+` operator.\n     *\n     * Requirements:\n     *\n     * - Addition cannot overflow.\n     */\n    function add(uint256 a, uint256 b) internal pure returns (uint256) {\n        uint256 c = a + b;\n        require(c \u003e= a, \"SafeMath: addition overflow\");\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the subtraction of two unsigned integers, reverting on\n     * overflow (when the result is negative).\n     *\n     * Counterpart to Solidity\u0027s `-` operator.\n     *\n     * Requirements:\n     *\n     * - Subtraction cannot overflow.\n     */\n    function sub(uint256 a, uint256 b) internal pure returns (uint256) {\n        return sub(a, b, \"SafeMath: subtraction overflow\");\n    }\n\n    /**\n     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on\n     * overflow (when the result is negative).\n     *\n     * Counterpart to Solidity\u0027s `-` operator.\n     *\n     * Requirements:\n     *\n     * - Subtraction cannot overflow.\n     */\n    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b \u003c= a, errorMessage);\n        uint256 c = a - b;\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the multiplication of two unsigned integers, reverting on\n     * overflow.\n     *\n     * Counterpart to Solidity\u0027s `*` operator.\n     *\n     * Requirements:\n     *\n     * - Multiplication cannot overflow.\n     */\n    function mul(uint256 a, uint256 b) internal pure returns (uint256) {\n        // Gas optimization: this is cheaper than requiring \u0027a\u0027 not being zero, but the\n        // benefit is lost if \u0027b\u0027 is also tested.\n        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522\n        if (a == 0) {\n            return 0;\n        }\n\n        uint256 c = a * b;\n        require(c / a == b, \"SafeMath: multiplication overflow\");\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the integer division of two unsigned integers. Reverts on\n     * division by zero. The result is rounded towards zero.\n     *\n     * Counterpart to Solidity\u0027s `/` operator. Note: this function uses a\n     * `revert` opcode (which leaves remaining gas untouched) while Solidity\n     * uses an invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function div(uint256 a, uint256 b) internal pure returns (uint256) {\n        return div(a, b, \"SafeMath: division by zero\");\n    }\n\n    /**\n     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on\n     * division by zero. The result is rounded towards zero.\n     *\n     * Counterpart to Solidity\u0027s `/` operator. Note: this function uses a\n     * `revert` opcode (which leaves remaining gas untouched) while Solidity\n     * uses an invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b \u003e 0, errorMessage);\n        uint256 c = a / b;\n        // assert(a == b * c + a % b); // There is no case in which this doesn\u0027t hold\n\n        return c;\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),\n     * Reverts when dividing by zero.\n     *\n     * Counterpart to Solidity\u0027s `%` operator. This function uses a `revert`\n     * opcode (which leaves remaining gas untouched) while Solidity uses an\n     * invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function mod(uint256 a, uint256 b) internal pure returns (uint256) {\n        return mod(a, b, \"SafeMath: modulo by zero\");\n    }\n\n    /**\n     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),\n     * Reverts with custom message when dividing by zero.\n     *\n     * Counterpart to Solidity\u0027s `%` operator. This function uses a `revert`\n     * opcode (which leaves remaining gas untouched) while Solidity uses an\n     * invalid opcode to revert (consuming all remaining gas).\n     *\n     * Requirements:\n     *\n     * - The divisor cannot be zero.\n     */\n    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {\n        require(b != 0, errorMessage);\n        return a % b;\n    }\n}\n"},"WithClaimableRegistryManagement.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./Context.sol\";\n\n/**\n * @title Claimable\n * @dev Extension for the Ownable contract, where the ownership needs to be claimed.\n * This allows the new owner to accept the transfer.\n */\ncontract WithClaimableRegistryManagement is Context {\n    address private _registryAdmin;\n    address private _pendingRegistryAdmin;\n\n    event RegistryManagementTransferred(address indexed previousRegistryAdmin, address indexed newRegistryAdmin);\n\n    /**\n     * @dev Initializes the contract setting the deployer as the initial registryRegistryAdmin.\n     */\n    constructor () internal {\n        address msgSender = _msgSender();\n        _registryAdmin = msgSender;\n        emit RegistryManagementTransferred(address(0), msgSender);\n    }\n\n    /**\n     * @dev Returns the address of the current registryAdmin.\n     */\n    function registryAdmin() public view returns (address) {\n        return _registryAdmin;\n    }\n\n    /**\n     * @dev Throws if called by any account other than the registryAdmin.\n     */\n    modifier onlyRegistryAdmin() {\n        require(isRegistryAdmin(), \"WithClaimableRegistryManagement: caller is not the registryAdmin\");\n        _;\n    }\n\n    /**\n     * @dev Returns true if the caller is the current registryAdmin.\n     */\n    function isRegistryAdmin() public view returns (bool) {\n        return _msgSender() == _registryAdmin;\n    }\n\n    /**\n     * @dev Leaves the contract without registryAdmin. It will not be possible to call\n     * `onlyManager` functions anymore. Can only be called by the current registryAdmin.\n     *\n     * NOTE: Renouncing registryManagement will leave the contract without an registryAdmin,\n     * thereby removing any functionality that is only available to the registryAdmin.\n     */\n    function renounceRegistryManagement() public onlyRegistryAdmin {\n        emit RegistryManagementTransferred(_registryAdmin, address(0));\n        _registryAdmin = address(0);\n    }\n\n    /**\n     * @dev Transfers registryManagement of the contract to a new account (`newManager`).\n     */\n    function _transferRegistryManagement(address newRegistryAdmin) internal {\n        require(newRegistryAdmin != address(0), \"RegistryAdmin: new registryAdmin is the zero address\");\n        emit RegistryManagementTransferred(_registryAdmin, newRegistryAdmin);\n        _registryAdmin = newRegistryAdmin;\n    }\n\n    /**\n     * @dev Modifier throws if called by any account other than the pendingManager.\n     */\n    modifier onlyPendingRegistryAdmin() {\n        require(msg.sender == _pendingRegistryAdmin, \"Caller is not the pending registryAdmin\");\n        _;\n    }\n    /**\n     * @dev Allows the current registryAdmin to set the pendingManager address.\n     * @param newRegistryAdmin The address to transfer registryManagement to.\n     */\n    function transferRegistryManagement(address newRegistryAdmin) public onlyRegistryAdmin {\n        _pendingRegistryAdmin = newRegistryAdmin;\n    }\n\n    /**\n     * @dev Allows the _pendingRegistryAdmin address to finalize the transfer.\n     */\n    function claimRegistryManagement() external onlyPendingRegistryAdmin {\n        _transferRegistryManagement(_pendingRegistryAdmin);\n        _pendingRegistryAdmin = address(0);\n    }\n\n    /**\n     * @dev Returns the current pendingRegistryAdmin\n    */\n    function pendingRegistryAdmin() public view returns (address) {\n       return _pendingRegistryAdmin;  \n    }\n}\n"}}