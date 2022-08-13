// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { IStringValidator } from '../interfaces/IStringValidator.sol';

/*
 * StringSet stores a set of names (or either group or catalog in AssetStore). 
 */
 //■マスタ系はlibraryで作るのが適しているのか？？
library StringSet {

  //■libraryの中のstructはどういう動きになる？？第一引数になっている。
  //〇  →using StringSet for StringSet.Set; という使われ方をする。
  //■ここは関数外なのでブロックチェーン上に記録されている
  struct Set {
    mapping(uint32 => string) names; //番号と名前
    uint32 nextIndex;
    //■名称からの逆参照があるのはなぜ？Strorageを消費しているけど。。namesをループして探せばいいのでは？？
    mapping(string => uint32) ids; // index+1
  }


  //〇nameとvalidator　→　nameからidを返している。
  //■libraryの関数はすべてinternal??
  //■getOrCreatedにしているのは、なぜ？？マスタメンテナンス機能の省略するため？？
  function getOrCreateId(Set storage _set, string memory _name, IStringValidator _validator) internal returns(uint32, bool) {
    uint32 id = _set.ids[_name];

    //〇すでにnameが存在する場合
    if (id > 0) {
      return (id, false);
    }

    //〇まだnameが存在していない場合
    //〇nameをstring→bytesに変換して、validateしている
    require(_validator.validate(bytes(_name)), "StringSet.getId: Invalid String");
    //〇問題なかったら登録
    _set.names[_set.nextIndex++] = _name;
    id = _set.nextIndex; // idex + 1
    _set.ids[_name] = id; 
    return (id, true);
  }

  function getId(Set storage _set, string memory _name) internal view returns (uint32) {
    uint32 id = _set.ids[_name];
    require(id > 0, "StringSet: the specified name does not exist");
    return id;
  }

  /*
   * Retuns the number of items in the set. 
   */
  function getCount(Set storage _set) internal view returns (uint32) {
    return _set.nextIndex;
  }

  /*
   * Safe method to access the name with its index
   */
  function nameAtIndex(Set storage _set, uint32 _index) internal view returns(string memory) {
    require(_index < _set.nextIndex, "StringSet.nameAtIndex: The index is out of range");
    return _set.names[_index];
  }
}