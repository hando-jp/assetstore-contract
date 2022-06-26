// SPDX-License-Identifier: MIT

/*
 * On-chain asset store, which allows multiple smart contracts to shara vector assets.
 *
 * All assets registered to this store will be treated as cc0 (public domain), 
 * CC-BY(attribution), Apache 2.0 or MIT (should be specified in the "group"). 
 * In case of CC-BY, the creater's name should be in the "group", "category" or "name".
 *
 * All registered assets will be available to other smart contracts for free, including
 * commecial services. Therefore, it is not allowed to register assets that require
 * any form of commercial licenses. 
 *
 * Once an asset is registed with group/category/name, it is NOT possible to update,
 * which guaranttees the availability in future.  
 * 
 * Created by Satoshi Nakajima (@snakajima)
 */

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IAssetStoreRegistry, IAssetStore } from './interfaces/IAssetStore.sol';
import { IStringValidator } from './interfaces/IStringValidator.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import './StringValidator.sol';
import './libs/StringSet.sol';

// import "hardhat/console.sol";

/*
 * Abstract contract that implements the categolized asset storage system. 
 */
abstract contract AssetStoreCore is Ownable, IAssetStoreRegistry {
  using StringSet for StringSet.Set;
  using Strings for uint16;
  using Strings for uint256;
  struct Asset {
    uint32 groupId;    // index to groups + 1
    uint32 categoryId; // index to categories + 1
    uint16 width;
    uint16 height;
    string name;
    string minter;
    address soulbound;
    uint256[] partsIds;
  }

  // Upgradable string validator
  IStringValidator validator;

  // asset & part database
  mapping(uint256 => Asset) private assets;
  uint256 private nextAssetIndex = 1; // 0 indicates an error
  mapping(uint256 => Part) private parts;
  uint256 private nextPartIndex = 1; // 0 indicates an error

  // Groups and categories(for browsing)
  StringSet.Set internal groupSet;
  mapping(string => StringSet.Set) internal categorySets;
  
  // Grouped and categorized assetIds (for browsing)
  mapping(string => mapping(string => mapping(uint32 => uint256))) internal assetIdsInCategory;
  mapping(string => mapping(string => uint32)) internal nextAssetIndecesInCategory;

  // Group/Category/Name => assetId
  mapping(string => mapping(string => mapping(string => uint256))) internal assetIdsLookup;

  constructor() {
    validator = new StringValidator(); // default validator
  }

  // Returns the groupId of the specified group, creating a new Id if necessary.
  // @notice gruopId == groupIndex + 1
  function _getGroupId(string memory group) private returns(uint32) {
    // return groupSet.getId(group, validator);
    uint32 groupId = groupSet.ids[group];
    if (groupId == 0) {
      require(validator.validate(group), "Invalid AssetData Group");
      groupSet.names[groupSet.nextIndex++] = group;
      groupId = groupSet.nextIndex; // idex + 1
      groupSet.ids[group] = groupId; 
    }
    return groupId;
  }

  // Returns the categoryId of the specified category in a group, creating a new Id if necessary.
  // The categoryId is unique only within that group. 
  // @notice categoryId == categoryIndex + 1
  function _getCategoryId(string memory group, string memory category) private returns(uint32) {
    // return categorySets[group].getId(category, validator);
    StringSet.Set storage categorySet = categorySets[group];
    uint32 categoryId = categorySet.ids[category];
    if (categoryId == 0) {
      require(validator.validate(category), "Invalid AssetData Categoy");
      categorySet.names[categorySet.nextIndex++] = category;
      categoryId = categorySet.nextIndex; // index + 1
      categorySet.ids[category] = categoryId;
    }
    return categoryId;
  }

  // Register a Part and returns its id, which is its index in parts[].
  function _registerPart(Part memory _part) private returns(uint256) {
    parts[nextPartIndex++] = _part;
    return nextPartIndex-1;    
  }

  // Validator
  modifier validateAsset(AssetInfo memory _assetInfo) {
    uint size = _assetInfo.parts.length;
    uint i;
    for (i=0; i < size; i++) {
      Part memory part = _assetInfo.parts[i];
      //require(validator.validate(string(part.body)), "Invalid AssetData Body");
      require(validator.validate(part.color), "Invalid AssetData Color");
      //require(validator.validate(string(part.mask)), "Invalid AssetData Mask");
    }
    require(validator.validate(_assetInfo.name), "Invalid AssetData Name");
    // @notice we validate group in _getGroup, category in _getCategory
    _;
  }

  // Register an Asset and returns its id, which is its index in assests[].
  function _registerAsset(AssetInfo memory _assetInfo) internal validateAsset(_assetInfo) returns(uint256) {
    require(assetIdsLookup[_assetInfo.group][_assetInfo.category][_assetInfo.name] == 0, "Asset already exists with the same group, category and name");
    uint size = _assetInfo.parts.length;
    uint256[] memory partsIds = new uint256[](size);
    uint i;
    for (i=0; i<size; i++) {
      partsIds[i] = _registerPart(_assetInfo.parts[i]);
    }
    uint256 assetId = nextAssetIndex++;
    Asset memory asset;
    asset.name = _assetInfo.name;
    asset.soulbound = _assetInfo.soulbound;
    asset.minter = _assetInfo.minter;
    asset.width = _assetInfo.width;
    asset.height = _assetInfo.height;
    asset.groupId = _getGroupId(_assetInfo.group);
    asset.categoryId = _getCategoryId(_assetInfo.group, _assetInfo.category);
    asset.partsIds = partsIds;
    assets[assetId] = asset;
    assetIdsInCategory[_assetInfo.group][_assetInfo.category][nextAssetIndecesInCategory[_assetInfo.group][_assetInfo.category]++] = assetId;
    assetIdsLookup[_assetInfo.group][_assetInfo.category][_assetInfo.name] = assetId;

    emit Registered(msg.sender, assetId);
    return assetId;
  }

  // Returns the number of registered assets
  function getAssetCount() external view onlyOwner returns(uint256) {
    return nextAssetIndex - 1;
  }

  modifier assetExists(uint256 _assetId) {
    require(_assetId > 0 && _assetId < nextAssetIndex, "AssetStore: assetId is out of range"); 
    _;
  }

  modifier partExists(uint256 _partId) {
    require(_partId > 0 && _partId < nextPartIndex, "partId is out of range");
    _;
  }

  // It allows us to keep the assets private. 
  function _getAsset(uint256 _assetId) internal view assetExists(_assetId) returns(Asset memory) {
    return assets[_assetId];
  }

  // It allows us to keep the parts private. 
  function _getPart(uint256 _partId) internal view partExists(_partId) returns(Part memory) {
    return parts[_partId];
  }
}

