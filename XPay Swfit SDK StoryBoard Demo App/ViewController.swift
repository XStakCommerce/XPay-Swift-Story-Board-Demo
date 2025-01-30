import UIKit
import SwiftUI
import XPayPaymentKit  // Assuming this is the framework you're using for the payment form

class ViewController: UIViewController {

    private var isReady = false
    @State private var isLoading: Bool = false
    private var button: UIButton!
    var handler = XPayController()
    @IBOutlet weak var showLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add the payment UI form and button dynamically
        addPaymentFormAndButton()
    }
    struct APIError: Error {
           let details: [String: Any]
       }
    private func makeNetworkCall(
        payload: [String: Any],
        endPoint: String,
        success: @escaping ([String: Any]) -> Void,
        failure: ((Error) -> Void)? = nil
    ) {
        guard let url = URL(string: "https://your backend app end point to call xpay create intent server side api") else {
            failure?(URLError(.badURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            failure?(error)
            return
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                failure?(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                failure?(URLError(.badServerResponse))
                return
            }
            if !(200...299).contains(httpResponse.statusCode) {
                if let data = data, let errorDetails = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    failure?(APIError(details: errorDetails))
                } else {
                    failure?(URLError(.badServerResponse))
                }
                return
            }

            guard let data = data,
                  let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                  let jsonResponse = jsonObject as? [String: Any] else {
                failure?(URLError(.cannotParseResponse))
                return
            }
            success(jsonResponse)
        }

        task.resume()
    }
    func doPayment(){
        self.handleButtonStatus(isReady: false)
         let customerEmail = "demo@xstak.com"
         let customerName = "John Doe"
         let customerPhone = "03012354678"
         let shippingAddress1 = "Industrial state"
         let shippingCity = "lahore"
         let shippingCountry = "pakistan"
         let shippingProvince = "punjab"
         let shippingZip = "54000"
         let randomDigits = Int.random(in: 100000...999999)
         let orderReference = "order-\(randomDigits)"

         // Constructing the payload dictionary
         let payload: [String: Any] = [
             "amount": 5,
             "currency": "PKR",
             "payment_method_types": "card",
             "customer": [
                 "email": customerEmail,
                 "name": customerName,
                 "phone": customerPhone
             ],
             "shipping": [
                 "address1": shippingAddress1,
                 "city": shippingCity,
                 "country": shippingCountry,
                 "province": shippingProvince,
                 "zip": shippingZip
             ],
             "metadata": [
                 "order_reference": orderReference
             ]
         ]
         makeNetworkCall(payload: payload, endPoint: "", success: {response in
             print("create intent api resp  : \(response)")
             // XPay will return a response containing the key 'pi_client_secret'.
             // Use this key accordingly for further processing.
             let clientSecret =  response["pi_client_secret"] as? String ??  ""
             print("create intent secret  : \(clientSecret)")
             self.handler.confirmPayment(customerName: "Amir", clientSecret:clientSecret, paymentResponse: {data in
                 print("payemnt respionse  : \(data)")
                 let errorValue = data["error"] as? Bool ?? false
                 let message = data["message"] as? String ?? "payment error"
                 let paymentStatus = data["status"] as? String ?? "Failed"
                      self.handleButtonStatus(isReady: errorValue)
                 print("message: \(message). error : \(errorValue). Payment Status : \(paymentStatus)")
             });
         }, failure:{response in
             self.handleButtonStatus(isReady: true)
             print("create intent api error  : \(response)")
         } )

     }
    private func handleButtonStatus(isReady: Bool) {
        // Ensure UI updates are on the main thread
        DispatchQueue.main.async {
            self.button.isEnabled = isReady
            self.button.backgroundColor = isReady ? .blue : .gray
        }
    }
    private func addPaymentFormAndButton() {
        let keysConfig = KeysConfiguration(accountId: "your account id", publicKey: "yur pk key", hmacKey: "your hmac key")
        let customStyleConfiguration = CustomStyleConfiguration(
            inputConfiguration: InputConfiguration(
                cardNumber: InputField(label: "Card Number", placeholder: "Enter card number"),
                expiry: InputField(label: "Expiry Date", placeholder: "MM/DD"),
                cvc: InputField(label: "CVC", placeholder: "CVC")
            ),
            inputStyle: InputStyle(
                height: 25, textColor: .black, textSize: 17,
                borderColor: .gray, borderRadius: 5, borderWidth: 1
            ),
            inputLabelStyle: InputLabelStyle(fontSize: 17, textColor: .gray),
            onFocusInputStyle: OnFocusInputStyle(
                textColor: .black, textSize: 17,
                borderColor: .blue, borderWidth: 1
            ),
            invalidStyle: InvalidStyle(borderColor: .red, borderWidth: 1, textColor: .red, textSize: 14),
            errorMessageStyle: ErrorMessageStyle(textColor: .red, textSize: 14)
        )

        let paymentView = XPayPaymentForm(
            keysConfiguration: keysConfig,
            customStyle: customStyleConfiguration,
            onBinDiscount: { data in
                print("Data in host app: \(data)")
            },
            onReady: { isReady in
                self.handleButtonStatus(isReady: isReady)
            },
            controller: self.handler
        )

        // Create the UIHostingController to host SwiftUI View
        let hostingController = UIHostingController(rootView: paymentView)

        // Add padding from left and right, keeping space from the top
        let paddingLeft: CGFloat = 20
        let paddingRight: CGFloat = 20
        let formHeight: CGFloat = 400  // Height of the form
        let yPosition: CGFloat = 100   // Y position where the form will appear

        // Set the frame for the hosting controller's view, with padding from left and right
        hostingController.view.frame = CGRect(
            x: paddingLeft,
            y: yPosition,
            width: self.view.frame.width - paddingLeft - paddingRight,  // Subtract padding for width
            height: formHeight
        )

        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        let contentHeight = hostingController.view.intrinsicContentSize.height
        hostingController.view.frame.size.height = contentHeight

         button = UIButton(type: .system)
        button.frame = CGRect(
            x: paddingLeft, // Positioning it to the right side with some margin
            y: hostingController.view.frame.maxY + 20,  // Placing it below the form (using maxY of the form)
            width:  self.view.frame.width - paddingLeft - paddingRight,  // Button width
            height: 50   // Button height
        )

        button.setTitle("Pay PKR 5.00", for: .normal)
        button.backgroundColor = isReady ? .blue : .gray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 5
        button.isEnabled = false
        button.addTarget(self, action: #selector(onPayButtonTapped), for: .touchUpInside)

        self.view.addSubview(button)
    }

    @objc private func onPayButtonTapped() {
        doPayment()
        // Add your action here (e.g., proceed with payment)
    }
}
