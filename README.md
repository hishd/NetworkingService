# NetworkingService
>Networking service is a http networking library developed on top of swift URLSession api. The library is capable of performing http network requests to REST api endpoints.

## Available Types
 - **ApiNetworkConfig**
 - **RequestableEndpoint**
 - **ApiEndpoint**
 - **NetworkDataTransferService**
 - **NetworkSessionManager**
 - **NetworkLogger**
 - **NetworkService**
 - etc.

### ApiNetworkConfig
This type is used to create an instance of the network configuration to start with. The type contains the below properties.

 - baseUrl: URL - The base url of the api collection.
 - headers: [String : String] - A dictionary containing key value pairs for the headers.
 - queryParameters: [String : String] - A dictionary containing key value pairs for the query parameters which is used on the base url (if exists).

### HTTPMethodType

An enum containing the below cases,
 - get
 - head
 - put
 - update
 - post
 - delete
 - patch

### ResponseDecoder

A protocol type which is used to handle response decoding. This contains the below methods,

 - **func** decode<T: Decodable>(data: Data) **throws** -> T

This below types confirms to this abstract type.

 - JsonResponseDecoder- Decodes the data as a **Decodable** object using a swift JsonDecoder
 - RawDataResponseDecoder- Handles the raw data types such as images

### RequestableEndpoint

A protocol type which is used to create blueprints of a endpoints. It contains the below properties and methods,

 - **var** path: String {**get**}
- **var**  method: HTTPMethodType {**get**}
- **var**  headerParameters: [String: String] {**get**}
- **var**  queryParameters: [String: **Any**] {**get**}
- **var** bodyParameters: [String: **Any**] {**get**}
- **var**  responseDecoder: **any**  ResponseDecoder {**get**}
- **func** urlRequest(with networkConfig: ApiNetworkConfig) **throws** -> URLRequest

The **ApiEndpoint** is a concrete type which confirms to the **RequestableEndpoint**. When creating an instance of this type, make sure to provide a **Decodable** type for the Generic placeholder **T**.

ex: 
```
private  var  endpoint: ApiEndpoint<[ResponseObject]> {
	return .init(path: "all", method: .get, responseDecoder: JsonResponseDecoder())
}
```

 - The method **func** urlRequest(....) will return a **URLRequest** instance which includes the query params, body params, http method and header parameters.


### NetworkSessionManager

A protocol type which contains the below methods,

 - **func**  request(endpoint: **any**  RequestableEndpoint, completion: **@escaping**  CompletionHandler) -> CancellableHttpRequest?
 - **func** request(_ request: URLRequest) **async** **throws** -> TaskType

The **TaskType** is a typealias which is a **Task<(Data, URLResponse), Error>**. This is a cancellable task which comes under the Swift's concurrency - async api.

>Note: To call the async methods, it requires iOS 16 as a minimum target.

The **DefaultNetworkSessionManager** type confirms to the **NetworkSessionManager** protocol. It uses the iOS default session manager to execute the url requests.

### NetworkService

A protocol type which contains the below methods,

- **func**  request(endpoint: **any**  RequestableEndpoint, completion: **@escaping**  CompletionHandler) -> CancellableHttpRequest?
- **func**  request(endpoint: **any**  RequestableEndpoint) **async** -> TaskType

The **TaskType** is a typealias which is a **Task<Data, Error>**. This is a cancellable task which comes under the Swift's concurrency - async api.

The **DefaultNetworkService** type confirms to the **NetworkService** protocol. It is used to perform a http request using a http endpoint. The below methods are used to execute rewuests.

| Method | Description |
|--|--|
| **func**  request(endpoint: **any**  RequestableEndpoint) **async** -> TaskType |  This async method executes a request using the endpoint and returns a Task which will later be executed by the caller to get a result.|
|**func**  request(endpoint: **any**  RequestableEndpoint, completion: **@escaping**  CompletionHandler) -> (**any**  CancellableHttpRequest)?|This method is used to execute a request using the provided endpoint and it will return a **CancellableHttpRequest** type which can be cancelled by the caller, using method **cancel()**.|

### NetworkLogger

A protocol which contains the below methods,
- **func**  log(request: URLRequest)
- **func**  log(responseData data: Data?, response: URLResponse?)
- **func** log(error: Error)

The **DefaultNetworkDataLogger** is a concrete type which confirms to **NetworkLogger**. This is used to log the network call's requests, responses and errors.

### NetworkDataTransferService

A protocol type which contains the below methods,

- **func**  request<T: Decodable, E: RequestableEndpoint>(with endpoint: E, on queue: NetworkDataTransferQueue, completion: **@escaping**  CompletionHandler<T> ) -> CancellableHttpRequest? **where** E.ResponseType == T

- **func**  request<T: Decodable, E: RequestableEndpoint>(with endpoint: E, completion: **@escaping**  CompletionHandler<T>) -> CancellableHttpRequest? **where** E.ResponseType == T

- **func** request<T: Decodable, E: RequestableEndpoint>(with endpoint: E) **async** -> TaskType<T> **where** E.ResponseType == T

The **DefaultNetworkDataTransferService** is a concrete type which confirms to the **NetworkDataTransferService** protocol. The class contains the below properties and these will be initialized through the designated initializer.

- networkService: **NetworkService**
- logger: **NetworkDataTransferErrorLogger** - this is a optional property

The below methods perform http requests through the provided network service and the response of type **Data** will be deserialized (converted) into the provided decodable types.

|Method|Description  |
|--|--|
| **func**  request<T: Decodable, E: RequestableEndpoint>(with endpoint: E, on queue: NetworkDataTransferQueue, completion:  **@escaping**  CompletionHandler ) -> CancellableHttpRequest?  **where**  E.ResponseType == T | This method will execute the request and executes the completion handler on the provided **DispatchQueue**.|
| **func**  request<T: Decodable, E: RequestableEndpoint>(with endpoint: E, completion:  **@escaping**  CompletionHandler) -> CancellableHttpRequest?  **where**  E.ResponseType == T | This method will execute the request and executes the completion handler |
| **func**  request<T: Decodable, E: RequestableEndpoint>(with endpoint: E)  **async**  -> TaskType  **where**  E.ResponseType == T | This async method will return a task which can be later executed by the caller. This task can also be cancelled. |

## Usage

### Declare Decodables

```
struct  ResponseObject: Decodable {
	let id: String
	let avatar: String
	let name: String
	let createdAt: String
}
```

### Creating instances

Creation of instances of below types,

 - ApiNetworkConfig
 - RequestableEndpoint<Type>
 - NetworkService
 - NetworkDataTransferService

```
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

private varnetworkDataTransferService: DefaultNetworkDataTransferService {
	return .init(networkService: networkService, logger: DefaultNetworkDataTransferErrorLogger())
}
```

### Execute request

```
let cancellableRequest = networkDataTransferService.request(with: endpoint) { result in
	switch result {
		case .success(**let** data):
			let items: [ResponseObject] = data
		case .failure(**let** error):
			print(error)
	}
}

//Cancel request if no longer needed
cancellableRequest.cancel()
```

### Using Swift's Async API (iOS 16+)

```
let task = await networkDataTransferService.request(with: endpoint)
do {
	let items: [ResponseObject] = try await task.value
} catch {
	print(error)
}
```
