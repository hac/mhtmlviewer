/* -*- Mode: ObjC; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is UnMHT for QuickLook.
 *
 * The Initial Developer of the Original Code is arai.
 * Portions created by the Initial Developer are Copyright (C) 2007
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s): arai <arai@mail.unmht.org>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "arUnMHTExtractor.h"
#include "stdlib.h"
#include "ctype.h"

@implementation arUnMHTExtractorFile
/**
 * 初期化
 *
 * @return id
 *         自分自身
 */
- (id) init {
  self = [super init];
  
  self->charset = @"";
  self->cid = @"";
  self->location = @"";
  self->baseDir = @"";
  self->referredBaseDir = @"";
  self->leafName = @"";
  self->extension = @"";
  self->disposition = @"";
  self->dispositionType = @"";
  self->encoding = 0;
  self->content = @"";
  self->binContent
    = [NSData
        dataWithBytes: ""
               length: 0];
  self->deleted = false;
  self->nativeFilename = @"";
  self->size = 0;
  
  return self;
}
/**
 * 開放
 */
- (void) release {
  [super release];
}
@end

@implementation arUnMHTExtractor
/**
 * 初期化
 *
 * @return id
 *         自分自身
 */
- (id) init {
  self = [super init];
  if (self == nil) {
    return nil;
  }
  
  self->boundary = @"";
  self->boundaryStack = nil;
  self->subject = @"";
  self->start = @"";
  self->rootFile = nil;
  self->alternative = false;
  self->files = nil;
  
  return self;
}

/**
 * 開放
 */
- (void) release {
  if (self->boundaryStack != nil) {
    [self->boundaryStack release];
    self->boundaryStack = nil;
  }
  if (self->rootFile != nil) {
    /* 参照だけなので開放はしない */
    self->rootFile = nil;
  }
  if (self->files != nil) {
    [self->files release];
    self->files = nil;
  }
  
  [super release];
}

/**
 * Base64 をデコードする
 *
 * @param  NSString *text
 *         デコードする文字列
 * @return NSData *
 *         デコードしたデータ
 *
 */
- (NSData *) atob: (NSString *)text {
  int i, j;
  int length;
  const char *ascii;
  char *binary;
  char *b;
  char *c;
  char part1, part2, part3, part4;
  NSData *data;
  
  length = [text length];
  ascii
    = [text
        cStringUsingEncoding: NSASCIIStringEncoding];
  binary = (char *)malloc (length + 1);
  b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
  
  for (i = 0, j = 0; i < length; i += 4) {
    c = strchr (b, ascii [i]);
    if (c != NULL) {
      part1 = (char)(c - b);
    }
    else {
      part1 = -1;
    }
    c = strchr (b, ascii [i + 1]);
    if (c != NULL) {
      part2 = (char)(c - b);
    }
    else {
      part2 = -1;
    }
    c = strchr (b, ascii [i + 2]);
    if (c != NULL) {
      part3 = (char)(c - b);
    }
    else {
      part3 = -1;
    }
    c = strchr (b, ascii [i + 3]);
    if (c != NULL) {
      part4 = (char)(c - b);
    }
    else {
      part4 = -1;
    }
    
    if (part1 != -1 && part2 != -1) {
      binary [j] = (part1 << 2) | (part2 >> 4);
      j ++;
    }
    if (part2 != -1 && part3 != -1 && part3 != 64) {
      binary [j] = ((part2 & 0x0f) << 4) | (part3 >> 2);
      j ++;
    }
    if (part3 != -1 && part4 != -1 && part4 != 64) {
      binary [j] = ((part3 & 0x03) << 6) | (part4);
      j ++;
    }
  }
  
  data
    = [NSData
        dataWithBytes: binary
               length: j];
  free (binary);
  
  return data;
}

/**
 * Base64 にエンコードする
 *
 * @param  NSData *data
 *         エンコードするデータ
 * @return NSString *
 *         エンコードした文字列
 */
- (NSString *) btoa: (NSData *)data {
  int i, j;
  int length;
  char *ascii;
  const char *binary;
  char *b;
  int c;
  int part1, part2, part3, part4;
  NSString *text;
  
  length = [data length];
  ascii = (char *)malloc (length * 2 + 1);
  binary = (const char *)[data bytes];
  b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
  
  for (i = 0, j = 0; i < length; i += 3) {
    c = (unsigned char)binary [i];
    part1 = c >> 2;
    part2 = (c & 0x3) << 4;
    if (i + 1 == length) {
      part3 = 64;
      part4 = 64;
    }
    else {
      c = binary [i + 1];
      part2 |= (c & 0xf0) >> 4;
      part3 = (c & 0x0f) << 2;
      if (i + 2 == length) {
        part4 = 64;
      }
      else {
        c = binary [i + 2];
        part3 |= (c & 0xc0) >> 6;
        part4 = c & 0x3f;
      }
    }
    ascii [j] = b [part1];
    j ++;
    ascii [j] = b [part2];
    j ++;
    ascii [j] = b [part3];
    j ++;
    ascii [j] = b [part4];
    j ++;
  }
  
  text
    = [[NSString alloc]
        initWithBytes: ascii
               length: j
             encoding: NSASCIIStringEncoding];
  free (ascii);
  
  return text;
}

/**
 * quoted-pritable をデコードする
 *
 * @param  NSString *text
 *         デコードする文字列
 * @return NSData *
 *         デコードしたデータ
 */
- (NSData *) decodeQuotedPrintable: (NSString *)text {
  int i, j;
  int length;
  const char *ascii;
  char *binary;
  char tmp [3];
  NSData *data;
  
  ascii
    = [text
        cStringUsingEncoding: NSASCIIStringEncoding];
  length = [text length];
  binary = (char *)malloc (length + 1);
  
  for (i = 0, j = 0; i < length;) {
    if (i < length - 2 && ascii [i] == '=') {
      if (isxdigit (ascii [i + 1])
          && isxdigit (ascii [i + 2])) {
        tmp [0] = ascii [i + 1];
        tmp [1] = ascii [i + 2];
        tmp [2] = '\0';
        binary [j] = (char)(unsigned char)strtol (tmp, NULL, 16);
        i += 3;
        j ++;
      }
      else {
        binary [j] = ascii [i];
        i ++;
        j ++;
      }
    }
    else {
      binary [j] = ascii [i];
      i ++;
      j ++;
    }
  }
  
  data
    = [NSData
        dataWithBytes: binary
               length: j];
  free (binary);
  
  return data;
}

/**
 * URL エンコーディングをデコードする
 *
 * @param  NSString *text
 *         デコードする文字列
 * @return NSData *
 *         デコードしたデータ
 */
