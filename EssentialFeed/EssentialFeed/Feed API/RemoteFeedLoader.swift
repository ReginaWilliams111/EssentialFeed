//
//  RemoteFeedLoader.swift
//  EssentialFeed
//
//  Created by Onyx Berry on 8/20/24.
//

import Foundation

public protocol HTTPClient {
    func get(from url: URL, completion: @escaping (Error?, HTTPURLResponse?) -> Void)
}

public final class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    // since our type name is the same as swift, we can specify Swift.Error so it doesnt infer incorrectly.
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
        
    public init(url: URL, client: HTTPClient) {
        self.client = client
        self.url = url
    }
    
    // we are able to set a default closure here so we don't break other tests
    public func load(completion: @escaping (Error) -> Void) {
        client.get(from: url) { error, response in
            
            if response != nil {
                completion(.invalidData)
            } else {
                completion(.connectivity)
            }
        }
    }
}
