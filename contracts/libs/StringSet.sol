// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import { IStringValidator } from '../interfaces/IStringValidator.sol';

/*
 * StringSet stores a set of names (or either group or catalog in AssetStore). 
 */
 //���}�X�^�n��library�ō��̂��K���Ă���̂��H�H
library StringSet {

  //��library�̒���struct�͂ǂ����������ɂȂ�H�H�������ɂȂ��Ă���B
  //�Z  ��using StringSet for StringSet.Set; �Ƃ����g����������B
  //�������͊֐��O�Ȃ̂Ńu���b�N�`�F�[����ɋL�^����Ă���
  struct Set {
    mapping(uint32 => string) names; //�ԍ��Ɩ��O
    uint32 nextIndex;
    //�����̂���̋t�Q�Ƃ�����̂͂Ȃ��HStrorage������Ă��邯�ǁB�Bnames�����[�v���ĒT���΂����̂ł́H�H
    mapping(string => uint32) ids; // index+1
  }


  //�Zname��validator�@���@name����id��Ԃ��Ă���B
  //��library�̊֐��͂��ׂ�internal??
  //��getOrCreated�ɂ��Ă���̂́A�Ȃ��H�H�}�X�^�����e�i���X�@�\�̏ȗ����邽�߁H�H
  function getOrCreateId(Set storage _set, string memory _name, IStringValidator _validator) internal returns(uint32, bool) {
    uint32 id = _set.ids[_name];

    //�Z���ł�name�����݂���ꍇ
    if (id > 0) {
      return (id, false);
    }

    //�Z�܂�name�����݂��Ă��Ȃ��ꍇ
    //�Zname��string��bytes�ɕϊ����āAvalidate���Ă���
    require(_validator.validate(bytes(_name)), "StringSet.getId: Invalid String");
    //�Z���Ȃ�������o�^
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