- (NSData *) unescape: (NSString *)text {
  int i, j;
  int length;
  const char *ascii;
  char *binary;
  char tmp [3];
  NSData *data;
  
  ascii
    = [text
        cStringUsingEncoding: NSASCIIStringEncoding];
  length = [text length];
  binary = (char *)malloc (length + 1);
  
  for (i = 0, j = 0; i < length;) {
    if (i < length - 2 && ascii [i] == '%') {
      if (isxdigit (ascii [i + 1])
          && isxdigit (ascii [i + 2])) {
        tmp [0] = ascii [i + 1];
        tmp [1] = ascii [i + 2];
        tmp [2] = '\0';
        binary [j] = (char)(unsigned char)strtol (tmp, NULL, 16);
        i += 3;
        j ++;
      }
      else {
        binary [j] = ascii [i];
        i ++;
        j ++;
      }
    }
    else {
      binary [j] = ascii [i];
      i ++;
      j ++;
    }
  }
  
  data
    = [NSData
        dataWithBytes: binary
               length: j];
  free (binary);
  
  return data;
}

/**
 * encoded word をデコードする
 *
 * @param  NSString *text
 *         デコードする文字列
 * @return NSString *
 *         デコードした文字列
 */
- (NSString *) decodeEW: (NSString *)text {
  int length;
  NSRange range;
  NSRange range2;
  NSStringEncoding encoding;
  NSString *encodedCharset;
  NSString *encodedType;
  NSString *encodedText;
  NSData *encodedData;
  
  length = [text length];
  
  range
    = [text
        rangeOfString: @"=?"
              options: NSLiteralSearch];
  if (range.location != 0) {
    /* =? が 先頭に無い */
    return text;
  }
  range2
    = [text
        rangeOfString: @"?"
              options: NSLiteralSearch
                range: NSMakeRange (range.location + range.length,
                                    length - range.location - range.length)];
  if (range.location == NSNotFound) {
    /* ? が無い */
    return text;
  }
  encodedCharset
    = [text
        substringWithRange: NSMakeRange (range.location + range.length,
                                         range2.location
                                         - range.location - range.length)];
  range = range2;
  range2
    = [text
        rangeOfString: @"?"
              options: NSLiteralSearch
                range: NSMakeRange (range.location + range.length,
                                    length - range.location - range.length)];
  if (range.location == NSNotFound) {
    /* ? が無い */
    return text;
  }
  encodedType
    = [text
        substringWithRange: NSMakeRange (range.location + range.length,
                                         range2.location
                                         - range.location - range.length)];
  range = range2;
  range2
    = [text
        rangeOfString: @"?="
              options: NSLiteralSearch
                range: NSMakeRange (range.location + range.length,
                                    length - range.location - range.length)];
  if (range.location == NSNotFound) {
    /* ?= が無い */
    return text;
  }
  encodedText
    = [text
        substringWithRange: NSMakeRange (range.location + range.length,
                                         range2.location
                                         - range.location - range.length)];
  if ([encodedType
        isEqualToString: @"Q"]) {
    encodedData
      = [self
          decodeQuotedPrintable: encodedText];
  }
  else if ([encodedType
             isEqualToString: @"B"]) {
    encodedData
      = [self
          atob: encodedText];
  }
  else {
    encodedData
      = [encodedText
          dataUsingEncoding: NSASCIIStringEncoding];
  }
  
  encoding
    = CFStringConvertEncodingToNSStringEncoding
    (CFStringConvertIANACharSetNameToEncoding ((CFStringRef)encodedCharset));
  
  text
    = [[NSString alloc]
        initWithData: encodedData
            encoding: encoding];
  
  return text;
}

/**
 * MIME ヘッダを各名前と値に分割する
 *
 * @param  NSString *header
 *         MIME ヘッダ
 * @return NSMutableDictionary *
 *         ヘッダの内容を示す辞書
 *           <NSString *名前, NSString *値>
 *
 */
- (NSMutableDictionary *) splitHeader: (NSString *)header {
  char c;
  int length;
  NSRange range;
  NSRange restRange;
  NSRange lineRange;
  NSCharacterSet *characterSet;
  NSString *line;
  NSString *name;
  NSString *value;
  NSMutableDictionary *headerMap;
  
  headerMap = [[NSMutableDictionary alloc] init];
  
  restRange = NSMakeRange (0, [header length]);
  name = nil;
  value = nil;
  while (restRange.length > 0) {
    lineRange
      = [header
          lineRangeForRange: NSMakeRange (restRange.location, 0)];
    if (lineRange.location == NSNotFound) {
      break;
    }
    line
      = [header
          substringWithRange: lineRange];
    length = [line length];
    if (length >= 1) {
      c
        = [line
            characterAtIndex: length - 1];
      if (c == '\n') {
        line = [line
                 substringToIndex: length - 1];
        length --;
      }
    }
    if (length >= 1) {
      c
        = [line
            characterAtIndex: length - 1];
      if (c == '\r') {
        line = [line
                 substringToIndex: length - 1];
        length --;
      }
    }
    
    if (length == 0) {
      /* 終了 */
      break;
    }
    
    c
      = [line
          characterAtIndex: 0];
    if (c == ' ' || c == '\t') {
      /* 2 行目以降 */
      characterSet
        = [[NSCharacterSet
             characterSetWithCharactersInString: @" \t"]
            invertedSet];
      range
        = [line
            rangeOfCharacterFromSet: characterSet
                            options: NSLiteralSearch];
      if (range.location != NSNotFound) {
        value
          = [NSString stringWithFormat: @"%@%@",
                      value,
                      [line
                        substringFromIndex: range.location]];
      }
    }
    else {
      /* 1 行目 */
      if (name != nil) {
        [headerMap
          setValue: [self
                       decodeEW: value]
            forKey: [name lowercaseString]];
      }
      
      range
        = [line
            rangeOfString: @":"
                  options: NSLiteralSearch];
      if (range.location == NSNotFound) {
        /* : が無い */
        [headerMap release];
        return nil;
      }
      name
        = [line
            substringToIndex: range.location];
      
      characterSet
        = [[NSCharacterSet
             characterSetWithCharactersInString: @" "]
            invertedSet];
      range
        = [line
            rangeOfCharacterFromSet: characterSet
                            options: NSLiteralSearch
                              range: NSMakeRange (range.location + range.length,
                                                  length - range.location - range.length)];
      if (range.location == NSNotFound) {
        value = @"";
      }
      else {
        value
          = [line
              substringFromIndex: range.location];
      }
    }
    
    restRange
      = NSMakeRange (lineRange.location + lineRange.length,
                     [header length]
                     - lineRange.location - lineRange.length);
  }
  if (name != nil) {
    [headerMap
      setValue: [self
                   decodeEW: value]
        forKey: [name lowercaseString]];
  }
  
  return headerMap;
}

/**
 * RFC2231 をデコードする
 *
 * @param  NSString *text
 *         デコードする文字列
 * @return NSString *
 *         デコードした文字列
 */
