//
//  RestClient.swift
//  Snorlax
//
//  Created by Austin Zheng on 3/1/16.
//  Copyright © 2016 Austin Zheng. All rights reserved.
//

import Foundation

public typealias SuccessHandler = ([NSObject : AnyObject], NSURLResponse?) -> Void
public typealias FailureHandler = SnorlaxError -> ()


public enum SnorlaxError {
  case DataError
  case ForbiddenHeaderError(String)
  case JSONSerializationError
  case NetworkError(NSError?)
}

public class RestClient {

  internal let session : NSURLSession
  internal let forbiddenHeadersSet = Set(["Authorization", "Connection", "Host", "WWW-Authenticate"])
  internal let forbiddenContentLengthKey = "Content-Length"

  init() {
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
      // TODO: build data properly
      // This means properly handling multi-part forms
      makeRequest(url, type: .POST, headers: headers, dataBuilder: data.asData, success: success, failure: failure)
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
          failure(.DataError)
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
      // TODO: do stuff with response
      // I wish I hadn't saved over this file.
  }

}

