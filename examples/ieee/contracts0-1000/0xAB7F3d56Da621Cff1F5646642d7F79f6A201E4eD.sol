{"Context.sol":{"content":"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.6.0;\n\n/*\n * @dev Provides information about the current execution context, including the\n * sender of the transaction and its data. While these are generally available\n * via msg.sender and msg.data, they should not be accessed in such a direct\n * manner, since when dealing with GSN meta-transactions the account sending and\n * paying for execution may not be the actual sender (as far as an application\n * is concerned).\n *\n * This contract is only required for intermediate, library-like contracts.\n */\nabstract contract Context {\n    function _msgSender() internal view virtual returns (address payable) {\n        return msg.sender;\n    }\n\n    function _msgData() internal view virtual returns (bytes memory) {\n        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691\n        return msg.data;\n    }\n}\n"},"ContractRegistryAccessor.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./IContractRegistry.sol\";\nimport \"./WithClaimableRegistryManagement.sol\";\nimport \"./Initializable.sol\";\n\ncontract ContractRegistryAccessor is WithClaimableRegistryManagement, Initializable {\n\n    IContractRegistry private contractRegistry;\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) public {\n        require(address(_contractRegistry) != address(0), \"_contractRegistry cannot be 0\");\n        setContractRegistry(_contractRegistry);\n        _transferRegistryManagement(_registryAdmin);\n    }\n\n    modifier onlyAdmin {\n        require(isAdmin(), \"sender is not an admin (registryManger or initializationAdmin)\");\n\n        _;\n    }\n\n    function isManager(string memory role) internal view returns (bool) {\n        IContractRegistry _contractRegistry = contractRegistry;\n        return isAdmin() || _contractRegistry != IContractRegistry(0) \u0026\u0026 contractRegistry.getManager(role) == msg.sender;\n    }\n\n    function isAdmin() internal view returns (bool) {\n        return msg.sender == registryAdmin() || msg.sender == initializationAdmin() || msg.sender == address(contractRegistry);\n    }\n\n    function getProtocolContract() internal view returns (address) {\n        return contractRegistry.getContract(\"protocol\");\n    }\n\n    function getStakingRewardsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingRewards\");\n    }\n\n    function getFeesAndBootstrapRewardsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"feesAndBootstrapRewards\");\n    }\n\n    function getCommitteeContract() internal view returns (address) {\n        return contractRegistry.getContract(\"committee\");\n    }\n\n    function getElectionsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"elections\");\n    }\n\n    function getDelegationsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"delegations\");\n    }\n\n    function getGuardiansRegistrationContract() internal view returns (address) {\n        return contractRegistry.getContract(\"guardiansRegistration\");\n    }\n\n    function getCertificationContract() internal view returns (address) {\n        return contractRegistry.getContract(\"certification\");\n    }\n\n    function getStakingContract() internal view returns (address) {\n        return contractRegistry.getContract(\"staking\");\n    }\n\n    function getSubscriptionsContract() internal view returns (address) {\n        return contractRegistry.getContract(\"subscriptions\");\n    }\n\n    function getStakingRewardsWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingRewardsWallet\");\n    }\n\n    function getBootstrapRewardsWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"bootstrapRewardsWallet\");\n    }\n\n    function getGeneralFeesWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"generalFeesWallet\");\n    }\n\n    function getCertifiedFeesWallet() internal view returns (address) {\n        return contractRegistry.getContract(\"certifiedFeesWallet\");\n    }\n\n    function getStakingContractHandler() internal view returns (address) {\n        return contractRegistry.getContract(\"stakingContractHandler\");\n    }\n\n    /*\n    * Governance functions\n    */\n\n    event ContractRegistryAddressUpdated(address addr);\n\n    function setContractRegistry(IContractRegistry newContractRegistry) public onlyAdmin {\n        require(newContractRegistry.getPreviousContractRegistry() == address(contractRegistry), \"new contract registry must provide the previous contract registry\");\n        contractRegistry = newContractRegistry;\n        emit ContractRegistryAddressUpdated(address(newContractRegistry));\n    }\n\n    function getContractRegistry() public view returns (IContractRegistry) {\n        return contractRegistry;\n    }\n\n}\n"},"GuardiansRegistration.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./IGuardiansRegistration.sol\";\nimport \"./IElections.sol\";\nimport \"./ManagedContract.sol\";\n\ncontract GuardiansRegistration is IGuardiansRegistration, ManagedContract {\n\n\tstruct Guardian {\n\t\taddress orbsAddr;\n\t\tbytes4 ip;\n\t\tuint32 registrationTime;\n\t\tuint32 lastUpdateTime;\n\t\tstring name;\n\t\tstring website;\n\t}\n\tmapping(address =\u003e Guardian) guardians;\n\tmapping(address =\u003e address) orbsAddressToGuardianAddress;\n\tmapping(bytes4 =\u003e address) public ipToGuardian;\n\tmapping(address =\u003e mapping(string =\u003e string)) guardianMetadata;\n\n\tconstructor(IContractRegistry _contractRegistry, address _registryAdmin) ManagedContract(_contractRegistry, _registryAdmin) public {}\n\n\tmodifier onlyRegisteredGuardian {\n\t\trequire(isRegistered(msg.sender), \"Guardian is not registered\");\n\n\t\t_;\n\t}\n\n\t/*\n     * External methods\n     */\n\n    /// @dev Called by a participant who wishes to register as a guardian\n\tfunction registerGuardian(bytes4 ip, address orbsAddr, string calldata name, string calldata website) external override onlyWhenActive {\n\t\trequire(!isRegistered(msg.sender), \"registerGuardian: Guardian is already registered\");\n\n\t\tguardians[msg.sender].registrationTime = uint32(block.timestamp);\n\t\temit GuardianRegistered(msg.sender);\n\n\t\t_updateGuardian(msg.sender, ip, orbsAddr, name, website);\n\t}\n\n    /// @dev Called by a participant who wishes to update its properties\n\tfunction updateGuardian(bytes4 ip, address orbsAddr, string calldata name, string calldata website) external override onlyRegisteredGuardian onlyWhenActive {\n\t\t_updateGuardian(msg.sender, ip, orbsAddr, name, website);\n\t}\n\n\tfunction updateGuardianIp(bytes4 ip) external override onlyWhenActive {\n\t\taddress guardianAddr = resolveGuardianAddress(msg.sender);\n\t\tGuardian memory data = guardians[guardianAddr];\n\t\t_updateGuardian(guardianAddr, ip, data.orbsAddr, data.name, data.website);\n\t}\n\n    /// @dev Called by a guardian to update additional guardian metadata properties.\n    function setMetadata(string calldata key, string calldata value) external override onlyRegisteredGuardian onlyWhenActive {\n\t\t_setMetadata(msg.sender, key, value);\n\t}\n\n\tfunction getMetadata(address guardian, string calldata key) external override view returns (string memory) {\n\t\treturn guardianMetadata[guardian][key];\n\t}\n\n\t/// @dev Called by a participant who wishes to unregister\n\tfunction unregisterGuardian() external override onlyRegisteredGuardian onlyWhenActive {\n\t\tdelete orbsAddressToGuardianAddress[guardians[msg.sender].orbsAddr];\n\t\tdelete ipToGuardian[guardians[msg.sender].ip];\n\t\tGuardian memory guardian = guardians[msg.sender];\n\t\tdelete guardians[msg.sender];\n\n\t\telectionsContract.guardianUnregistered(msg.sender);\n\t\temit GuardianDataUpdated(msg.sender, false, guardian.ip, guardian.orbsAddr, guardian.name, guardian.website);\n\t\temit GuardianUnregistered(msg.sender);\n\t}\n\n    /// @dev Returns a guardian\u0027s data\n\tfunction getGuardianData(address guardian) external override view returns (bytes4 ip, address orbsAddr, string memory name, string memory website, uint registrationTime, uint lastUpdateTime) {\n\t\tGuardian memory v = guardians[guardian];\n\t\treturn (v.ip, v.orbsAddr, v.name, v.website, v.registrationTime, v.lastUpdateTime);\n\t}\n\n\tfunction getGuardiansOrbsAddress(address[] calldata guardianAddrs) external override view returns (address[] memory orbsAddrs) {\n\t\torbsAddrs = new address[](guardianAddrs.length);\n\t\tfor (uint i = 0; i \u003c guardianAddrs.length; i++) {\n\t\t\torbsAddrs[i] = guardians[guardianAddrs[i]].orbsAddr;\n\t\t}\n\t}\n\n\tfunction getGuardianIp(address guardian) external override view returns (bytes4 ip) {\n\t\treturn guardians[guardian].ip;\n\t}\n\n\tfunction getGuardianIps(address[] calldata guardianAddrs) external override view returns (bytes4[] memory ips) {\n\t\tips = new bytes4[](guardianAddrs.length);\n\t\tfor (uint i = 0; i \u003c guardianAddrs.length; i++) {\n\t\t\tips[i] = guardians[guardianAddrs[i]].ip;\n\t\t}\n\t}\n\n\tfunction isRegistered(address guardian) public override view returns (bool) {\n\t\treturn guardians[guardian].registrationTime != 0;\n\t}\n\n\tfunction resolveGuardianAddress(address guardianOrOrbsAddress) public override view returns (address guardianAddress) {\n\t\tif (isRegistered(guardianOrOrbsAddress)) {\n\t\t\tguardianAddress = guardianOrOrbsAddress;\n\t\t} else {\n\t\t\tguardianAddress = orbsAddressToGuardianAddress[guardianOrOrbsAddress];\n\t\t}\n\n\t\trequire(guardianAddress != address(0), \"Cannot resolve address\");\n\t}\n\n\t/// @dev Translates a list guardians Orbs addresses to Ethereum addresses\n\tfunction getGuardianAddresses(address[] calldata orbsAddrs) external override view returns (address[] memory guardianAddrs) {\n\t\tguardianAddrs = new address[](orbsAddrs.length);\n\t\tfor (uint i = 0; i \u003c orbsAddrs.length; i++) {\n\t\t\tguardianAddrs[i] = orbsAddressToGuardianAddress[orbsAddrs[i]];\n\t\t}\n\t}\n\n\t/*\n\t * Governance\n\t */\n\n\tfunction migrateGuardians(address[] calldata guardiansToMigrate, IGuardiansRegistration previousContract) external override onlyInitializationAdmin {\n\t\trequire(previousContract != IGuardiansRegistration(0), \"previousContract must not be the zero address\");\n\n\t\tfor (uint i = 0; i \u003c guardiansToMigrate.length; i++) {\n\t\t\trequire(guardiansToMigrate[i] != address(0), \"guardian must not be the zero address\");\n\t\t\tmigrateGuardianData(previousContract, guardiansToMigrate[i]);\n\t\t\tmigrateGuardianMetadata(previousContract, guardiansToMigrate[i]);\n\t\t}\n\t}\n\n\t/*\n\t * Private methods\n\t */\n\n\tfunction _updateGuardian(address guardianAddr, bytes4 ip, address orbsAddr, string memory name, string memory website) private {\n\t\trequire(orbsAddr != address(0), \"orbs address must be non zero\");\n\t\trequire(orbsAddr != guardianAddr, \"orbs address must be different than the guardian address\");\n\t\trequire(!isRegistered(orbsAddr), \"orbs address must not be a guardian address of a registered guardian\");\n\t\trequire(bytes(name).length != 0, \"name must be given\");\n\n\t\tdelete ipToGuardian[guardians[guardianAddr].ip];\n\t\trequire(ipToGuardian[ip] == address(0), \"ip is already in use\");\n\t\tipToGuardian[ip] = guardianAddr;\n\n\t\tdelete orbsAddressToGuardianAddress[guardians[guardianAddr].orbsAddr];\n\t\trequire(orbsAddressToGuardianAddress[orbsAddr] == address(0), \"orbs address is already in use\");\n\t\torbsAddressToGuardianAddress[orbsAddr] = guardianAddr;\n\n\t\tguardians[guardianAddr].orbsAddr = orbsAddr;\n\t\tguardians[guardianAddr].ip = ip;\n\t\tguardians[guardianAddr].name = name;\n\t\tguardians[guardianAddr].website = website;\n\t\tguardians[guardianAddr].lastUpdateTime = uint32(block.timestamp);\n\n        emit GuardianDataUpdated(guardianAddr, true, ip, orbsAddr, name, website);\n    }\n\n\tfunction _setMetadata(address guardian, string memory key, string memory value) private {\n\t\tstring memory oldValue = guardianMetadata[guardian][key];\n\t\tguardianMetadata[guardian][key] = value;\n\t\temit GuardianMetadataChanged(guardian, key, value, oldValue);\n\t}\n\n\tfunction migrateGuardianData(IGuardiansRegistration previousContract, address guardianAddress) private {\n\t\t(bytes4 ip, address orbsAddr, string memory name, string memory website, uint registrationTime, uint lastUpdateTime) = previousContract.getGuardianData(guardianAddress);\n\t\tguardians[guardianAddress] = Guardian({\n\t\t\torbsAddr: orbsAddr,\n\t\t\tip: ip,\n\t\t\tname: name,\n\t\t\twebsite: website,\n\t\t\tregistrationTime: uint32(registrationTime),\n\t\t\tlastUpdateTime: uint32(lastUpdateTime)\n\t\t});\n\t\torbsAddressToGuardianAddress[orbsAddr] = guardianAddress;\n\t\tipToGuardian[ip] = guardianAddress;\n\n\t\temit GuardianDataUpdated(guardianAddress, true, ip, orbsAddr, name, website);\n\t}\n\n\tstring public constant ID_FORM_URL_METADATA_KEY = \"ID_FORM_URL\";\n\tfunction migrateGuardianMetadata(IGuardiansRegistration previousContract, address guardianAddress) private {\n\t\tstring memory rewardsFreqMetadata = previousContract.getMetadata(guardianAddress, ID_FORM_URL_METADATA_KEY);\n\t\tif (bytes(rewardsFreqMetadata).length \u003e 0) {\n\t\t\t_setMetadata(guardianAddress, ID_FORM_URL_METADATA_KEY, rewardsFreqMetadata);\n\t\t}\n\t}\n\n\t/*\n     * Contracts topology / registry interface\n     */\n\n\tIElections electionsContract;\n\tfunction refreshContracts() external override {\n\t\telectionsContract = IElections(getElectionsContract());\n\t}\n\n}\n"},"IContractRegistry.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ninterface IContractRegistry {\n\n\tevent ContractAddressUpdated(string contractName, address addr, bool managedContract);\n\tevent ManagerChanged(string role, address newManager);\n\tevent ContractRegistryUpdated(address newContractRegistry);\n\n\t/*\n\t* External functions\n\t*/\n\n\t/// @dev updates the contracts address and emits a corresponding event\n\t/// managedContract indicates whether the contract is managed by the registry and notified on changes\n\tfunction setContract(string calldata contractName, address addr, bool managedContract) external /* onlyAdmin */;\n\n\t/// @dev returns the current address of the given contracts\n\tfunction getContract(string calldata contractName) external view returns (address);\n\n\t/// @dev returns the list of contract addresses managed by the registry\n\tfunction getManagedContracts() external view returns (address[] memory);\n\n\tfunction setManager(string calldata role, address manager) external /* onlyAdmin */;\n\n\tfunction getManager(string calldata role) external view returns (address);\n\n\tfunction lockContracts() external /* onlyAdmin */;\n\n\tfunction unlockContracts() external /* onlyAdmin */;\n\n\tfunction setNewContractRegistry(IContractRegistry newRegistry) external /* onlyAdmin */;\n\n\tfunction getPreviousContractRegistry() external view returns (address);\n\n}\n"},"IElections.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\n/// @title Elections contract interface\ninterface IElections {\n\t\n\t// Election state change events\n\tevent StakeChanged(address indexed addr, uint256 selfStake, uint256 delegatedStake, uint256 effectiveStake);\n\tevent GuardianStatusUpdated(address indexed guardian, bool readyToSync, bool readyForCommittee);\n\n\t// Vote out / Vote unready\n\tevent GuardianVotedUnready(address indexed guardian);\n\tevent VoteUnreadyCasted(address indexed voter, address indexed subject, uint256 expiration);\n\tevent GuardianVotedOut(address indexed guardian);\n\tevent VoteOutCasted(address indexed voter, address indexed subject);\n\n\t/*\n\t * External functions\n\t */\n\n\t/// @dev Called by a guardian when ready to start syncing with other nodes\n\tfunction readyToSync() external;\n\n\t/// @dev Called by a guardian when ready to join the committee, typically after syncing is complete or after being voted out\n\tfunction readyForCommittee() external;\n\n\t/// @dev Called to test if a guardian calling readyForCommittee() will lead to joining the committee\n\tfunction canJoinCommittee(address guardian) external view returns (bool);\n\n\t/// @dev Returns an address effective stake\n\tfunction getEffectiveStake(address guardian) external view returns (uint effectiveStake);\n\n\t/// @dev returns the current committee\n\t/// used also by the rewards and fees contracts\n\tfunction getCommittee() external view returns (address[] memory committee, uint256[] memory weights, address[] memory orbsAddrs, bool[] memory certification, bytes4[] memory ips);\n\n\t// Vote-unready\n\n\t/// @dev Called by a guardian as part of the automatic vote-unready flow\n\tfunction voteUnready(address subject, uint expiration) external;\n\n\tfunction getVoteUnreadyVote(address voter, address subject) external view returns (bool valid, uint256 expiration);\n\n\t/// @dev Returns the current vote-unready status of a subject guardian.\n\t/// votes indicates wether the specific committee member voted the guardian unready\n\tfunction getVoteUnreadyStatus(address subject) external view returns (\n\t\taddress[] memory committee,\n\t\tuint256[] memory weights,\n\t\tbool[] memory certification,\n\t\tbool[] memory votes,\n\t\tbool subjectInCommittee,\n\t\tbool subjectInCertifiedCommittee\n\t);\n\n\t// Vote-out\n\n\t/// @dev Casts a voteOut vote by the sender to the given address\n\tfunction voteOut(address subject) external;\n\n\t/// @dev Returns the subject address the addr has voted-out against\n\tfunction getVoteOutVote(address voter) external view returns (address);\n\n\t/// @dev Returns the governance voteOut status of a guardian.\n\t/// A guardian is voted out if votedStake / totalDelegatedStake (in percent mille) \u003e threshold\n\tfunction getVoteOutStatus(address subject) external view returns (bool votedOut, uint votedStake, uint totalDelegatedStake);\n\n\t/*\n\t * Notification functions from other PoS contracts\n\t */\n\n\t/// @dev Called by: delegation contract\n\t/// Notifies a delegated stake change event\n\t/// total_delegated_stake = 0 if addr delegates to another guardian\n\tfunction delegatedStakeChange(address delegate, uint256 selfStake, uint256 delegatedStake, uint256 totalDelegatedStake) external /* onlyDelegationsContract onlyWhenActive */;\n\n\t/// @dev Called by: guardian registration contract\n\t/// Notifies a new guardian was unregistered\n\tfunction guardianUnregistered(address guardian) external /* onlyGuardiansRegistrationContract */;\n\n\t/// @dev Called by: guardian registration contract\n\t/// Notifies on a guardian certification change\n\tfunction guardianCertificationChanged(address guardian, bool isCertified) external /* onlyCertificationContract */;\n\n\n\t/*\n     * Governance functions\n\t */\n\n\tevent VoteUnreadyTimeoutSecondsChanged(uint32 newValue, uint32 oldValue);\n\tevent VoteOutPercentMilleThresholdChanged(uint32 newValue, uint32 oldValue);\n\tevent VoteUnreadyPercentMilleThresholdChanged(uint32 newValue, uint32 oldValue);\n\tevent MinSelfStakePercentMilleChanged(uint32 newValue, uint32 oldValue);\n\n\t/// @dev Sets the minimum self-stake required for the effective stake\n\t/// minSelfStakePercentMille - the minimum self stake in percent-mille (0-100,000)\n\tfunction setMinSelfStakePercentMille(uint32 minSelfStakePercentMille) external /* onlyFunctionalManager onlyWhenActive */;\n\n\t/// @dev Returns the minimum self-stake required for the effective stake\n\tfunction getMinSelfStakePercentMille() external view returns (uint32);\n\n\t/// @dev Sets the vote-out threshold\n\t/// voteOutPercentMilleThreshold - the minimum threshold in percent-mille (0-100,000)\n\tfunction setVoteOutPercentMilleThreshold(uint32 voteUnreadyPercentMilleThreshold) external /* onlyFunctionalManager onlyWhenActive */;\n\n\t/// @dev Returns the vote-out threshold\n\tfunction getVoteOutPercentMilleThreshold() external view returns (uint32);\n\n\t/// @dev Sets the vote-unready threshold\n\t/// voteUnreadyPercentMilleThreshold - the minimum threshold in percent-mille (0-100,000)\n\tfunction setVoteUnreadyPercentMilleThreshold(uint32 voteUnreadyPercentMilleThreshold) external /* onlyFunctionalManager onlyWhenActive */;\n\n\t/// @dev Returns the vote-unready threshold\n\tfunction getVoteUnreadyPercentMilleThreshold() external view returns (uint32);\n\n\t/// @dev Returns the contract\u0027s settings \n\tfunction getSettings() external view returns (\n\t\tuint32 minSelfStakePercentMille,\n\t\tuint32 voteUnreadyPercentMilleThreshold,\n\t\tuint32 voteOutPercentMilleThreshold\n\t);\n\n\tfunction initReadyForCommittee(address[] calldata guardians) external /* onlyInitializationAdmin */;\n\n}\n\n"},"IGuardiansRegistration.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\n/// @title Guardian registration contract interface\ninterface IGuardiansRegistration {\n\tevent GuardianRegistered(address indexed guardian);\n\tevent GuardianUnregistered(address indexed guardian);\n\tevent GuardianDataUpdated(address indexed guardian, bool isRegistered, bytes4 ip, address orbsAddr, string name, string website);\n\tevent GuardianMetadataChanged(address indexed guardian, string key, string newValue, string oldValue);\n\n\t/*\n     * External methods\n     */\n\n    /// @dev Called by a participant who wishes to register as a guardian\n\tfunction registerGuardian(bytes4 ip, address orbsAddr, string calldata name, string calldata website) external;\n\n    /// @dev Called by a participant who wishes to update its propertires\n\tfunction updateGuardian(bytes4 ip, address orbsAddr, string calldata name, string calldata website) external;\n\n\t/// @dev Called by a participant who wishes to update its IP address (can be call by both main and Orbs addresses)\n\tfunction updateGuardianIp(bytes4 ip) external /* onlyWhenActive */;\n\n    /// @dev Called by a participant to update additional guardian metadata properties.\n    function setMetadata(string calldata key, string calldata value) external;\n\n    /// @dev Called by a participant to get additional guardian metadata properties.\n    function getMetadata(address guardian, string calldata key) external view returns (string memory);\n\n    /// @dev Called by a participant who wishes to unregister\n\tfunction unregisterGuardian() external;\n\n    /// @dev Returns a guardian\u0027s data\n\tfunction getGuardianData(address guardian) external view returns (bytes4 ip, address orbsAddr, string memory name, string memory website, uint registrationTime, uint lastUpdateTime);\n\n\t/// @dev Returns the Orbs addresses of a list of guardians\n\tfunction getGuardiansOrbsAddress(address[] calldata guardianAddrs) external view returns (address[] memory orbsAddrs);\n\n\t/// @dev Returns a guardian\u0027s ip\n\tfunction getGuardianIp(address guardian) external view returns (bytes4 ip);\n\n\t/// @dev Returns guardian ips\n\tfunction getGuardianIps(address[] calldata guardian) external view returns (bytes4[] memory ips);\n\n\t/// @dev Returns true if the given address is of a registered guardian\n\tfunction isRegistered(address guardian) external view returns (bool);\n\n\t/// @dev Translates a list guardians Orbs addresses to guardian addresses\n\tfunction getGuardianAddresses(address[] calldata orbsAddrs) external view returns (address[] memory guardianAddrs);\n\n\t/// @dev Resolves the guardian address for a guardian, given a Guardian/Orbs address\n\tfunction resolveGuardianAddress(address guardianOrOrbsAddress) external view returns (address guardianAddress);\n\n\t/*\n\t * Governance functions\n\t */\n\n\tfunction migrateGuardians(address[] calldata guardiansToMigrate, IGuardiansRegistration previousContract) external /* onlyInitializationAdmin */;\n\n}\n"},"ILockable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ninterface ILockable {\n\n    event Locked();\n    event Unlocked();\n\n    function lock() external /* onlyLockOwner */;\n    function unlock() external /* onlyLockOwner */;\n    function isLocked() view external returns (bool);\n\n}\n"},"Initializable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\ncontract Initializable {\n\n    address private _initializationAdmin;\n\n    event InitializationComplete();\n\n    constructor() public{\n        _initializationAdmin = msg.sender;\n    }\n\n    modifier onlyInitializationAdmin() {\n        require(msg.sender == initializationAdmin(), \"sender is not the initialization admin\");\n\n        _;\n    }\n\n    /*\n    * External functions\n    */\n\n    function initializationAdmin() public view returns (address) {\n        return _initializationAdmin;\n    }\n\n    function initializationComplete() external onlyInitializationAdmin {\n        _initializationAdmin = address(0);\n        emit InitializationComplete();\n    }\n\n    function isInitializationComplete() public view returns (bool) {\n        return _initializationAdmin == address(0);\n    }\n\n}"},"Lockable.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./ContractRegistryAccessor.sol\";\nimport \"./ILockable.sol\";\n\ncontract Lockable is ILockable, ContractRegistryAccessor {\n\n    bool public locked;\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) ContractRegistryAccessor(_contractRegistry, _registryAdmin) public {}\n\n    modifier onlyLockOwner() {\n        require(msg.sender == registryAdmin() || msg.sender == address(getContractRegistry()), \"caller is not a lock owner\");\n\n        _;\n    }\n\n    function lock() external override onlyLockOwner {\n        locked = true;\n        emit Locked();\n    }\n\n    function unlock() external override onlyLockOwner {\n        locked = false;\n        emit Unlocked();\n    }\n\n    function isLocked() external override view returns (bool) {\n        return locked;\n    }\n\n    modifier onlyWhenActive() {\n        require(!locked, \"contract is locked for this operation\");\n\n        _;\n    }\n}\n"},"ManagedContract.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./Lockable.sol\";\n\ncontract ManagedContract is Lockable {\n\n    constructor(IContractRegistry _contractRegistry, address _registryAdmin) Lockable(_contractRegistry, _registryAdmin) public {}\n\n    modifier onlyMigrationManager {\n        require(isManager(\"migrationManager\"), \"sender is not the migration manager\");\n\n        _;\n    }\n\n    modifier onlyFunctionalManager {\n        require(isManager(\"functionalManager\"), \"sender is not the functional manager\");\n\n        _;\n    }\n\n    function refreshContracts() virtual external {}\n\n}"},"WithClaimableRegistryManagement.sol":{"content":"// SPDX-License-Identifier: UNLICENSED\n\npragma solidity 0.6.12;\n\nimport \"./Context.sol\";\n\n/**\n * @title Claimable\n * @dev Extension for the Ownable contract, where the ownership needs to be claimed.\n * This allows the new owner to accept the transfer.\n */\ncontract WithClaimableRegistryManagement is Context {\n    address private _registryAdmin;\n    address private _pendingRegistryAdmin;\n\n    event RegistryManagementTransferred(address indexed previousRegistryAdmin, address indexed newRegistryAdmin);\n\n    /**\n     * @dev Initializes the contract setting the deployer as the initial registryRegistryAdmin.\n     */\n    constructor () internal {\n        address msgSender = _msgSender();\n        _registryAdmin = msgSender;\n        emit RegistryManagementTransferred(address(0), msgSender);\n    }\n\n    /**\n     * @dev Returns the address of the current registryAdmin.\n     */\n    function registryAdmin() public view returns (address) {\n        return _registryAdmin;\n    }\n\n    /**\n     * @dev Throws if called by any account other than the registryAdmin.\n     */\n    modifier onlyRegistryAdmin() {\n        require(isRegistryAdmin(), \"WithClaimableRegistryManagement: caller is not the registryAdmin\");\n        _;\n    }\n\n    /**\n     * @dev Returns true if the caller is the current registryAdmin.\n     */\n    function isRegistryAdmin() public view returns (bool) {\n        return _msgSender() == _registryAdmin;\n    }\n\n    /**\n     * @dev Leaves the contract without registryAdmin. It will not be possible to call\n     * `onlyManager` functions anymore. Can only be called by the current registryAdmin.\n     *\n     * NOTE: Renouncing registryManagement will leave the contract without an registryAdmin,\n     * thereby removing any functionality that is only available to the registryAdmin.\n     */\n    function renounceRegistryManagement() public onlyRegistryAdmin {\n        emit RegistryManagementTransferred(_registryAdmin, address(0));\n        _registryAdmin = address(0);\n    }\n\n    /**\n     * @dev Transfers registryManagement of the contract to a new account (`newManager`).\n     */\n    function _transferRegistryManagement(address newRegistryAdmin) internal {\n        require(newRegistryAdmin != address(0), \"RegistryAdmin: new registryAdmin is the zero address\");\n        emit RegistryManagementTransferred(_registryAdmin, newRegistryAdmin);\n        _registryAdmin = newRegistryAdmin;\n    }\n\n    /**\n     * @dev Modifier throws if called by any account other than the pendingManager.\n     */\n    modifier onlyPendingRegistryAdmin() {\n        require(msg.sender == _pendingRegistryAdmin, \"Caller is not the pending registryAdmin\");\n        _;\n    }\n    /**\n     * @dev Allows the current registryAdmin to set the pendingManager address.\n     * @param newRegistryAdmin The address to transfer registryManagement to.\n     */\n    function transferRegistryManagement(address newRegistryAdmin) public onlyRegistryAdmin {\n        _pendingRegistryAdmin = newRegistryAdmin;\n    }\n\n    /**\n     * @dev Allows the _pendingRegistryAdmin address to finalize the transfer.\n     */\n    function claimRegistryManagement() external onlyPendingRegistryAdmin {\n        _transferRegistryManagement(_pendingRegistryAdmin);\n        _pendingRegistryAdmin = address(0);\n    }\n\n    /**\n     * @dev Returns the current pendingRegistryAdmin\n    */\n    function pendingRegistryAdmin() public view returns (address) {\n       return _pendingRegistryAdmin;  \n    }\n}\n"}}