- (NSString *) decodeRFC2231: (NSString *)text {
  NSRange range;
  NSRange range2;
  NSStringEncoding encoding;
  NSData *data;
  NSString *encode;
  NSString *language;
  
  range
    = [text
        rangeOfString: @"\'"
              options: NSLiteralSearch];
  if (range.location != NSNotFound
      && range.location > 0) {
    encode
      = [text
          substringToIndex: range.location];
    range2
      = [text
          rangeOfString: @"\'"
                options: NSLiteralSearch
                  range: NSMakeRange (range.location + range.length,
                                      [text length]
                                      - range.location - range.length)];
    if (range2.location != NSNotFound
        && range2.location + range2.length != [text length]) {
      language
        = [text
            substringWithRange: NSMakeRange (range.location
                                             + range.length,
                                             range2.location
                                             - range.location
                                             - range.length)];
      text
        = [text
            substringFromIndex: range2.location + range2.length];
      
      data
        = [self
            unescape: text];
      encoding
        = CFStringConvertEncodingToNSStringEncoding
        (CFStringConvertIANACharSetNameToEncoding ((CFStringRef)encode));
      text
        = [[NSString alloc]
            initWithData: data
                encoding: encoding];
    }
  }
  
  return text;
}

/**
 * Content-Type/Content-Disposition の値を解析する
 *
 * @param  NSString *value
 *         Content-Type/Content-Disposition の値
 * @param  bool mimeType
 *         値のみのフィールドは MIME Type か
 * @return NSMutableDictionary *
 *         解析した値の辞書
 *           <NSString *名前, NSString *値>
 */
- (NSMutableDictionary *) parseValue: (NSString *)value
                            mimeType: (bool)mimeType {
  int i;
  NSRange restRange;
  NSRange range;
  NSRange range2;
  NSString *index;
  NSString *current;
  NSString *name2;
  NSString *value2;
  NSString *realName;
  NSString *realValue;
  NSCharacterSet *separatorSet;
  NSCharacterSet *notSeparatorSet;
  NSMutableDictionary *map;
  NSMutableDictionary *map2;
  
  map = [[NSMutableDictionary alloc] init];
  map2 = [[NSMutableDictionary alloc] init];
  
  restRange = NSMakeRange (0, [value length]);
  
  separatorSet
    = [NSCharacterSet
        characterSetWithCharactersInString: @" \t;"];
  notSeparatorSet = [separatorSet invertedSet];
  while (restRange.length > 0) {
    range
      = [value
          rangeOfCharacterFromSet: separatorSet
                          options: NSLiteralSearch
                            range: restRange];
    if (range.location != NSNotFound) {
      current
        = [value
            substringWithRange: NSMakeRange (restRange.location,
                                             range.location
                                             - restRange.location)];
      restRange
        = NSMakeRange (range.location + range.length,
                       [value length]
                       - range.location - range.length);
      range
        = [value
            rangeOfCharacterFromSet: notSeparatorSet
                            options: NSLiteralSearch
                              range: restRange];
      if (range.location != NSNotFound) {
        restRange = NSMakeRange (range.location,
                                 [value length] - range.location);
      }
      else {
        restRange = NSMakeRange (0, 0);
      }
    }
    else {
      current
        = [value
            substringWithRange: restRange];
      restRange = NSMakeRange (0, 0);
    }
    
    range2
      = [current
          rangeOfString: @"="
                options: NSLiteralSearch];
    if (range2.location != NSNotFound) {
      name2
        = [current
            substringToIndex: range2.location];
      value2
        = [current
            substringFromIndex: range2.location + range2.length];
      if ([value2 length] >= 2) {
        if ([value2
              characterAtIndex: 0] == '\"'
            && [value2
                 characterAtIndex: [value2 length] - 1] == '\"') {
          value2
            = [value2
                substringWithRange: NSMakeRange (1, [value2 length] - 2)];
        }
        else if ([value2
                   characterAtIndex: 0] == '\''
                 && [value2
                      characterAtIndex: [value2 length] - 1] == '\'') {
          value2
            = [value2
                substringWithRange: NSMakeRange (1, [value2 length] - 2)];
        }
      }
      [map
        setValue: value2
          forKey: name2];
    }
    else {
      range2
        = [current
            rangeOfString: @"/"
                  options: NSLiteralSearch];
      if (range2.location != NSNotFound
          || !mimeType) {
        [map
          setValue: current
            forKey: @"_"];
      }
    }
  }
  
  for (name2 in map) {
    range
      = [name2
          rangeOfString: @"*"
                options: NSLiteralSearch];
    if (range.location != NSNotFound) {
      /* RFC2231 */
      
      if (range.location + range.length == [name2 length]) {
        /* 単体でエンコードあり */
        realName
          = [name2
              substringToIndex: [name2 length] - 1];
        value2
          = [map
              valueForKey: name2];
        realValue
          = [self
              decodeRFC2231: value2];
        
        [map2
          setValue: realValue
            forKey: realName];
      }
      else {
        i = range.location + range.length;
        
        while (i < [name2 length]
               && isdigit ([name2
                             characterAtIndex: i])) {
          i ++;
        }
        if (i == [name2 length]) {
          /* 複数でエンコードなし */
          index
            = [name2
                substringFromIndex: range.location + range.length];
        }
        else if ([name2
                   characterAtIndex: i] == '*') {
          /* 複数でエンコードあり */
          index
            = [name2
                substringWithRange: NSMakeRange (range.location
                                                 + range.length,
                                                 i
                                                 - range.location
                                                 - range.length)];
        }
        else {
          continue;
        }
        
        if ([index
              isEqualToString: @"0"]) {
          /* 最初の値 */
          realName
            = [name2
                substringToIndex: range.location];
          
          realValue = @"";
          
          i = 0;
          for (;;) {
            name2
              = [NSString stringWithFormat: @"%@*%d",
                          realName, i];
            if ([map
                  objectForKey: name2] != nil) {
              /* エンコードなし */
              value2
                = [map
                    valueForKey: name2];
              realValue
                = [NSString stringWithFormat: @"%@%@",
                            realValue, value2];
            }
            else {
              name2
                = [NSString stringWithFormat: @"%@*%d*",
                            realName, i];
              if ([map
                    objectForKey: name2] != nil) {
                /* エンコードあり */
                value2
                  = [map
                      valueForKey: name2];
                value2
                  = [self
                      decodeRFC2231: value2];
                realValue
                  = [NSString stringWithFormat: @"%@%@",
                              realValue, value2];
              }
              else {
                break;
              }
            }
            i ++;
          }
          
          [map2
            setValue: realValue
              forKey: realName];
        }
      }
    }
  }
  
  for (name2 in map2) {
    value2
      = [map2
          valueForKey: name2];
    [map
      setValue: value2
        forKey: name2];
  }
  
  [map2 release];
  
  return map;
}