/*
 * Abstract contract that implements various adminstrative functions, such as
 * managing the whitelist, disable/enable assets and accessing the raw data.
 */
abstract contract AssetStoreAdmin is AssetStoreCore {
  constructor() {
    whitelist[msg.sender] = true;
  }

  // Whitelist
  mapping(address => bool) whitelist;
  bool disableWhitelist = false;

  // Disabled (just in case...)
  mapping(uint256 => bool) disabled;

  function setWhitelistStatus(address _address, bool _status) external onlyOwner {
    whitelist[_address] = _status;
  }

  function setDisabled(uint256 _assetId, bool _status) external assetExists(_assetId) onlyOwner {
    disabled[_assetId] = _status;
  }

  function setDisableWhitelist(bool _disable) external onlyOwner {
    disableWhitelist = _disable;
  } 

  // returns the raw asset data speicified by the assetId (1, ..., count)
  function getRawAsset(uint256 _assetId) external view onlyOwner returns(Asset memory) {
    return _getAsset(_assetId);
  }

  // returns the raw part data specified by the assetId (1, ... count)
  function getRawPart(uint256 _partId) external view onlyOwner returns(Part memory) {
    return _getPart(_partId);
  }
}

/*
 * Concreate contract that implements IAssetStoreRegistory
 * We will never deploy this contract. 
 */
contract AppStoreRegistory is AssetStoreAdmin {
  modifier onlyWhitelist {
    require(disableWhitelist || whitelist[msg.sender], "AssetStore: Tjhe sender must be in the white list.");
    _;
  }
   
  function registerAsset(AssetInfo memory _assetInfo) external override onlyWhitelist returns(uint256) {
    return _registerAsset(_assetInfo);
  }

  function registerAssets(AssetInfo[] memory _assetInfos) external override onlyWhitelist returns(uint256) {
    uint i;
    uint assetIndex;
    for (i=0; i<_assetInfos.length; i++) {
      assetIndex = _registerAsset(_assetInfos[i]);
    }
    return assetIndex;
  }
}

/*
 * Concreate contract that implements both IAssetStore and IAssetStoreRegistory
 * This is the contract we deploy to the blockchain.
 */
