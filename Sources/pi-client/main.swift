import SwiftyGPIO
import Foundation
import AsyncHTTPClient

let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi3)
let pin = gpios[.P18]!
let debouncePeriodInSeconds = 3.0
var buttonState = 0
var lastChange = Date()
let endpoint = "https://rawlie-server-prod.vapor.cloud/api/v1/eats"

let client = HTTPClient(eventLoopGroupProvider: .createNew)
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .formatted(DateFormatter.iso8601Full)

struct RequestBody: Codable {
    var timestamp: Date
}

func makeRequest(given httpClient: HTTPClient) throws {
    var request = try HTTPClient.Request(url: endpoint, method: .POST)
    request.headers.add(name: "User-Agent", value: "Rasberry Pi - Swift HTTPClient")
    request.headers.add(name: "Content-Type", value: "application/json")
    let requestBody = RequestBody(timestamp: Date())
    let requestData = try encoder.encode(requestBody)
    
    request.body = .string(String(bytes: requestData, encoding: .utf8)!)
    
    print(String(bytes: requestData, encoding: .utf8)!)
    
    
    httpClient.execute(request: request).whenComplete { result in
        switch result {
        case .failure(let error):
            // process error
            fatalError("\(error)")
        case .success(let response):
            if response.status == .accepted {
                // handle response
                print("Response Status: \(response.status)")
                return
            } else {
                // handle remote error
                print("Non-200 returned: \(response.status)")
                return
            }
        }
    }
}


while true {
    pin.onChange { changingPin in
        let now = Date()
        let timeSinceLastChange = now.timeIntervalSince(lastChange)
        
        if changingPin.value != buttonState && timeSinceLastChange >= debouncePeriodInSeconds {
            print("Making request to health endpoint")
            do {
                try makeRequest(given: client)
            } catch(let error) {
                // TODO: Add error handling? Possibly send to slack?
                print("There was an error sending request: \(error.localizedDescription)")
            }
            
            print("Request sent successfully!")
            
            print("Changing button state to \(changingPin.value), time since last change \(timeSinceLastChange)")
            buttonState = changingPin.value
            lastChange = now
        }
    }
}


