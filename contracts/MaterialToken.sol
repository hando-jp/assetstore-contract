// SPDX-License-Identifier: MIT

/*
 * Material Icon NFT (ERC721). The mint function takes IAssetStore.AssetInfo as a parameter.
 * It registers the specified asset to the AssetStore and mint a token which represents
 * the "minter" of the asset (who paid the gas fee), along with two additional bonus tokens.
 * 
 * It uses ERC721A as the base contract, which is quite efficent to mint multiple tokens
 * with a single transaction. 
 *
 * Once minted, the asset will beome available to other smart contract developers,
 * for free, either CC0, CC-BY-SA(Attribution-ShareAlike), Appache, MIT or similar.
 * 
 * Created by Satoshi Nakajima (@snakajima)
 */

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//��erc721a�̎��Ԃ͂ǂ��ɂ���H�H
//�Z��package.json�Ŏw�肷�邱�ƂŎg���Ă���
import "erc721a/contracts/ERC721A.sol";
import { IAssetStoreRegistry, IAssetStore } from './interfaces/IAssetStore.sol';
import { IAssetStoreToken } from './interfaces/IAssetStoreToken.sol';
//�Zbase64��package.json�Ŏw�肷�邱�ƂŎg���Ă���
import { Base64 } from 'base64-sol/base64.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';