/**
 * Content-Location を親ディレクトリとファイル名に分割する
 *
 * @param  UnMHTExtractorFile *file
 *         対象のファイル情報
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) splitLocation: (arUnMHTExtractorFile *)file {
  int i;
  NSRange range;
  
  range
    = [file->location
          rangeOfString: @"mhtml:"
          options: NSCaseInsensitiveSearch];
  if (range.location != NSNotFound) {
    /* mhtml で始まる場合 (IE のプロトコル ?) */
    
    /* ! の前後に分割する */
    i = [file->location length] - 1;
    while (i >= 0
           && [file->location
                  characterAtIndex: i] != '!') {
      i --;
    }
    if (i >= 0 && i != [file->location length] - 1) {
      /* ファイル名がある場合 */
      file->baseDir
        = [file->location
              substringToIndex: i];
      file->leafName
        = [file->location
              substringFromIndex: i + 1];
    }
    else {
      /* ファイル名がない場合 */
      file->baseDir = file->location;
      file->leafName = @"";
    }
  }
  else {
    range
      = [file->location
            rangeOfString: @"\\"
            options: NSLiteralSearch];
    if (range.location != NSNotFound) {
      /* Windows のパスの場合 */
      i = [file->location length] - 1;
      while (i >= 0
             && [file->location
                    characterAtIndex: i] != '\\') {
        i --;
      }
      if (i >= 0 && i != [file->location length] - 1) {
        /* ファイル名がある場合 */
        file->baseDir
          = [file->location
                substringToIndex: i];
        file->leafName
          = [file->location
                substringFromIndex: i + 1];
      }
      else {
        /* ファイル名がない場合 */
        file->baseDir = file->location;
        file->leafName = @"";
      }
    }
    else {
      range
        = [file->location
              rangeOfString: @"/"
              options: NSLiteralSearch];
      if (range.location != NSNotFound) {
        /* Mac OS X、Linux のパス、URI の場合 */
        i = [file->location length] - 1;
        while (i >= 0
               && [file->location
                      characterAtIndex: i] != '/') {
          i --;
        }
        if (i >= 0 && i != [file->location length] - 1) {
          /* ファイル名がある場合 */
          file->baseDir
            = [file->location
                  substringToIndex: i];
          file->leafName
            = [file->location
                  substringFromIndex: i + 1];
        }
        else {
          /* ファイル名がない場合 */
          file->baseDir = file->location;
          file->leafName = @"";
        }
      }
      else {
        range
          = [file->location
                rangeOfString: @":"
                options: NSLiteralSearch];
        if (range.location != NSNotFound) {
          /* Mac OS 9 以前のパスの場合 */
          i = [file->location length] - 1;
          while (i >= 0
                 && [file->location
                        characterAtIndex: i] != ':') {
            i --;
          }
          if (i >= 0 && i != [file->location length] - 1) {
            /* ファイル名がある場合 */
            file->baseDir
              = [file->location
                    substringToIndex: i];
            file->leafName
              = [file->location
                    substringFromIndex: i + 1];
          }
          else {
            /* ファイル名がない場合 */
            file->baseDir = file->location;
            file->leafName = @"";
          }
        }
        else {
          /* ファイル名のみの場合 */
          file->baseDir = @"";
          file->leafName = file->location;
        }
      }
    }
  }
  
  return 1;
}

/**
 * ヘッダを解析して UnMHTExtractorFile オブジェクトを作成する
 *
 * @return NSMutableDictionary *headerMap
 *         ヘッダの内容を示す辞書
 *           <NSString *名前, NSString *値>
 * @return UnMHTExtractorFile *
 *         作成されたファイル情報
 */
- (arUnMHTExtractorFile *) parseHeader: (NSMutableDictionary *)headerMap {
  int i;
  NSRange range;
  NSString *name;
  NSString *value;
  NSMutableDictionary *valueMap;
  NSString *value2Lower;
  NSString *boundary2;
  arUnMHTExtractorFile *file;
  
  boundary2 = @"";
  
  file = [[arUnMHTExtractorFile alloc] init];
  
  file->charset = @"UTF-8";
  
  if ([headerMap
        objectForKey: @"content-type"] != nil) {
    value
      = [headerMap
          valueForKey: @"content-type"];
  }
  else {
    value = @"text/html";
  }
  valueMap
    = [self
        parseValue: value
          mimeType: true];
  for (name in valueMap) {
    if ([name
          isEqualToString: @"_"]) {
      file->filetype
        = [valueMap
            valueForKey: name];
    }
    else if ([name
               isEqualToString: @"charset"]) {
      file->charset
        = [valueMap
            valueForKey: name];
    }
    else if ([name
               isEqualToString: @"boundary"]) {
      boundary2
        = [valueMap
            valueForKey: name];
    }
    else if ([name
               isEqualToString: @"start"]) {
      self->start
        = [valueMap
            valueForKey: name];
      if ([self->start length] > 1
          && [self->start
                 characterAtIndex: 0] == '<') {
        self->start
          = [self->start
                substringFromIndex: 1];
      }
      if ([self->start length] > 1
          && [self->start
                 characterAtIndex: [self->start length] - 1] == '>') {
        self->start
          = [self->start
                substringToIndex: [self->start length] - 1];
      }
    }
  }
  
  if ([headerMap
        objectForKey: @"subject"] != nil) {
    self->subject
      = [headerMap
          valueForKey: @"subject"];
  }
  
  if (![file->filetype
           isEqualToString: @""]) {
    range
      = [file->filetype
            rangeOfString: @"multipart/"
            options: NSCaseInsensitiveSearch];
    if (range.location == 0) {
      /* マルチパート */
      if (![boundary2
             isEqualToString: @""]) {
        if (![self->boundary
                 isEqualToString: @""]) {
          [self->boundaryStack
              addObject: self->boundary];
        }
        self->boundary = boundary2;
      }
      else {
        /* ヘッダが異常 */
        [file release];
        return nil;
      }
    }
    else {
      /* 通常のファイルならば */
      
      /* Content-Disposition を解析 */
      file->disposition = @"";
      if ([headerMap
            objectForKey: @"content-disposition"] != nil) {
        NSString *disposition;
        
        disposition
          = [headerMap
              valueForKey: @"content-disposition"];
        if (![[disposition lowercaseString]
               isEqualToString: @"inline"]) {
          valueMap
            = [self
                parseValue: disposition
                  mimeType: true];
          for (name in valueMap) {
            if ([name
                  isEqualToString: @"_"]) {
              file->dispositionType
                = [valueMap
                    valueForKey: name];
            }
            else if ([name
                       isEqualToString: @"filename"]) {
              file->disposition
                = [valueMap
                    valueForKey: name];
            }
          }
        }
      }
      
      /* Content-Location を解析 */
      if ([headerMap
            objectForKey: @"content-location"] != nil) {
        file->location
          = [headerMap
              valueForKey: @"content-location"];
      }
      else {
        file->location = @"";
      }
      if ([file->location
              isEqualToString: @""]) {
        /* ルートドキュメントの Content-Location が
         * 指定されない場合があるので index.html とする */
        if ([file->filetype
                isEqualToString: @"text/heml"]) {
          file->location = @"index.html";
        }
      }
      
      range
        = [file->location
              rangeOfString: @"file:///"
              options: NSCaseInsensitiveSearch];
      if (range.location == 0) {
        file->location = 
          [file->location
              stringByReplacingCharactersInRange: range
              withString: @"unmht://dummy/"];
      }
      else {
        range
          = [file->location
                rangeOfString: @"file://"
                options: NSCaseInsensitiveSearch];
        if (range.location == 0) {
          file->location = 
            [file->location
                stringByReplacingCharactersInRange: range
                withString: @"unmht://dummy/"];
        }
      }
      
      [self
        splitLocation: file];
      
      /* Content-ID を解析 */
      if ([headerMap
            objectForKey: @"content-id"] != nil) {
        file->cid
          = [headerMap
              valueForKey: @"content-id"];
        if ([file->cid length] > 1
            && [file->cid
                   characterAtIndex: 0] == '<') {
          file->cid
            = [file->cid
                  substringFromIndex: 1];
        }
        if ([file->cid length] > 1
            && [file->cid
                   characterAtIndex: [file->cid length] - 1] == '>') {
          file->cid
            = [file->cid
                  substringToIndex: [file->cid length] - 1];
        }
      }
      else {
        file->cid = @"";
      }
      
      /* ファイル名を調べる */
      NSString *leafName;
      leafName = @"";
      
      if ([file->disposition
              isEqualToString: @""]) {
        /* Content-Disposition が存在しない場合 */
        leafName = file->leafName;
      }
      else {
        /* Content-Disposition が存在する場合 */
        leafName = file->disposition;
      }
      
      i = [leafName length] - 1;
      while (i > 0
             && isalnum ([leafName
                           characterAtIndex: i])) {
        i --;
      }
      if (i > 0 && i != [leafName length] - 1) {
        file->extension
          = [leafName
              substringFromIndex: i + 1];
      }
      else {
        file->extension = @"";
      }
      
      file->referredBaseDir = @"";
      
      /* Content-Transfer-Encoding を解析する */
      if ([headerMap
            objectForKey: @"content-transfer-encoding"] != nil) {
        value
          = [headerMap
              valueForKey: @"content-transfer-encoding"];
      }
      else {
        value = @"";
      }
      
      value2Lower = [value lowercaseString];
      if ([value2Lower
            isEqualToString: @"quoted-printable"]) {
        file->encoding = 1;
      }
      else if ([value2Lower
                 isEqualToString: @"base64"]) {
        file->encoding = 2;
      }
      else if ([value2Lower
                 isEqualToString: @"7bit"]) {
        file->encoding = 3;
      }
      else {
        file->encoding = 0;
      }
      
      if ([file->filetype
              isEqualToString: @"text/html"]) {
        if (self->rootFile == nil
            || self->alternative
            || [self->start
                   isEqualToString: file->cid]) {
          /* 最初の HTML ファイルか、指定された Content-ID ならば、
           * これをルートドキュメントとする */
          self->rootFile = file;
          self->alternative = false;
        }
      }
      
      [self->files
          addObject: file];
    }
  }
  
  return file;
}

