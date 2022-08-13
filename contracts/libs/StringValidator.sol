// SPDX-License-Identifier: MIT
import { IStringValidator } from '../interfaces/IStringValidator.sol';

pragma solidity ^0.8.6;


contract StringValidator is IStringValidator {

  //〇bytesはbyteのarray(バイナリデータ等の扱い)、solidityではstringも同様
  //〇type of an argument as memory = passing an argument by value  →　default ,so it is redundant?
  //〇type of an argument as storage = passing an argument by reference
  function validate(bytes memory str) external pure override returns (bool) {
    for(uint i; i < str.length; i++){
      //〇bytes1 is 1 column
      bytes1 char = str[i];
        if(!(
         (char >= 0x30 && char <= 0x39) || //0-9
         (char >= 0x41 && char <= 0x5A) || //A-Z
         (char >= 0x61 && char <= 0x7A) || //a-z
         (char == 0x20) || //SP
         (char == 0x23) || // #
         (char == 0x28) || // (
         (char == 0x29) || // )
         (char == 0x2C) || //,
         (char == 0x2D) || //-
         (char == 0x2E) // .
        )) {
          return false;
      }
    }
    return true;
  }

  //〇こちらの引数はなぜstring型?
  //〇retrun value can be memory
  function sanitizeJason(string memory _str) external override pure returns(bytes memory) {

    //〇stringをbyte arrayに変換している
    bytes memory src = bytes(_str);
    bytes memory res;
    uint i;
    for (i=0; i<src.length; i++) {
      uint8 b = uint8(src[i]);
      // Skip control codes, escape backslash and double-quote
      // 〇なぜbackslashとdouble-quoteだけでよいのか？？
      if (b >= 0x20) {
        if  (b == 0x5c || b == 0x22) {
          
          //〇0x5c=backslash をつけている？？なぜ？？
          res = abi.encodePacked(res, bytes1(0x5c));
        }
        res = abi.encodePacked(res, b);
      }
    }
    return res;
  }  
}