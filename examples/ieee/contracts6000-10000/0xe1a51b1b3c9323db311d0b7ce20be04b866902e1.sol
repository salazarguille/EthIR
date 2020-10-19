{"Organization.sol":{"content":"pragma solidity ^0.5.0;\n\nimport \"./OrganizationInterface.sol\";\nimport \"./PermissionsEnum.sol\";\n\n\n/**\n * @title Organization\n * Organization contract to create new organization, add/delete Devices,\n * create new Lot\n */\ncontract Organization is OrganizationInterface, PermissionsEnum {\n\n    address public lotFactory;\n\n    mapping(address =\u003e bool) public adminDevices;\n\n    mapping(address =\u003e bool) public permittedDevices;\n\n    bool public isActive;\n\n    event DeviceAdded (\n        address device\n    );\n\n    event DeviceRemoved (\n        address device\n    );\n\n    event AdminDeviceAdded (\n        address device\n    );\n\n    event AdminDeviceRemoved (\n        address device\n    );\n\n    event LotFactoryChanged (\n        address oldFactory,\n        address newFactory\n    );\n\n    modifier onlyOwnerAccess() {\n        require(isAdminDevice(msg.sender), \"Only admin device accesible\");\n        _;\n    }\n\n    modifier onlyPermittedAccess() {\n        require(isPermittedDevice(msg.sender), \"Only permitted device accesible\");\n        _;\n    }\n\n    constructor(\n        address _lotFactory,\n        address _organizationOwner,\n        bool _isActive\n    )\n    public {\n        lotFactory = _lotFactory;\n\n        // Set all the roles to false initially\n        isActive = _isActive;\n\n        // make admin the owner device\n        _permitAdminDevice(_organizationOwner);\n    }\n    \n    /**\n     * @dev Returns the organization info\n     */\n    function organizationInfo()\n    public\n    view\n    returns (bool status) {\n        status = isActive;\n    }\n\n    /**\n     * @dev Check if device is able to add or remove permitted devices.\n     * @param _device The address to device check access.\n     */\n    function isAdminDevice(address _device)\n    public\n    view\n    returns (bool deviceAdmin)\n    {\n        return adminDevices[_device];\n    }\n\n    /**\n     * @dev Check if device is Permitted to perform Lot related operations.\n     * @param _device The address to device check access.\n     */\n    function isPermittedDevice(address _device)\n    public\n    view\n    returns (bool devicePermitted)\n    {\n        return (permittedDevices[_device] || adminDevices[_device]);\n    }\n\n    /**\n    * @dev Update lot factory address\n    */\n    function setLotFactory(address _lotFactory)\n    public\n    onlyOwnerAccess\n    {\n        address oldFactory = lotFactory;\n        lotFactory = _lotFactory;\n\n        // Emit we updated lot factory\n        emit LotFactoryChanged(oldFactory, _lotFactory);\n    }\n\n    /**\n     * @dev Allows the new _device to access organization.\n     * @param _deviceAddress The address of new device which needs access to organization.\n     */\n    function permitDevice(address _deviceAddress)\n    public\n    onlyOwnerAccess\n    returns (bool devicePermitted)\n    {\n        return _permitDevice(_deviceAddress);\n    }\n\n    function removeDevice(address _deviceAddress)\n    public\n    onlyOwnerAccess\n    returns (bool devicePermitted)\n    {\n        return _removeDevice(_deviceAddress);\n    }\n\n    function _permitDevice(address _deviceAddress)\n    private\n    returns (bool devicePermitted)\n    {\n        //validation to check already exist in the list\n        permittedDevices[_deviceAddress] = true;\n\n        emit DeviceAdded(_deviceAddress);\n        return true;\n    }\n\n    function _removeDevice(address _deviceAddress)\n    private\n\n    returns (bool devicePermitted)\n    {\n        permittedDevices[_deviceAddress] = false;\n\n        emit DeviceRemoved(_deviceAddress);\n        return true;\n    }\n\n    function permitAdminDevice(address _deviceAddress)\n    public\n    onlyOwnerAccess\n    returns (bool deviceAdmin)\n    {\n        return _permitAdminDevice(_deviceAddress);\n    }\n\n    function removeAdminDevice(address _deviceAddress)\n    public\n    onlyOwnerAccess\n    returns (bool deviceAdmin)\n    {\n        return _removeAdminDevice(_deviceAddress);\n    }\n\n    function _permitAdminDevice(address _deviceAddress)\n    private\n    returns (bool deviceAdmin)\n    {\n        //validation to check already exist in the list\n        adminDevices[_deviceAddress] = true;\n        permittedDevices[_deviceAddress] = true;\n\n        emit AdminDeviceAdded(_deviceAddress);\n        return true;\n    }\n\n    function _removeAdminDevice(address _deviceAddress)\n    private\n    returns (bool deviceAdmin)\n    {\n        adminDevices[_deviceAddress] = false;\n        permittedDevices[_deviceAddress] = false;\n\n        emit AdminDeviceRemoved(_deviceAddress);\n        return true;\n    }\n    \n\n    function hasPermissions(address permittee, uint256 permission)\n    public\n    view\n    returns (bool)\n    {\n        if (permittee == address(this)) return true;\n\n        if (permission == uint256(Permissions.CREATE_LOT)) return isPermittedDevice(permittee);\n        if (permission == uint256(Permissions.CREATE_SUB_LOT)) return isPermittedDevice(permittee);\n        if (permission == uint256(Permissions.UPDATE_LOT)) return isPermittedDevice(permittee);\n        if (permission == uint256(Permissions.TRANSFER_LOT_OWNERSHIP)) return isPermittedDevice(permittee);\n        if (permission == uint256(Permissions.ALLOCATE_SUPPLY)) return permittee == address(lotFactory);\n\n        return false;\n    }\n}\n"},"OrganizationFactory.sol":{"content":"\npragma solidity ^0.5.0;\n\nimport \"./OrganizationFactoryInterface.sol\";\nimport \"./Organization.sol\";\n\ncontract OrganizationFactory is OrganizationFactoryInterface {\n\n    function createOrganization(address _lotFactory, address _organizationOwner, bool _isActive) public returns (address) {\n        Organization organization = new Organization( _lotFactory, _organizationOwner, _isActive);\n        return address(organization);\n    }\n} \n"},"OrganizationFactoryInterface.sol":{"content":"pragma solidity ^0.5.0;\n\ninterface OrganizationFactoryInterface {\n    function createOrganization(address lotFactory, address owner, bool isActive) external returns (address);\n}"},"OrganizationInterface.sol":{"content":"pragma solidity ^0.5.0;\n\ncontract OrganizationInterface {\n    function hasPermissions(address permittee, uint256 permission) public view returns (bool);\n}\n"},"PermissionsEnum.sol":{"content":"pragma solidity ^0.5.0;\n\ncontract PermissionsEnum {\n    enum Permissions {\n        CREATE_LOT,\n        CREATE_SUB_LOT,\n        UPDATE_LOT,\n        TRANSFER_LOT_OWNERSHIP,\n        ALLOCATE_SUPPLY\n    }\n}\n"}}