/**
 * mht ファイルを解析する
 *
 * @param  NSString *text
 *         mht ファイルの内容
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) parseMHT: (NSString *)text {
  int start_pos, end_pos;
  int length;
  int i;
  NSString *header;
  NSString *body;
  NSString *subpart;
  NSRange range;
  NSRange range2;
  NSMutableDictionary *headerMap;
  arUnMHTExtractorFile *file;
  
  length = [text length];
  
  start_pos = 0;
  
  /* ヘッダの終わりの検索 */
  range
    = [text
        rangeOfString: self->retcode2
              options: NSLiteralSearch
                range: NSMakeRange (start_pos, length - start_pos)];
  end_pos = range.location;
  if (end_pos == NSNotFound) {
    /* ヘッダが存在しない */
    return 0;
  }
  
  header
    = [text
        substringWithRange: NSMakeRange (start_pos,
                                         end_pos + [self->retcode2 length])];
  body
    = [text
        substringFromIndex: end_pos + [self->retcode2 length]];
  headerMap
    = [self
        splitHeader: header];
  file
    = [self
        parseHeader: headerMap];
  if (file == nil) {
    /* ヘッダが異常な場合、終了する */
    return 0;
  }
  
  range
    = [[file->filetype lowercaseString]
        rangeOfString: @"multipart/"
              options: NSCaseInsensitiveSearch];
  if (range.location == 0) {
    /* multipart の場合 */
    if ([[file->filetype lowercaseString]
          isEqualToString: @"multipart/alternative"]) {
      self->alternative = true;
    }
    
    i = 0;
    range = NSMakeRange (0, 0);
    for (;;) {
      range2
        = [body
            rangeOfString: [NSString stringWithFormat: @"--%@%@",
                                     self->boundary,
                                     self->retcode]
                  options: NSLiteralSearch
                    range: NSMakeRange (range.location + range.length,
                                        [body length]
                                        - range.location - range.length)];
      if (range2.location != NSNotFound) {
        if (i != 0) {
          /* 最初は boundary に挟まれていないので無効 */
          subpart
            = [body
                substringWithRange: NSMakeRange (range.location + range.length,
                                                 range2.location
                                                 - range.location
                                                 - range.length)];
          if ([subpart length] > 0) {
            [self
              parseMHT: subpart];
          }
        }
      }
      else {
        range2
          = [body
              rangeOfString: [NSString stringWithFormat: @"--%@--",
                                       self->boundary]
                    options: NSLiteralSearch
                      range: NSMakeRange (range.location + range.length,
                                          [body length]
                                          - range.location - range.length)];
        if (range2.location != NSNotFound) {
          if (i != 0) {
            /* 最初は boundary に挟まれていないので無効 */
            subpart
              = [body
                  substringWithRange: NSMakeRange (range.location
                                                   + range.length,
                                                   range2.location
                                                   - range.location
                                                   - range.length)];
            if ([subpart length] > 0) {
              [self
                parseMHT: subpart];
            }
            i = -1;
          }
        }
      }
      range = range2;
      if (range.location == NSNotFound) {
        /* もう boundary が見付からない */
        break;
      }
      if (i == -1) {
        /* 終端の boundary 後 */
        break;
      }
      i ++;
    }
    
    self->alternative = false;
    if ([self->boundaryStack count] > 0) {
      self->boundary
        = [self->boundaryStack
              objectAtIndex: [self->boundaryStack count] - 1];
      [self->boundaryStack removeLastObject];
    }
    else {
      self->boundary = @"";
    }
  }
  else {
    if (file->encoding == 1) {
      /* quoted-printable */
      file->content
        = [body
            stringByReplacingOccurrencesOfString
              : [NSString stringWithFormat: @"=%@", self->retcode]
              withString: @""];
    }
    else if (file->encoding == 2) {
      /* base64 */
      file->content
        = [body
            stringByReplacingOccurrencesOfString: self->retcode
                                      withString: @""];
    }
    else {
      file->content = body;
    }
    if ([file->filetype
            isEqualToString: @"application/octet-stream"]) {
      /* CGI の応答等の HTML かもしれない */
      if ([file->content length] > 1
          && [file->content
                 characterAtIndex: 1] == '<') {
        /* 先頭がタグっぽい */
        range
          = [body
              rangeOfString: @"<html"
                    options: NSCaseInsensitiveSearch];
        if (range.location != NSNotFound) {
          file->filetype = @"text/html";
        }
      }
    }
  }
  
  [headerMap release];
  
  return 1;
}

