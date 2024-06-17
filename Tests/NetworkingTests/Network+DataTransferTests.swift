import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    
    struct ResponseObject: Decodable {
        let id: String
        let avatar: String
        let name: String
        let createdAt: String
    }
    
    private var networkConfig: ApiNetworkConfig {
        let url = URL(string: "https://666918ba2e964a6dfed3ced7.mockapi.io/users")
        return .init(baseUrl: url!)
    }
    
    private var endpoint: ApiEndpoint<[ResponseObject]> {
        return .init(path: "all", method: .get, responseDecoder: JsonResponseDecoder())
    }
    
    private var networkService: DefaultNetworkService {
        return .init(networkConfig: networkConfig, sessionManagerType: .defaultType, loggerType: .defaultType)
    }
    
    private var networkDataTransferService: DefaultNetworkDataTransferService {
        return .init(networkService: networkService, logger: DefaultNetworkDataTransferErrorLogger())
    }
    
    @available(iOS 16, *)
    func test_async_service_returns_result() async {
        let expectedCount = 10
        let task = await networkDataTransferService.request(with: endpoint)
        
        do {
            let items = try await task.value
            XCTAssertEqual(items.count, expectedCount)
        } catch {
            XCTFail("Failed tests with error: \(error)")
        }
    }
    
    func test_network_service_returns_result() {
        let expectation = expectation(description: "Fetching results from remote")
        let expectedCount = 10
        
        let _ = networkDataTransferService.request(with: endpoint) { result in
            switch result {
            case .success(let data):
                let items: [ResponseObject] = data
                XCTAssertEqual(items.count, expectedCount)
                expectation.fulfill()
            case .failure(let error):
                switch error {
                case .networkFailure(let networkError):
                    if networkError.isNotFoundError {
                        XCTFail("Error with URL endpoint.")
                    }
                default:
                    XCTFail("Failed tests with error: \(error)")
                    break
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func test_decode_network_service_result() {
        let expectation = expectation(description: "Fetching results from remote")
        let expectedString = "Ms. Luke Strosin"
        
        let _ = networkDataTransferService.request(with: endpoint) { result in
            switch result {
            case .success(let data):
                let items: [ResponseObject] = data
                XCTAssertEqual(items.first?.name, expectedString)
                expectation.fulfill()
            case .failure(let error):
                switch error {
                case .networkFailure(let networkError):
                    if networkError.isNotFoundError {
                        XCTFail("Error with URL endpoint.")
                    }
                default:
                    XCTFail("Failed tests with error: \(error)")
                    break
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
