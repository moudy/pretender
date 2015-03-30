//
// Created by Yusef Napora on 3/26/15.
// Copyright (c) 2015 Mine. All rights reserved.
//

import Foundation
import Quick
import Nimble
import Alamofire
import Pretender


class PretenderSpec : QuickSpec {
  override func spec() {
    describe("Pretender") {
      describe("Stubs in setup block") {
        let baseURL = "http://pretend.stub"
        var pretender: PretendServer!
        let manager = Alamofire.Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        beforeEach {
          pretender = PretendServer(baseURL: baseURL) { server in
            server.get("thing1") { _ in PretendResponse(string: "Hello from thing1")}
            server.post("thing2") { _ in PretendResponse(string: "Nice thing2 you posted there") }
            server.get("nothing") { _ in PretendResponse(string: "Nothing to see here", statusCode: 404)}
            server.get("things/:id/colors") { request, params in
              let id = params["id"] as! String
              return PretendResponse(string: "This thing has an id of \(id)")
            }
            server.get("people/:id/roles/:role") { request, params in
              let (id, role) = (params["id"] as! String, params["role"] as! String)
              return PretendResponse(string: "Person #\(id) loves being a \(role)")
            }
            server.get("params-please") { request, params in
              PretendResponse(string: "Thanks for sending me these great parameters: \(params)")
            }
          }
        }

        it("Stubs GET requests for a given path") {
          var responseStr: String?
          manager.request(.GET, baseURL + "/thing1")
            .responseString({ (request, response, str, error) in responseStr = str })

          expect(responseStr).toEventually(equal("Hello from thing1"))
        }

        it("Stubs POST requests for a given path") {
          var responseStr: String?
          manager.request(.POST, baseURL + "/thing2")
            .responseString({ (request, response, str, error) in responseStr = str })
          expect(responseStr).toEventually(equal("Nice thing2 you posted there"))
        }

        it("Returns the provided status code") {
          var code: Int?
          manager.request(.GET, baseURL + "/nothing")
            .response { (request, response, str, error) in code = response?.statusCode }
          expect(code).toEventually(equal(404))
        }

        it("Treats path segments beginning with ':' as wildcards") {
          var responseStr: String?
          manager.request(.GET, baseURL + "/things/100/colors")
            .responseString({ (request, response, str, error) in responseStr = str })
          expect(responseStr).toEventuallyNot(beNil())
        }

        it("Provides the values of parameterized path segments") {
          var responseStr: String?
          manager.request(.GET, baseURL + "/people/10/roles/walletinspector")
            .responseString({ (request, response, str, error) in responseStr = str })
          expect(responseStr).toEventually(equal("Person #10 loves being a walletinspector"))
        }

        it("Parses integer path parameters") {

        }

        it("Returns request parameters if they're associated with the request using NSURLProtocol") {
          var request = NSMutableURLRequest(URL: NSURL(string: baseURL + "/params-please")!)
          let params = ["ice": 9]
          NSURLProtocol.setProperty(params, forKey: RequestURLProtocolKeys.Parameters, inRequest: request)
          var responseStr: String?
          manager.request(request)
            .responseString({(request, response, str, error) in responseStr = str })
          expect(responseStr).toEventually(contain("ice"))
        }
      }

      describe("FixtureResponse") {
        describe ("Bundle class") {
          it ("Allows you to globally set the class for the bundle containing fixtures") {
            FixtureResponse.bundleClass = PretenderSpec.self
            let response = FixtureResponse("jsonresponse")
            expect("didn't assert") == "didn't assert"
            FixtureResponse.bundleClass = nil
          }

          // does what it says on the tin, so disabled with 'x' prefix
          xit("Asserts if you don't set the bundle class either globally or in the initializer") {
            let response = FixtureResponse("jsonresponse")
            expect("to never get here") == "yep, we crashed"
          }
        }

        let baseURL = "http://pretend.stub"
        var pretender: PretendServer!
        let manager = Alamofire.Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        beforeEach {
          pretender = PretendServer(baseURL: baseURL) { server in
            server.get("json") { _ in FixtureResponse("jsonresponse", inBundleForClass: PretenderSpec.self) }
            server.get("text") { _ in FixtureResponse("stringresponse.txt", inBundleForClass: PretenderSpec.self) }
          }
        }

        it("Returns the contents of a fixture file") {
          var responseStr: String?
          manager.request(.GET, baseURL + "/text")
            .responseString({ (request, response, str, error) in responseStr = str })
          expect(responseStr).toEventually(contain("Hello"))
        }

        it("Assumes a '.json' file extension if none is provided") {
          var responseData: AnyObject?
          manager.request(.GET, baseURL + "/json")
            .responseJSON { (request, response, data, error) in responseData = data }
          expect(responseData).toEventuallyNot(beNil())
        }
      }

      describe("Alamofire Manager extension") {
        let mockURL = "http://pretend.stub"
        let manager = Pretender.AlamofireManager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

        it("Includes the request parameters automatically") {
          var requestParams: [String:AnyObject]?
          let pretender = PretendServer(baseURL: mockURL) { server in
            server.post("needsparams") { request, params in
              requestParams = params
              return PretendResponse(string: "")
            }
          }

          manager.request(.POST, "http://pretend.stub/needsparams", parameters: ["something": "foo"])
          expect(requestParams?["something"] as? String).toEventually(equal("foo"))
        }
      }
    }
  }
}