/**
 * 空のファイルを削除する
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) deleteEmptyFile {
  int i;
  arUnMHTExtractorFile *file;
  
  
  for (i = 0; i < [self->files count]; i ++) {
    file
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    if ([file->content
            isEqualToString: @""]) {
      [self->files
          removeObjectAtIndex: i];
      i --;
    }
  }
  
  return 1;
}

/**
 * Content-ID を重複しないように設定する
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) setCID {
  int i;
  arUnMHTExtractorFile *file;
  
  for (i = 0; i < [self->files count]; i ++) {
    file
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    if ([file->cid
            isEqualToString: @""]) {
      /* デフォルトの CID が無いので付ける */
      file->cid
        = [NSString stringWithFormat: @"unmht_cid_%d", i];
    }
  }
  
  return 1;
}

/**
 * 内容をデコードする
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) decodeContent {
  int i;
  arUnMHTExtractorFile *file;
  
  for (i = 0; i < [self->files count]; i ++) {
    file
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    
    if (file->deleted) {
      continue;
    }
    
    if (file->encoding == 1) {
      file->binContent
        = [self
            decodeQuotedPrintable: file->content];
    }
    else if (file->encoding == 2) {
      file->binContent
        = [self
            atob: file->content];
    }
    else {
      file->charset = @"UTF-8";
      file->binContent
        = [file->content
              dataUsingEncoding: NSUTF8StringEncoding];
    }
  }
  
  return 1;
}

/**
 * パスを展開、連結する
 *
 * @param  NSString *base
 *         親ディレクトリのパス
 * @param  NSString *sub
 *         相対パス、もしくは絶対パス
 * @return NSString *
 *         連結したパス
 */
- (NSString *) jointPath: (NSString *)base
                     sub: (NSString *)sub {
  int i;
  NSRange range;
  NSRange range2;
  NSRange restRange;
  NSString *path;
  NSString *sep;
  NSString *protocol;
  NSString *host;
  NSString *part;
  NSMutableArray *newNames;
  
  /* セパレータを検出 */
  if ([base
        rangeOfString: @"\\"
              options: NSLiteralSearch].location != NSNotFound) {
    /* Windows のパスの場合 */
    sep = @"\\";
  }
  else if ([base
             rangeOfString: @"/"
                   options: NSLiteralSearch].location != NSNotFound) {
    /* Mac OS X、Linux のパス、URI の場合 */
    sep = @"/";
  }
  else if ([base
             rangeOfString: @":"
                   options: NSLiteralSearch].location != NSNotFound) {
    /* Mac OS 9 以前のパスの場合 */
    sep = @":";
  }
  else {
    /* 区切りが見付からない場合連結できないので
     * サブのみ返す */
    return sub;
  }
  
  bool matched;
  
  matched = false;
  range
    = [base
        rangeOfString: @"://"
              options: NSLiteralSearch];
  if (range.location != NSNotFound
      && range.location > 0) {
    range2
      = [base
          rangeOfString: @"/"
                options: NSLiteralSearch
                  range: NSMakeRange (range.location + range.length,
                                      [base length]
                                      - range.location - range.length)];
    if (range2.location != NSNotFound) {
      /* URI の場合 */
      protocol 
        = [base
            substringToIndex: range.location + range.length];
      host
        = [base
            substringWithRange: NSMakeRange (range.location + range.length,
                                             range2.location
                                             - range.location - range.length)];
      base
        = [base
            substringFromIndex: range2.location + range2.length];
      matched = true;
    }
  }
  if (!matched) {
    range
      = [base
          rangeOfString: @":"
                options: NSLiteralSearch];
    if (range.location == 1) {
      /* Windows のネイティブなパスの場合 */
      protocol 
        = [base
            substringToIndex: range.location + range.length];
      host = @"";
      base
        = [base
            substringFromIndex: range.location + range.length];
      matched = true;
    }
  }
  if (!matched) {
    /* その他のパスの場合 */
    protocol = @"";
    host = @"";
  }
  
  range
    = [sub
        rangeOfString: @"://"
              options: NSLiteralSearch];
  if (range.location != NSNotFound
      && range.location > 0) {
    range2
      = [sub
          rangeOfString: @"/"
                options: NSLiteralSearch
                  range: NSMakeRange (range.location + range.length,
                                      [sub length]
                                      - range.location - range.length)];
    if (range2.location != NSNotFound) {
      /* sub が URI のネイティブな絶対パスの場合 */
      return sub;
    }
  }
  range
    = [sub
        rangeOfString: @":"
              options: NSLiteralSearch];
  if (range.location != NSNotFound
      && range.location > 0) {
    /* sub が Windows のネイティブな絶対パスの場合 */
    return sub;
  }
  
  if ([sub length] > 0
      && [[sub
            substringToIndex: 1]
           isEqualToString: sep]) {
    /* sub が絶対パスの場合 */
    base = @"";
  }
  
  path
    = [NSString stringWithFormat: @"%@%@%@",
                base, sep, sub];
  
  newNames = [[NSMutableArray alloc] init];
  
  restRange = NSMakeRange (0, [path length]);
  for (;;) {
    range
      = [path
          rangeOfString: sep
                options: NSLiteralSearch
                  range: restRange];
    if (range.location == NSNotFound) {
      [newNames
        addObject: [path
                      substringFromIndex: restRange.location]];
      break;
    }
    
    [newNames
      addObject: [path
                    substringWithRange: NSMakeRange (restRange.location,
                                                     range.location
                                                     - restRange.location)]];
    restRange = NSMakeRange (range.location + range.length,
                             [path length]
                             - range.location - range.length);
  }
  
  for (i = 0; i < [newNames count]; i ++) {
    part
      = [newNames
          objectAtIndex: i];
    
    if ([part
          isEqualToString: @"."]) {
      [newNames
           removeObjectAtIndex: i];
      i --;
    }
    else if ([part
               isEqualToString: @".."]) {
      [newNames
           removeObjectAtIndex: i];
      i --;
      if (i >= 0) {
        [newNames
             removeObjectAtIndex: i];
        i --;
      }
    }
    else if ([part
               isEqualToString: @""]) {
      [newNames
           removeObjectAtIndex: i];
      i --;
    }
  }
  
  path = @"";
  for (i = 0; i < [newNames count]; i ++) {
    part
      = [newNames
          objectAtIndex: i];
    path
      = [NSString stringWithFormat: @"%@%@%@",
                  path, sep, part];
  }
  
  path
    = [NSString stringWithFormat: @"%@%@%@",
                protocol, host, path];
  
  return path;
}

/**
 * mht に含まれるファイルを探す
 *
 * @param  UnMHTExtractorFile *file
 *         呼び出し元のファイル
 * @param  NSString *path
 *         対象のパス
 * @param  bool referred
 *         referredBaseDir をチェックするか
 * @return arUnMHTExtractorFile *
 *         対象のファイル
 *         見付からなければ null
 */
