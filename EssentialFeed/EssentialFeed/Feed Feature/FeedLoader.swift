//
//  Copyright © Essential Developer. All rights reserved.
//

import Foundation

// not able to set Equatable here directly because we don't know what Error will be, it may not result in an equatable value
public enum LoadFeedResult<Error: Swift.Error> {
	case success([FeedItem])
	case failure(Error)
}

extension LoadFeedResult: Equatable where Error: Equatable {
    
}

protocol FeedLoader {
    associatedtype Error: Swift.Error
	func load(completion: @escaping (LoadFeedResult<Error>) -> Void)
}
