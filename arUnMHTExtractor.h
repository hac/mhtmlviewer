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

#import <Foundation/Foundation.h>

@interface arUnMHTExtractorFile: NSObject {
@public
  NSString *charset;         /* Content-Type のうち、文字コード */
  NSString *filetype;        /* Content-Type のうち、MIME タイプ */
  
  NSString *cid;             /* Content-ID の値 */
  NSString *location;        /* Content-Location の値 */
  
  NSString *baseDir;         /* 親ディレクトリ */
  NSString *referredBaseDir; /* 参照元のファイルの親ディレクトリ
                              * IE で保存されたファイルの場合
                              * CSS から CSS が相対パスで参照されると
                              * パスがおかしくなるため、これを修正するために用いる */
  
  NSString *leafName;        /* ファイル名 */
  NSString *extension;       /* 拡張子 (. も含む) */
  
  NSString *disposition;     /* Content-Disposition の filename の値 */
  NSString *dispositionType; /* Content-Disposition のタイプ */
  
  int encoding;              /* Content-Encoding の値
                              *   1: quoted-printable
                              *   2: base64
                              *   3: 7bit
                              *   0: 8bit */
  
  NSString *content;         /* ファイルの中身 */
  NSData *binContent;        /* デコードしたファイルの中身 */
  
  bool deleted;              /* 展開しない事を示すフラグ */
  
  NSString *nativeFilename;  /* 保存したファイル名 */
  int size;                  /* ファイルサイズ */
}
- (id) init;
- (void) release;
@end

@interface arUnMHTExtractor: NSObject {
@public
  NSString *originalURISpec;       /* 展開したファイル名の URI 表記 */
  NSString *boundary;              /* 現在の階層の boundary パラメータ */
  NSMutableArray *boundaryStack;   /* 上の階層の boundary パラメータ
                                    *   [NSString *上の階層の boundary パラメータ,
                                    *    ...] */
  
  NSString *subject;               /* Subject の値 */
  
  NSString *start;                 /* ルートドキュメントの CID */
  
  arUnMHTExtractorFile *rootFile;  /* ルートドキュメント */
  bool alternative;                /* multipert/alternative に入ったか */
  NSMutableArray *files;           /* mht ファイルの中にあるファイル
                                    *   [arUnMHTExtractorFile *ファイル情報,
                                    *    ...] */
  
  NSString *retcode;               /* mht ファイルの改行コード */
  NSString *retcode2;              /* ヘッダの終了 */
  
  int mode;                        /* 動作モード
                                    *   0: URI
                                    *   1: CID */
}
- (id) init;
- (void) release;
- (NSData *) atob: (NSString *)text;
- (NSString *) btoa: (NSData *)data;
- (NSData *) decodeQuotedPrintable: (NSString *)text;
- (NSData *) unescape: (NSString *)text;
- (NSString *) decodeEW: (NSString *)text;
- (NSString *) decodeRFC2231: (NSString *)text;
- (NSMutableDictionary *) splitHeader: (NSString *)header;
- (NSMutableDictionary *) parseValue: (NSString *)value
                            mimeType: (bool)mimeType;
- (int) splitLocation: (arUnMHTExtractorFile *)file;
- (arUnMHTExtractorFile *) parseHeader: (NSMutableDictionary *)headerMap;
- (int) parseMHT: (NSString *)text;
- (int) deleteEmptyFile;
- (int) setCID;
- (int) decodeContent;
- (NSString *) jointPath: (NSString *)base
                     sub: (NSString *)sub;
- (arUnMHTExtractorFile *) checkFile: (arUnMHTExtractorFile *)file
                                path: (NSString *)path
                            referred: (bool)referred;
- (int) replaceLocation;
- (int) extractMHT: (NSString *)text
   originalURISpec: (NSString *)uri;
- (int) setCIDMode;
- (int) setURIMode;
@end