- (arUnMHTExtractorFile *) checkFile: (arUnMHTExtractorFile *)file
                                path: (NSString *)path
                            referred: (bool)referred {
  int i;
  NSString *jointedPath;
  NSString *jointedPath2;
  NSString *filename;
  NSString *cid;
  arUnMHTExtractorFile *file2;
  NSRange range;
  
  jointedPath
    = [self
        jointPath: file->baseDir
              sub: path];
  if (referred
      && ![file->referredBaseDir
              isEqualToString: @""]) {
    /* HTML ファイルから参照されたものの場合 */
    
    /* 参照元のファイルからの相対パスとみなす */
    jointedPath2
      = [self
          jointPath: file->referredBaseDir
                sub: path];
  }
  else {
    jointedPath2 = @"";
  }
  
  /* URI に対応するファイルが存在する場合 */
  for (i = 0; i < [self->files count]; i ++) {
    file2
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    
    filename = file2->location;
    if (![filename
           isEqualToString: @""]) {
      if ([path
            isEqualToString: filename]
          || [jointedPath
               isEqualToString: filename]
          || (referred
              && [jointedPath2
                   isEqualToString: filename])) {
        return file2;
      }
    }
  }
  
  /* ファイル名のみ対応するファイルが存在する場合 */
  for (i = 0; i < [self->files count]; i ++) {
    file2
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    
    filename = file2->leafName;
    if (![filename
           isEqualToString: @""]) {
      range
        = [path
            rangeOfString: filename
                  options: NSLiteralSearch];
      if (range.location == [path length] - [filename length]) {
        return file2;
      }
    }
  }
  
  /* Content-ID の場合 */
  cid = @"";
  range
    = [path
        rangeOfString: @"cid:"
              options: NSLiteralSearch];
  if (range.location == 0) {
    cid
      = [path
          substringFromIndex: range.location + range.length];
  }
  if (![cid
         isEqualToString: @""]) {
    for (i = 0; i < [self->files count]; i ++) {
      file2
        = (arUnMHTExtractorFile *)[self->files
                                      objectAtIndex: i];
      if (cid == file2->cid) {
        return file2;
      }
    }
  }
  
  return nil;
}

/**
 * HTML 部分のファイル名を置き換える
 *
 * @param NSString *content
 *        ファイルの中身
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (NSString *) replaceHTMLLocation: (NSString *)content
                              file: (arUnMHTExtractorFile *)file {
  int modified;
  char c;
  int i;
  NSRange rangeRest;
  NSRange rangeTagStart;
  NSRange rangeTagEnd;
  NSRange rangeTag;
  NSRange rangeTagRest;
  NSRange rangeSrc;
  NSRange rangeHref;
  NSRange valueRange;
  NSString *tag;
  NSString *beforeTag;
  NSString *afterTag;
  NSString *value;
  NSString *beforeValue;
  NSString *afterValue;
  
  /* タグの開始が探す */
  rangeRest = NSMakeRange (0, [content length]);
  for (;;) {
    if (rangeRest.location == NSNotFound) {
      /* 終了している */
      break;
    }
    rangeTagStart
      = [content
          rangeOfString: @"<"
                options: NSLiteralSearch
                  range: rangeRest];
    if (rangeTagStart.location == NSNotFound) {
      /* タグの開始が無い */
      break;
    }

    rangeRest = NSMakeRange (rangeTagStart.location
                             + rangeTagStart.length,
                             [content length]
                             - rangeTagStart.location
                             - rangeTagStart.length);
    /* タグの終了を探す */
    rangeTagEnd
      = [content
          rangeOfString: @">"
                options: NSLiteralSearch
                  range: rangeRest];
    if (rangeTagEnd.location != NSNotFound) {
      /* タグの終了が無い場合, 以降全てを対象とする */
      rangeRest = NSMakeRange (rangeTagEnd.location
                               + rangeTagEnd.length,
                               [content length]
                               - rangeTagEnd.location
                               - rangeTagEnd.length);
      rangeTag = NSMakeRange (rangeTagStart.location,
                              rangeTagEnd.location + rangeTagEnd.length
                              - rangeTagStart.location);
    }
    else {
      /* タグの終了がある場合, タグを対象とする */
      rangeRest = NSMakeRange (NSNotFound, 0);
      rangeTag = NSMakeRange (rangeTagStart.location,
                              [content length]
                              - rangeTagStart.location);
    }
    tag
      = [content
          substringWithRange: rangeTag];
    rangeTagRest = NSMakeRange (0, [tag length]);
    
    modified = false;
    for (;;) {
      /* src, href のそれぞれについてチェック */
      rangeSrc
        = [tag
            rangeOfString: @"src"
                  options: NSCaseInsensitiveSearch
                    range: rangeTagRest];
      rangeHref
        = [tag
            rangeOfString: @"href"
                  options: NSCaseInsensitiveSearch
                    range: rangeTagRest];
      if (rangeSrc.location != NSNotFound) {
        if (rangeHref.location != NSNotFound) {
          if (rangeSrc.location < rangeHref.location) {
            /* src の方が先にある */
            i = rangeSrc.location + rangeSrc.length;
          }
          else {
            /* href の方が先にある */
            i = rangeHref.location + rangeHref.length;
          }
        }
        else {
          /* src だけある */
          i = rangeSrc.location + rangeSrc.length;
        }
      }
      else if (rangeHref.location != NSNotFound) {
        /* href だけある */
        i = rangeHref.location + rangeHref.length;
      }
      else {
        /* 何もない */
        break;
      }
      
      /* 値を取得する */
      int state = 0;
      valueRange.location = NSNotFound;
      valueRange.length = NSNotFound;
      while (i < [tag length]) {
        c
          = [tag
              characterAtIndex: i];
        if (state == 0) {
          /* = を探す */
          if (c == ' ' || c == '\r' || c == '\n' || c == '\t') {
            i ++;
          }
          else if (c == '=') {
            state = 1;
            i ++;
          }
          else {
            /* マッチしない */
            break;
          }
        }
        else if (state == 1) {
          /* 値の開始を探す */
          if (c == ' ' || c == '\r' || c == '\n' || c == '\t') {
            i ++;
          }
          else {
            if (c == '\'' || c == '\"') {
              i ++;
            }
            state = 2;
            valueRange.location = i;
          }
        }
        else if (state == 2) {
          /* 値の終了を探す */
          if (c == ' ' || c == '\r' || c == '\n' || c == '\t'
              || c == '\'' || c == '\"') {
            valueRange.length = i - valueRange.location;
            break;
          }
          else {
            i ++;
          }
        }
      }
      if (i == [tag length]) {
        /* 末尾に到達 */
        break;
      }
      rangeTagRest = NSMakeRange (i, [tag length] - i);
      if (valueRange.location == NSNotFound
          || valueRange.length == NSNotFound) {
        /* マッチしなかった */
        continue;
      }
      value
        = [tag
            substringWithRange: valueRange];
      beforeValue
        = [tag
            substringToIndex: valueRange.location];
      afterValue
        = [tag
            substringFromIndex: valueRange.location + valueRange.length];
      
      /* パスを置き換える */
      arUnMHTExtractorFile *file2;
      file2
        = [self
            checkFile: file
                 path: value
             referred: false];
      if (file2 != nil) {
        /* 含まれていた場合 */
        if (file2->deleted) {
          /* 展開しなかった場合、削除する */
          value = @"";
          modified = true;
        }
        else {
          if (self->mode == 1) {
            value
              = [NSString stringWithFormat: @"cid:%@",
                          file2->cid];
          }
          else {
            value
              = [NSString stringWithFormat: @"%@/%@",
                          originalURISpec, file2->cid];
          }
          modified = true;
        }
      }
      else {
        /* 含まれていない場合 */
        if ([value
              rangeOfString: @"file://"
                    options: NSCaseInsensitiveSearch].location == 0) {
          /* 参照先はローカルファイルの場合、削除する */
          value = @"";
          modified = true;
        }
        else if ([value
                   rangeOfString: @":"
                         options: NSLiteralSearch].location != NSNotFound) {
          /* 絶対パスの場合そのままにする */
        }
        else if ([file->baseDir
                     isEqualToString: @""]) {
          value = @"";
          modified = true;
        }
        else {
          /* 相対パスの場合、元の場所へ取りに行くようにする */
          value
            = [self
                jointPath: file->baseDir
                      sub: value];
          modified = true;
        }
      }                
      
      i = [beforeValue length] + [value length];
      tag
        = [NSString stringWithFormat: @"%@%@%@",
                    beforeValue, value, afterValue];
      rangeTagRest = NSMakeRange (i, [tag length] - i);
    }
    
    if (modified) {
      /* 修正していれば作り直す */
      beforeTag
        = [content
            substringToIndex: rangeTag.location];
      afterTag
        = [content
            substringFromIndex: rangeTag.location + rangeTag.length];
      i = [beforeTag length] + [tag length];
      content
        = [NSString stringWithFormat: @"%@%@%@",
                    beforeTag, tag, afterTag];
      rangeRest = NSMakeRange (i, [content length] - i);
    }
  }
  
  return content;
}