contract AssetStore is AppStoreRegistory, IAssetStore {
  using Strings for uint16;
  using Strings for uint256;

  modifier enabled(uint256 _assetId) {
    require(disabled[_assetId] != true, "AssetStore: this asset is diabled");
    _;    
  }

  // Returns the number of registered groups.
  function getGroupCount() external view override returns(uint32) {
    return groupSet.nextIndex;
  }

  // Returns the name of a group specified with groupIndex (groupId - 1). 
  function getGroupNameAtIndex(uint32 groupIndex) external view override returns(string memory) {
    require(groupIndex < groupSet.nextIndex, "The group index is out of range");
    return groupSet.names[groupIndex];
  }

  // Returns the number of categories in the specified group.
  function getCategoryCount(string memory group) external view override returns(uint32) {
    return categorySets[group].nextIndex;
  }

  // Returns the name of category specified with group/categoryIndex pair.
  function getCategoryNameAtIndex(string memory group, uint32 categoryIndex) external view override returns(string memory) {
    StringSet.Set storage categorySet = categorySets[group];
    require(categoryIndex <categorySet.nextIndex, "The categoryIndex index is out of range");
    return categorySet.names[categoryIndex];
  }

  // Returns the number of asset in the specified group/category. 
  function getAssetCountInCategory(string memory group, string memory category) external view override returns(uint32) {
    return nextAssetIndecesInCategory[group][category];
  }

  // Returns the assetId of the specified group/category/assetIndex. 
  function getAssetIdInCategory(string memory group, string memory category, uint32 assetIndex) external view override returns(uint256) {
    require(assetIndex < nextAssetIndecesInCategory[group][category], "The assetIndex is out of range");
    return assetIdsInCategory[group][category][assetIndex];
  }

  // Returns the assetId of the specified group/category/name. 
  function getAssetIdWithName(string memory group, string memory category, string memory name) external override view returns(uint256) {
    return assetIdsLookup[group][category][name];
  }

  function _getDescription(Asset memory asset) internal view returns(bytes memory) {
    string memory group = groupSet.names[asset.groupId - 1];
    return abi.encodePacked(group, '/', categorySets[group].names[asset.categoryId - 1], '/', asset.name);
  }

  function _decodePath(bytes memory body) internal pure returns (bytes memory) {
    require(body.length % 2 == 0, "AssetStore:decodePath invalid body length (odd)");
    bytes memory ret;
    uint16 i;
    uint16 length = (uint16(body.length) * 2)/ 3;
    for (i = 0; i < length; i++) {
      uint16 offset = i / 2 * 3;
      uint16 high;
      uint16 low;
      if (i % 2 == 0) {
        low = uint8(body[offset]);
        high = uint8(body[offset + 1]) % 16;
      } else {
        low = uint8(body[offset + 2]);
        high = uint8(body[offset + 1]) / 16;
      }
      if (high == 0) {
        // Accept only [A-Za-z] and ignore others 
        if (low >=65 && low<=90 || low >= 97 && low <= 122) {
          ret = abi.encodePacked(ret, body[i]);
        }
      } else {
        uint16 value = high * 256 + low - 256;
        if (value >= 1024) {
          ret = abi.encodePacked(ret, (value - 1024).toString(), " ");
        } else {
          ret = abi.encodePacked(ret, "-", (1024 - value).toString(), " ");
        }
      }
    }
    return ret;
  }

  function _safeGenerateSVGPart(uint256 _assetId) internal view returns(bytes memory) {
    Asset memory asset = _getAsset(_assetId);
    uint256[] memory indeces = asset.partsIds;
    bytes memory pack = abi.encodePacked(' <g id="asset', _assetId.toString(), '" desc="', _getDescription(asset), '">\n');
    uint i;
    for (i=0; i<indeces.length; i++) {
      Part memory part = _getPart(indeces[i]);
      if (bytes(part.color).length > 0) {
        pack = abi.encodePacked(pack, '  <path d="', _decodePath(part.body), '" fill="', part.color ,'" />\n');
      } else {
        pack = abi.encodePacked(pack, '  <path d="', _decodePath(part.body), '" />\n');
      }
    }
    pack = abi.encodePacked(pack, ' </g>\n');
    return pack;
  }

  // returns a SVG part with the specified asset
  function generateSVGPart(uint256 _assetId) external override view enabled(_assetId) returns(string memory) {
    return string(_safeGenerateSVGPart(_assetId));
  }

  // returns a full SVG with the specified asset
  function generateSVG(uint256 _assetId) external override view enabled(_assetId) returns(string memory) {
    Asset memory asset = _getAsset(_assetId);
    bytes memory pack = abi.encodePacked(
      '<svg viewBox="0 0 ', (asset.width).toString(), ' ', (asset.height).toString(), '" xmlns="http://www.w3.org/2000/svg">\n', 
      _safeGenerateSVGPart(_assetId), 
      '</svg>');
    return string(pack);
  }

  // returns the attributes of the specified asset
  function getAttributes(uint256 _assetId) external view override returns(AssetAttributes memory) {
    Asset memory asset = _getAsset(_assetId);
    AssetAttributes memory attr;
    attr.name = asset.name;
    attr.soulbound = asset.soulbound;
    attr.minter = asset.minter;
    attr.group = groupSet.names[asset.groupId - 1];
    attr.category = categorySets[attr.group].names[asset.categoryId - 1];
    attr.width = asset.width;
    attr.height = asset.height;
    return attr;
  }

}
