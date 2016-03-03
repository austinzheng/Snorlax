//
//  DataHelpers.swift
//  Snorlax
//
//  Created by Austin Zheng on 3/1/16.
//  Copyright © 2016 Austin Zheng. All rights reserved.
//

import Foundation

#if os(iOS)
  import UIKit
#elseif os(OSX)
  import AppKit
#endif

enum SnorlaxSerializationError : ErrorType {
  case TextError
  case JSONError
  case ImageError
  case OtherError
}

/// A protocol describing types which can serialize themselves as MIME content.
public protocol SnorlaxSerializable {
  func asData() throws -> NSData
  var contentType : String { get }
}

extension String : SnorlaxSerializable {
  public func asData() throws -> NSData {
    return try snorlaxEncode()
  }

  public var contentType : String {
    return "text/plain"
  }
}

extension String {
  func snorlaxEncode() throws -> NSData {
    if let encoded = dataUsingEncoding(NSUTF8StringEncoding) {
      return encoded
    }
    throw SnorlaxSerializationError.TextError
  }
}

// extension Dictionary : SnorlaxSerializable where Key == String, Value : JSONType {
extension Dictionary : SnorlaxSerializable {
  public func asData() throws -> NSData {
    // Rewrite this when conditional protocol conformance becomes a thing
    var buffer : [String : AnyObject] = [:]
    for key in keys {
      if let theKey = key as? String, value = self[key] as? AnyObject {
        buffer[theKey] = value
      } else {
        throw SnorlaxSerializationError.JSONError
      }
    }
    do {
      return try NSJSONSerialization.dataWithJSONObject(buffer, options: [])
    } catch {
      throw error
    }
  }

  public var contentType : String {
    return "application/json"
  }
}

extension NSData : SnorlaxSerializable {
  public func asData() throws -> NSData {
    return self
  }

  public var contentType : String {
    return "application/octet-stream"
  }
}

/// A data wrapper intended to present a raw NSData value in the context of a custom MIME content type.
public struct DataWrapper : SnorlaxSerializable {
  private let data : NSData
  public let contentType : String

  public func asData() throws -> NSData {
    return data
  }

  init(_ data: NSData, contentType: String) {
    self.data = data; self.contentType = contentType
  }
}

#if os(iOS)
  extension UIImage : SnorlaxSerializable {
    public func asData() throws -> NSData {
      // TODO: for iOS
      fatalError("Not yet implemented")
      return NSData()
    }

    public var contentType : String {
      return "image/png"
    }
  }
#elseif os(OSX)
  extension NSImage : SnorlaxSerializable {
    public func asData() throws -> NSData {
      if let cgSelf = CGImageForProposedRect(nil, context: nil, hints: nil) {
        let bitmapRep = NSBitmapImageRep(CGImage: cgSelf)
        if let image = bitmapRep.representationUsingType(.NSPNGFileType, properties: [:]) {
          return image
        } else {
          throw SnorlaxSerializationError.ImageError
        }
      } else {
        throw SnorlaxSerializationError.ImageError
      }
    }

    public var contentType : String {
      return "image/png"
    }
  }
#endif
