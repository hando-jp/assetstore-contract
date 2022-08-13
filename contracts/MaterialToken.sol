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
//■erc721aの実態はどこにある？？
//〇→package.jsonで指定することで使えている
import "erc721a/contracts/ERC721A.sol";
import { IAssetStoreRegistry, IAssetStore } from './interfaces/IAssetStore.sol';
import { IAssetStoreToken } from './interfaces/IAssetStoreToken.sol';
//〇base64もpackage.jsonで指定することで使えている
import { Base64 } from 'base64-sol/base64.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';

contract MaterialToken is Ownable, ERC721A, IAssetStoreToken {

  //〇StringsのLibraryが使える。value.toString()などの型変換
  using Strings for uint256;
  using Strings for uint16;

  //〇immutableは定数とは違い、初期デプロイ時（=construct起動時に設定されて変更できないもの、ガス代の節約？？）
  IAssetStoreRegistry public immutable registry;
  IAssetStore public immutable assetStore;

  //〇１つのアセットに対していくつtokenを発行するか。マテリアルアイコンの場合は4つ
  //■tokenIdはMaterialToken内だけのものなのだろうか？？
  //〇→その通りだった。token group内で採番されている
  //〇AssetIdはAsset全体での採番
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
   //〇ECR721Aのコンストラクターに値を渡している。
   //■MaterialTokenはどこでコンストラクターが呼び出されているか。。要確認
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

  //■プライマリートークンかどうか。なぜプライマリーが必要？？ERC721Aの仕様ではなかった。
  function _isPrimary(uint256 _tokenId) internal pure returns(bool) {
    return _tokenId % tokensPerAsset == 0;
  }

  /*
   * It registers the specified asset to the AssetStore and
   * mint three tokens to the msg.sender, and one additional
   * token to either the affiliator, the developer or the owner.npnkda
   */
   //〇IAssetStoreRegistry is a interface for contracts to register Assets
   //〇Parts of assetInfo are viewed at opensea
   //〇affiliate = primary token of affiliater
  function mintWithAsset(IAssetStoreRegistry.AssetInfo memory _assetInfo, uint256 _affiliate) external {

    //〇group is registered by hard cording
    _assetInfo.group = "Material Icons (Apache 2.0)";
    //〇Assets are registered here.Assets are numbered.
    uint256 assetId = registry.registerAsset(_assetInfo);
    //〇_nextTokenId is defined in ERC721A.
    uint256 tokenId = _nextTokenId(); 

    //〇AssetId is identified not in only Material but in all assets
    assetIds[tokenId / tokensPerAsset] = assetId;
    //〇_mint is implemented in ERC721A for bulk mint.
    //〇3 of 4 for minter
    _mint(msg.sender, tokensPerAsset - 1);

    // Specified affliate token must be one of soul-bound token and not owned by the minter.
    //〇こちらのownerOfはECR721トークンとしてのOwner
    if (_affiliate > 0 && _isPrimary(_affiliate) && ownerOf(_affiliate) != msg.sender) {
      _mint(ownerOf(_affiliate), 1);
    } else if ((tokenId / tokensPerAsset) % 4 == 0) {
      // 1 in 24 tokens goes to the developer
      //〇これは間違いでは？？16個に一つ？？tokenIdは4個ずつ増える、4回のmintに1回？
      _mint(developer, 1);
    } else {
      // the rest goes to the owner for distribution
      //■owner()はどこに定義されている？？
      //〇→Ownable内だった。×トークンのオーナーを返す。コントラクトのownerを返す。
      //■developerとownerで分けているのはなぜか？？
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
  //〇isApprovedForAllはERC721の規格
  //■open seaに取引代行の権限移譲されているかの確認？
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
   //〇styleはトークンの色パターン
  function generateSVG(string memory _svgPart, uint256 _style, string memory _tag) public pure override returns (string memory) {
    bytes memory assetTag = abi.encodePacked('#', _tag);
    bytes memory image = abi.encodePacked(
      SVGHeader,
      _svgPart,
      '</defs>\n'
      '<g filter="url(#f1)">\n');
    //〇sytle==0はプライマリー
    if (_style == 0) {
      image = abi.encodePacked(image,
      ' <mask id="assetMask">\n'
      '  <use href="', assetTag, '" fill="white" />\n'
      ' </mask>\n'
      ' <use href="#base" mask="url(#assetMask)" />\n');
    //〇その他のボーナストークン（_style < tokensPerAsset - 1）以外のトークン
    } else if (_style < tokensPerAsset - 1) {
      image = abi.encodePacked(image,
      ' <use href="#base" />\n'
      ' <use href="', assetTag, '" fill="',(_style % 2 == 0) ? 'black':'white','" />\n');
    //〇ボーナストークン
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
  //■それぞれの16-bitが、可能なstyleの数を表わす・・・という部分がまだ理解不能
  function styles() external pure override returns(uint256) {
    return tokensPerAsset;
  }

  //〇下のtokenURIで使っている内部関数
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

  //〇初期値セットされているが、Ownerが変更できるようにしている。
  function setDescription(string memory _description) external onlyOwner {
      description = _description;
  }

  /**
    * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    * @dev See {IERC721Metadata-tokenURI}.
    */
  //〇data:application/json;base64,「jsonをbase64エンコードしたもの」でjsonデータを返却できる。
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