contract MaterialToken is Ownable, ERC721A, IAssetStoreToken {

  //�ZStrings��Library���g����Bvalue.toString()�Ȃǂ̌^�ϊ�
  using Strings for uint256;
  using Strings for uint16;

  //�Zimmutable�͒萔�Ƃ͈Ⴂ�A�����f�v���C���i=construct�N�����ɐݒ肳��ĕύX�ł��Ȃ����́A�K�X��̐ߖ�H�H�j
  IAssetStoreRegistry public immutable registry;
  IAssetStore public immutable assetStore;

  //�Z�P�̃A�Z�b�g�ɑ΂��Ă�����token�𔭍s���邩�B�}�e���A���A�C�R���̏ꍇ��4��
  //��tokenId��MaterialToken�������̂��̂Ȃ̂��낤���H�H
  //�Z�����̒ʂ肾�����Btoken group���ō̔Ԃ���Ă���
  //�ZAssetId��Asset�S�̂ł̍̔�
  uint256 constant tokensPerAsset = 4;
  mapping(uint256 => uint256) assetIds; // tokenId / tokensPerAsset => assetId

  // description
  string public description = "This is one of effts to create (On-Chain Asset Store)[https://assetstore.wtf].";

  // developer address.
  address public developer;

  // OpenSea's Proxy Registry
  IProxyRegistry public immutable proxyRegistry;

  /*
   * @notice both _registry and _assetStore points to the AssetStore.
   */
   //�ZECR721A�̃R���X�g���N�^�[�ɒl��n���Ă���B
   //��MaterialToken�͂ǂ��ŃR���X�g���N�^�[���Ăяo����Ă��邩�B�B�v�m�F
  constructor(
    IAssetStoreRegistry _registry, 
    IAssetStore _assetStore,
    address _developer,
    IProxyRegistry _proxyRegistry
  ) ERC721A("Material Icons", "MATERIAL") {
    registry = _registry;
    assetStore = _assetStore;
    developer = _developer;
    proxyRegistry = _proxyRegistry;
  }

  //���v���C�}���[�g�[�N�����ǂ����B�Ȃ��v���C�}���[���K�v�H�HERC721A�̎d�l�ł͂Ȃ������B
  function _isPrimary(uint256 _tokenId) internal pure returns(bool) {
    return _tokenId % tokensPerAsset == 0;
  }

  /*
   * It registers the specified asset to the AssetStore and
   * mint three tokens to the msg.sender, and one additional
   * token to either the affiliator, the developer or the owner.npnkda
   */
   //�ZIAssetStoreRegistry is a interface for contracts to register Assets
   //�ZParts of assetInfo are viewed at opensea
   //�Zaffiliate = primary token of affiliater
  function mintWithAsset(IAssetStoreRegistry.AssetInfo memory _assetInfo, uint256 _affiliate) external {

    //�Zgroup is registered by hard cording
    _assetInfo.group = "Material Icons (Apache 2.0)";
    //�ZAssets are registered here.Assets are numbered.
    uint256 assetId = registry.registerAsset(_assetInfo);
    //�Z_nextTokenId is defined in ERC721A.
    uint256 tokenId = _nextTokenId(); 

    //�ZAssetId is identified not in only Material but in all assets
    assetIds[tokenId / tokensPerAsset] = assetId;
    //�Z_mint is implemented in ERC721A for bulk mint.
    //�Z3 of 4 for minter
    _mint(msg.sender, tokensPerAsset - 1);

    // Specified affliate token must be one of soul-bound token and not owned by the minter.
    //�Z�������ownerOf��ECR721�g�[�N���Ƃ��Ă�Owner
    if (_affiliate > 0 && _isPrimary(_affiliate) && ownerOf(_affiliate) != msg.sender) {
      _mint(ownerOf(_affiliate), 1);
    } else if ((tokenId / tokensPerAsset) % 4 == 0) {
      // 1 in 24 tokens goes to the developer
      //�Z����͊ԈႢ�ł́H�H16�Ɉ�H�HtokenId��4��������A4���mint��1��H
      _mint(developer, 1);
    } else {
      // the rest goes to the owner for distribution
      //��owner()�͂ǂ��ɒ�`����Ă���H�H
      //�Z��Ownable���������B�~�g�[�N���̃I�[�i�[��Ԃ��B�R���g���N�g��owner��Ԃ��B
      //��developer��owner�ŕ����Ă���̂͂Ȃ����H�H
      _mint(owner(), 1);
    }
  }
  /*
   * @notice get next tokenId.
   */
  function getCurrentToken() external view returns (uint256) {                  
    return _nextTokenId();
  }

  /**
    * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
    */
  //�ZisApprovedForAll��ERC721�̋K�i
  //��open sea�Ɏ����s�̌����ڏ�����Ă��邩�̊m�F�H
  function isApprovedForAll(address owner, address operator) public view override returns (bool) {
      // Whitelist OpenSea proxy contract for easy trading.
      if (proxyRegistry.proxies(owner) == operator) {
          return true;
      }
      return super.isApprovedForAll(owner, operator);
  }

  string constant SVGHeader = '<svg viewBox="0 0 1024 1024'
      '"  xmlns="http://www.w3.org/2000/svg">\n'
      '<defs>\n'
      ' <filter id="f1" x="0" y="0" width="200%" height="200%">\n'
      '  <feOffset result="offOut" in="SourceAlpha" dx="24" dy="32" />\n'
      '  <feGaussianBlur result="blurOut" in="offOut" stdDeviation="16" />\n'
      '  <feBlend in="SourceGraphic" in2="blurOut" mode="normal" />\n'
      ' </filter>\n'
      '<g id="base">\n'
      ' <rect x="0" y="0" width="512" height="512" fill="#4285F4" />\n'
      ' <rect x="0" y="512" width="512" height="512" fill="#34A853" />\n'
      ' <rect x="512" y="0" width="512" height="512" fill="#FBBC05" />\n'
      ' <rect x="512" y="512" width="512" height="512" fill="#EA4335"/>\n'
      '</g>';

  /*
   * A function of IAssetStoreToken interface.
   * It generates SVG with the specified style, using the given "SVG Part".
   */
   //�Zstyle�̓g�[�N���̐F�p�^�[��
  function generateSVG(string memory _svgPart, uint256 _style, string memory _tag) public pure override returns (string memory) {
    bytes memory assetTag = abi.encodePacked('#', _tag);
    bytes memory image = abi.encodePacked(
      SVGHeader,
      _svgPart,
      '</defs>\n'
      '<g filter="url(#f1)">\n');
    //�Zsytle==0�̓v���C�}���[
    if (_style == 0) {
      image = abi.encodePacked(image,
      ' <mask id="assetMask">\n'
      '  <use href="', assetTag, '" fill="white" />\n'
      ' </mask>\n'
      ' <use href="#base" mask="url(#assetMask)" />\n');
    //�Z���̑��̃{�[�i�X�g�[�N���i_style < tokensPerAsset - 1�j�ȊO�̃g�[�N��
    } else if (_style < tokensPerAsset - 1) {
      image = abi.encodePacked(image,
      ' <use href="#base" />\n'
      ' <use href="', assetTag, '" fill="',(_style % 2 == 0) ? 'black':'white','" />\n');
    //�Z�{�[�i�X�g�[�N��
    } else {
      image = abi.encodePacked(image,
      ' <mask id="assetMask" desc="Material Icons (Apache 2.0)/Social/Public">\n'
      '  <rect x="0" y="0" width="1024" height="1024" fill="white" />\n'
      '  <use href="', assetTag, '" fill="black" />\n'
      ' </mask>\n'
      ' <use href="#base" mask="url(#assetMask)" />\n');
    }
    return string(abi.encodePacked(image, '</g>\n</svg>'));
  }

  /*
   * A function of IAssetStoreToken interface.
   * It returns the assetId, which this token uses.
   */
  function assetIdOfToken(uint256 _tokenId) public view override returns(uint256) {
    require(_exists(_tokenId), 'MaterialToken.assetIdOfToken: nonexistent token');
    return assetIds[_tokenId / tokensPerAsset];
  }

  /*
   * A function of IAssetStoreToken interface.
   * Each 16-bit represents the number of possible styles, allowing various combinations.
   */
  //�����ꂼ���16-bit���A�\��style�̐���\�킷�E�E�E�Ƃ����������܂�����s�\
  function styles() external pure override returns(uint256) {
    return tokensPerAsset;
  }

  //�Z����tokenURI�Ŏg���Ă�������֐�
  function _generateTraits(uint256 _tokenId, IAssetStore.AssetAttributes memory _attr) internal view returns (bytes memory) {
    return abi.encodePacked(
      '{'
        '"trait_type":"Primary",'
        '"value":"', _isPrimary(_tokenId) ? 'Yes':'No', '"' 
      '},{'
        '"trait_type":"Group",'
        '"value":"', _attr.group, '"' 
      '},{'
        '"trait_type":"Category",'
        '"value":"', _attr.category, '"' 
      '},{'
        '"trait_type":"Minter",'
        '"value":"', (bytes(_attr.minter).length > 0)?
              assetStore.getStringValidator().sanitizeJason(_attr.minter) : bytes('(anonymous)'), '"' 
      '}'
    );
  }

  //�Z�����l�Z�b�g����Ă��邪�AOwner���ύX�ł���悤�ɂ��Ă���B
  function setDescription(string memory _description) external onlyOwner {
      description = _description;
  }

  /**
    * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    * @dev See {IERC721Metadata-tokenURI}.
    */
  //�Zdata:application/json;base64,�ujson��base64�G���R�[�h�������́v��json�f�[�^��ԋp�ł���B
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    require(_exists(_tokenId), 'MaterialToken.tokenURI: nonexistent token');
    uint256 assetId = assetIdOfToken(_tokenId);
    IAssetStore.AssetAttributes memory attr = assetStore.getAttributes(assetId);
    string memory svgPart = assetStore.generateSVGPart(assetId, attr.tag);
    bytes memory image = bytes(generateSVG(svgPart, _tokenId % tokensPerAsset, attr.tag));

    return string(
      abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(
          bytes(
            abi.encodePacked(
              '{"name":"', attr.name, 
                '","description":"', description, 
                '","attributes":[', _generateTraits(_tokenId, attr), 
                '],"image":"data:image/svg+xml;base64,', 
                Base64.encode(image), 
              '"}')
          )
        )
      )
    );
  }  
}
