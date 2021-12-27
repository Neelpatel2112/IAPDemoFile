//
//  IAPHelper.swift
//  IAPDemo
//
//  Created by PC on 17/10/20.
//  Copyright © 2020 PC. All rights reserved.
//

import Foundation
import SwiftyStoreKit
enum typeofPurchse : String {
    case autoRenewableWeekly = "com.consumer.kooberi.monthly"
}
class IAPHelper {
    
    //MARK:- =========== variables ===========
    static let share = IAPHelper()
    private let SecretKey = "your-shared-secret"
    //MARK:- =========== GetProductInfo ===========
    func getInfo(_ purchase: typeofPurchse,OnSuccess: @escaping (String)->Void, OnError: @escaping (String)->Void) {
        SwiftyStoreKit.retrieveProductsInfo([purchase.rawValue]) { result in
            self.Check_ProductRetrievalInfo(result, OnSuccess: { (MSG) in
                OnSuccess(MSG)
            }) { (errorMSG) in
                OnError(errorMSG)
            }            
        }
    }
    //MARK:- =========== Purchase Product ===========
    func purchase(_ purchase: typeofPurchse, atomically: Bool) {
        SwiftyStoreKit.purchaseProduct(purchase.rawValue, atomically: atomically) { result in
            
            if case .success(let purchase) = result {
                let downloads = purchase.transaction.downloads
                if !downloads.isEmpty {
                    SwiftyStoreKit.start(downloads)
                }
                // Deliver content from server, then:
                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
            switch result {
            case .success(let purchase):
                print("Purchase Success: \(purchase.productId)")
            case .error(let error):
                print("Purchase Error: \(error.localizedDescription)")
                break
            }
        }
    }
    //MARK:- =========== VerifyReceipt ===========
    
    func verifyReceipt(completion: @escaping (VerifyReceiptResult) -> Void) {
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: SecretKey)
        SwiftyStoreKit.verifyReceipt(using: appleValidator, completion: completion)
    }
    //MARK:- =========== VerifyPurchase ===========
    
    func verifyPurchase(_ purchase: typeofPurchse) {
        verifyReceipt { result in
            switch result {
            case .success(let receipt):
                let productId = purchase.rawValue
                switch purchase {
                case .autoRenewableWeekly:
                    let purchaseResult = SwiftyStoreKit.verifySubscription(
                        ofType: .autoRenewable,
                        productId: productId,
                        inReceipt: receipt)
                    self.Check_VerifySubscriptions(purchaseResult, productIds: [productId])
                }
            case .error:
                self.Check_VerifyReceipt(result)
            }
        }
    }
    func restore(OnSuccess: @escaping (String)->Void, OnError: @escaping (String)-> Void) {
        SwiftyStoreKit.restorePurchases(atomically: false) { results in
            if results.restoreFailedPurchases.count > 0 {
                print("Restore Failed: \(results.restoreFailedPurchases)")
                OnError("\(results.restoreFailedPurchases)")
            }
            else if results.restoredPurchases.count > 0 {
                for purchase in results.restoredPurchases {
                    // fetch content from your server, then:
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                }
                print("Restore Success: \(results.restoredPurchases)")
                OnSuccess("Restore Success: \(results.restoredPurchases)")
            }
            else {
                OnError("Nothing to Restore")
                print("Nothing to Restore")
            }
        }
    }
}
extension IAPHelper {
    //MARK:- =========== Check_ProductRetrievalInfo ===========
    func Check_ProductRetrievalInfo(_ result: RetrieveResults,OnSuccess: @escaping (String)->Void, OnError: @escaping (String)-> Void) {
        
        if let product = result.retrievedProducts.first {
            let priceString = product.localizedPrice!
            OnSuccess("\(product.localizedDescription) - \(priceString)")
        } else if let invalidProductId = result.invalidProductIDs.first {
            OnError("Invalid product identifier: \(invalidProductId)")
        } else {
            let errorString = result.error?.localizedDescription ?? "Unknown error. Please contact support"
            OnError("Could not retrieve product info \(errorString)")
        }
    }
    //MARK:- =========== Check_VerifySubscriptions ===========
    func Check_VerifySubscriptions(_ result: VerifySubscriptionResult, productIds: Set<String>) {
        switch result {
        case .purchased(let expiryDate, let items):
            print("\(productIds) is valid until \(expiryDate)\n\(items)\n")
        case .expired(let expiryDate, let items):
            print("\(productIds) is expired since \(expiryDate)\n\(items)\n")
        case .notPurchased:
            print("\(productIds) has never been purchased")
        }
    }
    //MARK:- =========== Check_VerifyReceipt ===========
    func Check_VerifyReceipt(_ result: VerifyReceiptResult)  {
        
        switch result {
        case .success(let receipt):
            print("Verify receipt Success: \(receipt)")
        case .error(let error):
            print("Verify receipt Failed: \(error)")
            switch error {
            case .noReceiptData:
                print("No receipt data. Try again.")
            case .networkError(let error):
                print("Network error while verifying receipt: \(error)")
            default:
                print("Receipt verification failed: \(error)")
            }
        }
    }
}
