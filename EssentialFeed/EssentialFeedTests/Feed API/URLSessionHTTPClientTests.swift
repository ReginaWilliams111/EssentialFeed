//
//  URLSessionHTTPClientTests.swift
//  EssentialFeedTests
//
//  Created by Onyx Berry on 9/25/24.
//

import XCTest
import EssentialFeed

class URLSessionHTTPClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    struct UnexpectedValuesRepresentation: Error {}
    
    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data, let response = response as? HTTPURLResponse {
                completion(.success(data, response))
            } else {
                completion(.failure(UnexpectedValuesRepresentation()))
            }
        }.resume()
    }
}

class URLSessionHTTPClientTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        URLProtocolStub.startInterceptingRequests()
    }
    
    override class func tearDown() {
        super.tearDown()
        URLProtocolStub.stopInterceptingRequests()
    }
    
    func test_getFromURL_performGetRequestWithURL() {
        let url = anyURL()
        let exp = expectation(description: "Wait for request")
        var requestFulfilled = false // Add a flag to ensure fulfill() is called only once
            
            URLProtocolStub.observeRequests { request in
                // Added condition to fix crash where fulfilled was being called more than once.
                if !requestFulfilled {
                    XCTAssertEqual(request.url, url, "request.url '\(String(describing: request.url))' and url '\(url)' are not equal")
                    XCTAssertEqual(request.httpMethod, "GET")
                    requestFulfilled = true // Set the flag
                    exp.fulfill() // Fulfill the expectation only once
                }
            }
        
        makeSUT().get(from: url) { _ in }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_failsOnRequestError() {
        let requestError = anyNSError()
        let receivedError = resultError(for: nil, response: nil, error: requestError) as? NSError
        
        XCTAssertEqual(receivedError?.domain, requestError.domain)
        XCTAssertEqual(receivedError?.code, requestError.code)
    }
    
    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        XCTAssertNotNil(resultError(for: nil, response: nil, error: nil))
        XCTAssertNotNil(resultError(for: nil, response: nonHTTPURLResponse(), error: nil))
        XCTAssertNotNil(resultError(for: anyData(), response: nil, error: nil))
        XCTAssertNotNil(resultError(for: anyData(), response: nil, error: anyNSError()))
        XCTAssertNotNil(resultError(for: nil, response: nonHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(resultError(for: nil, response: anyHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(resultError(for: anyData(), response: nonHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(resultError(for: anyData(), response: anyHTTPURLResponse(), error: anyNSError()))
        XCTAssertNotNil(resultError(for: anyData(), response: nonHTTPURLResponse(), error: nil))
    }
    
    // Happy path
    func test_getFromURL_succeedsOnHTTPURLReponseWithData() {
        let data = anyData()
        let response = anyHTTPURLResponse()
        URLProtocolStub.stub(data: data, response: response, error: nil)
        
        let exp = expectation(description: "Wait for completion")
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case let .success(receivedData, receivedResponse):
                XCTAssertEqual(receivedData, data)
                XCTAssertEqual(receivedResponse.statusCode, response.statusCode)
                XCTAssertEqual(receivedResponse.url, response.url)
            default:
                XCTFail("Expected success, got \(result) instead")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    func test_getFromURL_succeedsWithEmptyDataOnHTTPURLReponseWithNilData() {
        let response = anyHTTPURLResponse()
        URLProtocolStub.stub(data: nil, response: response, error: nil)
        
        let exp = expectation(description: "Wait for completion")
        makeSUT().get(from: anyURL()) { result in
            switch result {
            case let .success(receivedData, receivedResponse):
                let emptyData = Data()
                XCTAssertEqual(receivedData, emptyData)
                XCTAssertEqual(receivedResponse.statusCode, response.statusCode)
                XCTAssertEqual(receivedResponse.url, response.url)
            default:
                XCTFail("Expected success, got \(result) instead")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> URLSessionHTTPClient {
        let sut = URLSessionHTTPClient()
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func resultError(for data: Data?, response: URLResponse?, error: Error?, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        URLProtocolStub.stub(data: data, response: response, error: error)
        let sut = makeSUT(file: file, line: line)
        let exp = expectation(description: "Wait for completion")
        
        var receivedError: Error?
        sut.get(from: anyURL()) { result in
            switch result {
            case let .failure(error):
                receivedError = error
            default:
                XCTFail("Expected failure, got result \(result) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        return receivedError
    }
    
    private func anyURL() -> URL {
        return URL(string: "http://any-url.com/")!
    }
    
    private func anyData() -> Data {
        return Data("any data".utf8)
    }
    
    private func anyNSError() -> NSError {
        return NSError(domain: "anyData", code: 1)
    }
    
    private func nonHTTPURLResponse() -> URLResponse {
        return URLResponse(url: anyURL(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
    }
    
    private func anyHTTPURLResponse() -> HTTPURLResponse {
        return HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
    }
    
    // we are subclassing URLProtcol class (its not a protocol)
    private class URLProtocolStub: URLProtocol {
        private static var stub: Stub?
        private static var requestObserver: ((URLRequest) -> Void)?
        
        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }
        
        static func stub(data: Data?, response: URLResponse?, error: Error?) {
            stub = Stub(data: data, response: response, error: error)
        }
        
        static func observeRequests(observer: @escaping (URLRequest) -> Void) {
            requestObserver = observer
        }
        
        static func startInterceptingRequests() {
            URLProtocol.registerClass(URLProtocolStub.self)
            
        }
        
        static func stopInterceptingRequests() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }
        
        override class func canInit(with request: URLRequest) -> Bool {
            requestObserver?(request)
           return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            // returning true allows us to intercept all requests
            return request
        }
        
        override func startLoading() {
            if let data = URLProtocolStub.stub?.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            if let response = URLProtocolStub.stub?.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let error = URLProtocolStub.stub?.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            
            // tell it to finish loading
            client?.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {}
    }
}
