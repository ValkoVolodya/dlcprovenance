pragma solidity ^0.4.26;

contract DLCProvenance {
    address public owner;
    
    Resource public resource;
    
    // Aggrement Policy between owner of resource and users of resource
    bytes32 public aggrementPolicyIPFS;
    
    // maybe add resource type?
    
    
    struct Resource {
        address resourceOwner; // Ethereum address of resource owner
        address smartContractAddress;
        string info;
        string metadata; // Information about method of obtaining a resource
        uint256 creationTimestamp;
        
        // In future we might define array struct for storing multiple hashes if needed
        bytes32 IPFSHash;
    }
    
    bool hasParent;
    address[] parentResources;
    
    enum scientistState {SentRequest,  GrantedPermission, DeniedPermission, sentReviewRequest, AcceptedReview, DeniedReview }
    
    struct Scientist {
        scientistState state;
        address addr;
        bytes32 hash;
        bool result;
    }
    
    mapping (bytes32 => Resource) public grantedPermissionChildResources; // for history tracking, mapping all children resources with their smart contract address
    mapping (bytes32 => Scientist) public grantedPermissions; // EA of scientists with granted permissions, maps between the EA and the IPFS hash of the resource
    mapping (bytes32 => Scientist) public deniedPermissions; // list of scientists with denied permissions, maps between the EA and the IPFS hash of the resource
    mapping (bytes32 => Scientist) public requests; // all requets , EA and IPFS hash
        
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier notOwner() {
        require(msg.sender != owner);
        _;
    }
    
    event scientistRequestingPermission(address scientist);
    event scientistRequestRegistered(address scientist, bytes32 IPFS_Hash); // <- is we need this hash?
    event permissionGranted(address scientist);
    event permissionDenied(address scientist);
    event reviewRequest(address scientist);
    event reviewApprove(address scientist);
    event reviewDenied(address scientist);
        
    constructor(
        bytes32 IPFSHash,
        string info,
        string metadata,
        address[] _parentResources
    ) public {
        owner = msg.sender;
        resource.resourceOwner = msg.sender;
        resource.smartContractAddress = this;
        resource.IPFSHash = IPFSHash;
        resource.info = info;
        resource.metadata = metadata;
        resource.creationTimestamp = block.timestamp;
        
        if (_parentResources.length != 0) {
            hasParent = true;
            parentResources = _parentResources;
        }
    }
    
    function requestPermission(bytes32 IPFSHash) public notOwner {
        require(requests[IPFSHash].hash != IPFSHash);
        requests[IPFSHash].state = scientistState.SentRequest;
        requests[IPFSHash].addr = msg.sender;
        requests[IPFSHash].hash = IPFSHash;
        requests[IPFSHash].result = false;
        emit scientistRequestRegistered(msg.sender, IPFSHash);
    }
    
    function grantPermission(bool result, address scientist, bytes32 IPFSHash) public onlyOwner {
        require(requests[IPFSHash].state == scientistState.SentRequest);
        if(result){
            grantedPermissions[IPFSHash].addr = scientist;
            grantedPermissions[IPFSHash].state = scientistState.GrantedPermission;
            grantedPermissions[IPFSHash].result = result;
            grantedPermissions[IPFSHash].hash = IPFSHash;
            requests[IPFSHash].state = scientistState.GrantedPermission;
            requests[IPFSHash].result = true;
            emit permissionGranted(scientist);
            
        }
        else {
            deniedPermissions[IPFSHash].addr = scientist;
            deniedPermissions[IPFSHash].state = scientistState.DeniedPermission;
            deniedPermissions[IPFSHash].result = result;
            deniedPermissions[IPFSHash].hash = IPFSHash;
            requests[IPFSHash].state = scientistState.DeniedPermission;
            emit permissionDenied(scientist);
        }
        
    }
    
    function requestReview(bytes32 hash, address SCaddress) public notOwner {
        require(requests[hash].state == scientistState.GrantedPermission); //requires state to be granted
        emit reviewRequest(SCaddress);
        grantedPermissions[hash].state = scientistState.sentReviewRequest;
    }
    
    function approveReview(bool result, string infor, bytes32 hash, string meta, address SCaddress) public onlyOwner {
        require(grantedPermissions[hash].state == scientistState.sentReviewRequest);
        if(result){
         grantedPermissionChildResources[hash].resourceOwner = msg.sender;//save all info as new entry
         grantedPermissionChildResources[hash].info = infor;
         grantedPermissionChildResources[hash].IPFSHash = hash;
         grantedPermissionChildResources[hash].smartContractAddress = SCaddress;
         grantedPermissionChildResources[hash].creationTimestamp = block.timestamp;
         grantedPermissionChildResources[hash].metadata = meta;
         grantedPermissions[hash].state = scientistState.AcceptedReview;
         requests[hash].state = scientistState.AcceptedReview;
         emit reviewApprove(SCaddress);
        }
        else
        {
         grantedPermissions[hash].state = scientistState.DeniedReview;//Granted permission for the request, but denied attestation
         requests[hash].state = scientistState.DeniedReview;
         emit reviewDenied(SCaddress);   
        }
    }
}
