//
//  RemoteFeedLoader.swift
//  EssentialFeed
//
//  Created by Onyx Berry on 8/20/24.
//

import Foundation

public final class RemoteFeedLoader {
    private let url: URL
    private let client: HTTPClient
    
    // since our type name is the same as swift, we can specify Swift.Error so it doesnt infer incorrectly.
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public enum Result: Equatable {
        case success([FeedItem])
        case failure(Error)
    }
        
    public init(url: URL, client: HTTPClient) {
        self.client = client
        self.url = url
    }
    
    // we are able to set a default closure here so we don't break other tests
    public func load(completion: @escaping (Result) -> Void) {
        client.get(from: url) { result in
            switch result {
            case let .success(data, response):
                completion(FeedItemsMapper.map(data, from: response))
            case .failure:
                completion(.failure(.connectivity))
            }
        }
    }
}
