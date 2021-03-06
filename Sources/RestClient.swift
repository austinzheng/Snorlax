//
//  RestClient.swift
//  Snorlax
//
//  Created by Austin Zheng on 3/1/16.
//  Copyright © 2016 Austin Zheng. All rights reserved.
//

import Foundation

public typealias SuccessHandler = ([NSObject : AnyObject], NSURLResponse?) -> Void
public typealias FailureHandler = SnorlaxError -> Void

public enum SnorlaxError {
  case DataSerializationError
  case ForbiddenHeaderError(String)
  case JSONSerializationError
  case NetworkError(NSError)
  case NoDataReturnedError
}

/// A wrapper around a piece of MIME content sent up as part of a multi-part form POST request.
public struct FormDataObject {
  let data : SnorlaxSerializable
  let name : String
  let fileName : String
}

public class RestClient {

  internal let session : NSURLSession
  internal let forbiddenHeadersSet = Set(["Authorization", "Connection", "Host", "WWW-Authenticate"])
  internal let forbiddenContentLengthKey = "Content-Length"
  internal static let boundary = "SNORLAX-FORM-BOUNDARY"    // TODO: user-configurable and/or autogenerated?

  init() {
    // TODO: knobs for configuring all of this
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    session = NSURLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
  }

  internal enum RequestType : String {
    case GET, POST, DELETE
  }

  func makeGETRequest(url: NSURL, headers: [String : String], success: SuccessHandler, failure: FailureHandler) {
    makeRequest(url, type: .GET, headers: headers, dataBuilder: nil, success: success, failure: failure)
  }

  func makePOSTRequest(url: NSURL, headers: [String : String], data: SnorlaxSerializable, success: SuccessHandler,
    failure: FailureHandler) {
      var h1 = headers
      h1.updateValue(data.contentType, forKey: "Content-Type")
      makeRequest(url, type: .POST, headers: h1, dataBuilder: data.asData, success: success, failure: failure)
  }

  func makeMultiPartPOSTRequest(url: NSURL, headers: [String : String], data: [FormDataObject], success: SuccessHandler,
    failure: FailureHandler) {
      // data builder
      let dataBuilder : () throws -> NSData = {
        let buffer = NSMutableData()
        for item in data {
          try buffer.appendData("--\(RestClient.boundary)\r\n".snorlaxEncode())
          try buffer.appendData("Content-Disposition: form-data; name=\"\(item.name)\"; filename=\"\(item.fileName)\"\r\n".snorlaxEncode())
          try buffer.appendData("Content-Type: \(item.data.contentType)\r\n\r\n".snorlaxEncode())
          try buffer.appendData(item.data.asData())
          try buffer.appendData("\r\n".snorlaxEncode())
        }
        try buffer.appendData("--\(RestClient.boundary)--\r\n".snorlaxEncode())
        return buffer
      }
      var h1 = headers
      h1.updateValue("multipart/form-data; boundary=\(RestClient.boundary)", forKey: "Content-Type")
      makeRequest(url, type: .POST, headers: h1, dataBuilder: dataBuilder, success: success, failure: failure)
  }

  func makeDELETERequest(url: NSURL, headers: [String : String], success: SuccessHandler, failure: FailureHandler) {
    makeRequest(url, type: .DELETE, headers: headers, dataBuilder: nil, success: success, failure: failure)
  }

  internal func makeRequest(url: NSURL, type: RequestType, headers: [String : String]?,
    dataBuilder: (() throws -> NSData)?, success: SuccessHandler, failure: FailureHandler) {
      let request = NSMutableURLRequest(URL: url)
      request.HTTPMethod = type.rawValue
      if let dataBuilder = dataBuilder {
        do {
          request.HTTPBody = try dataBuilder()
        } catch {
          failure(.DataSerializationError)
        }
      }
      if let headers = headers {
        for (key, value) in headers {
          if forbiddenHeadersSet.contains(key) || (dataBuilder != nil && key == forbiddenContentLengthKey) {
            failure(.ForbiddenHeaderError(key))
            return
          }
          request.addValue(value, forHTTPHeaderField: key)
        }
      }
      let task = session.dataTaskWithRequest(request) { (data, response, error) in
        RestClient.callback(success, failure, data, response, error)
      }
      task.resume()
  }

  internal static func callback(success: SuccessHandler, _ failure: FailureHandler, _ data: NSData?,
    _ response: NSURLResponse?, _ error: NSError?) {
      if let error = error {
        // Request failed with an error
        failure(.NetworkError(error))
      } else if let data = data {
        // Try turning data back into JSON
        do {
          let data = try NSJSONSerialization.JSONObjectWithData(data, options: [])
          if let data = data as? [String : AnyObject] {
            success(data, response)
          } else {
            failure(.JSONSerializationError)
          }
        } catch {
          failure(.JSONSerializationError)
        }
      } else {
        // No error, but no data returned either
        failure(.NoDataReturnedError)
      }
  }

}

