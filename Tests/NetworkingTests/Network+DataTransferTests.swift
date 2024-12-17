import XCTest
@testable import NetworkingService

final class NetworkingTests: XCTestCase {
    
    struct ResponseObject: Decodable {
        let id: String
        let avatar: String
        let name: String
        let createdAt: String
        
        var _id: Int {
            guard let id = Int(id) else {
                fatalError("Invalid format id: \(id)")
            }
            
            return Int(id)
        }
    }
    
    let testIds = Array((1...10)).map(String.init)
    
    var testEndpoints: [ApiEndpoint<ResponseObject>] {
        return testIds.map { id in
                .init(path: .path(id), method: .get, responseDecoder: JsonResponseDecoder())
        }
    }
    
    private var networkConfig: ApiNetworkConfig {
        let url = URL(string: "https://6751156e69dc1669ec1d0c49.mockapi.io/users")
        return .init(baseUrl: url!)
    }
    
    private var endpoint: ApiEndpoint<[ResponseObject]> {
        return .init(path: .path("/"), method: .get, responseDecoder: JsonResponseDecoder())
    }
    
    private var networkService: DefaultNetworkService {
        return .init(networkConfig: networkConfig, sessionManagerType: .defaultType, loggerType: .defaultType)
    }
    
    private var networkDataTransferService: DefaultNetworkDataTransferService {
        return .init(networkService: networkService, logger: DefaultNetworkDataTransferErrorLogger())
    }
    
    func test_network_service_without_config_returns_result() {
        let expectation = expectation(description: "Fetching results from remote")
        let expectedCount = 10
        
        let endpoint: ApiEndpoint<[ResponseObject]> = .init(path: .urlPath("https://6751156e69dc1669ec1d0c49.mockapi.io/users"), method: .get)
        let service: DefaultNetworkService = .init(networkConfig: nil, sessionManagerType: .defaultType, loggerType: .defaultType)
        let networkDataTransferService: DefaultNetworkDataTransferService = .init(networkService: service, logger: DefaultNetworkDataTransferErrorLogger())
        
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
    
    func test_network_service_with_full_endpoint_returns_result() {
        let expectation = expectation(description: "Fetching results from remote")
        let expectedCount = 10
        
        let endpoint: ApiEndpoint<[ResponseObject]> = .init(path: .urlPath("https://666918ba2e964a6dfed3ced7.mockapi.io/users/all"), method: .get)
        let service: DefaultNetworkService = .init(networkConfig: networkConfig, sessionManagerType: .defaultType, loggerType: .defaultType)
        let networkDataTransferService: DefaultNetworkDataTransferService = .init(networkService: service, logger: DefaultNetworkDataTransferErrorLogger())
        
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
    
    func test_multiple_requests_returns_result() {
        let expectation = expectation(description: "Fetching results from remote")
        let expectedResult = "Leona Schultz"
        let id = 1
        let key: KeyPath<ResponseObject, String> = \.name
        
        let _ = networkDataTransferService.request(with: self.testEndpoints, on: DispatchQueue.global()) { result in
            switch result {
            case .success(let data):
                let item: ResponseObject = data.results.first{$0.id == String(id)}!
                let value = item[keyPath: key]
                XCTAssertEqual(value, expectedResult)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed \(#function) with error: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    @available(iOS 16, *)
    func test_async_multiple_requests_returns_result() async {
        let expectedResult = "Evelyn Cronin"
        let index = 9
        let key: KeyPath<ResponseObject, String> = \.name
        
        let task = await networkDataTransferService.request(with: testEndpoints)
        
        testEndpoints.forEach { endpoint in
            print("=======Endpoint \(endpoint.path)=======")
        }
        
        do {
            let items: [ResponseObject] = try await task.value.sorted { $0._id < $1._id }
            let item = items[index]
            let value = item[keyPath: key]
            XCTAssertEqual(value, expectedResult)
        }
        catch {
            XCTFail("Failed \(#function) with error: \(error)")
        }
    }
    
    @available(iOS 16, *)
    func test_async_service_returns_result() async {
        let expectedCount = 10
        let task = await networkDataTransferService.request(with: endpoint)
        
        do {
            let items: [ResponseObject] = try await task.value
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
        let expectedString = "Leona Schultz"
        
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