/**
 * mht 内のファイル名を置き換える
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) replaceLocation {
  int i;
  arUnMHTExtractorFile *file;
  NSStringEncoding encoding;
  NSString *content;
  
  for (i = 0; i < [self->files count]; i ++) {
    file
      = (arUnMHTExtractorFile *)[self->files
                                    objectAtIndex: i];
    
    if (file->deleted) {
      continue;
    }
    
    if ([file->filetype
            isEqualToString: @"text/css"]) {
      /* CSS ファイルはチェックしない */
    }
    else if ([file->filetype
                 rangeOfString: @"image/"
                 options: NSCaseInsensitiveSearch].location != 0) {
      /* HTML ファイルの場合、属性でチェックする */
      encoding
        = CFStringConvertEncodingToNSStringEncoding
        (CFStringConvertIANACharSetNameToEncoding ((CFStringRef)file->charset));
      if ([file->charset
              isEqualToString: @"Shift_JIS"]) {
        encoding = NSShiftJISStringEncoding;
      }
      content
        = [[NSString alloc]
            initWithData: file->binContent
                encoding: encoding];
      if ([content length] == 0) {
        /* 元のコーディングでは展開できないので
         * ASCII で展開する */
        encoding = NSASCIIStringEncoding;
        content
          = [[NSString alloc]
              initWithData: file->binContent
                  encoding: encoding];
        if ([content length] == 0) {
          continue;
        }
      }
      
      content
        = [self
            replaceHTMLLocation: content
                           file: file];
      
      file->content = content;
      file->binContent
        = [file->content
              dataUsingEncoding: encoding];
      if ([file->binContent length] == 0) {
        file->binContent
          = [file->content
                dataUsingEncoding: NSShiftJISStringEncoding];
      }
    }
  }
  
  return 1;
}

/**
 * mht ファイルを展開する
 *
 * @param  NSString *text
 *         mht ファイルの内容
 * @param  NSString *uri
 *         展開したファイル名の URI 表記
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) extractMHT: (NSString *)text
   originalURISpec: (NSString *)uri {
  NSRange range;
  NSRange range2;
  int length;
  char c1;
  char c2;
  NSCharacterSet *characterSet;
  NSString *line;
  
  self->rootFile = nil;
  self->alternative = false;
  self->originalURISpec = uri;
  
  range
    = [self->originalURISpec
          rangeOfString: @":/"
          options: NSLiteralSearch];
  if (range.location != NSNotFound) {
    characterSet
      = [[NSCharacterSet
           characterSetWithCharactersInString: @"/"]
          invertedSet];
    
    range2
      = [self->originalURISpec
            rangeOfCharacterFromSet: characterSet
            options: NSLiteralSearch
            range: NSMakeRange (range.location + range.length,
                                [self->originalURISpec length]
                                - range.location - range.length)];
    if (range2.location != NSNotFound) {
      self->originalURISpec
        = [NSString stringWithFormat: @"%@/%@",
                    [self->originalURISpec
                        substringToIndex: range.location],
                    [self->originalURISpec
                        substringFromIndex: range2.location]];
    }
  }
  
  self->retcode = @"";
  line
    = [text
        substringWithRange: [text
                               lineRangeForRange: NSMakeRange (0, 0)]];
  length = [line length];
  if (length >= 1) {
    c1
      = [line
          characterAtIndex: length - 1];
    if (length >= 2) {
      c2
        = [line
            characterAtIndex: length - 2];
    }
    else {
      c2 = '\0';
    }
    
    if (c1 == '\n') {
      if (c2 == '\r') {
        self->retcode = @"\r\n";
      }
      else {
        self->retcode = @"\n";
      }
    }
    else if (c1 == '\r') {
      self->retcode = @"\r";
    }
  }
  else {
    return 0;
  }
  
  self->retcode2
    = [NSString stringWithFormat: @"%@%@", self->retcode, self->retcode];
  
  self->files = [[NSMutableArray alloc] init];
  self->boundary = @"";
  self->boundaryStack = [[NSMutableArray alloc] init];
  
  
  [self
    parseMHT: text];
  
  if (self->rootFile == nil) {
    [self->files release];
    [self->boundaryStack release];
    return 0;
  }
  
  [self deleteEmptyFile];
  [self setCID];
  [self decodeContent];
  [self replaceLocation];
  
  return 1;
}

/**
 * ファイル名の置き換えを Content-ID で行う
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) setCIDMode {
  self->mode = 1;
  
  return 1;
}

/**
 * ファイル名の置き換えを URI で行う
 *
 * @return int
 *         成功したか
 *           0: 失敗
 *           1: 成功
 */
- (int) setURIMode {
  self->mode = 0;
  
  return 1;
}

@end
