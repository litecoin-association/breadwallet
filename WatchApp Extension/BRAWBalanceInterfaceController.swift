//
//  BRAWBalanceInterfaceController.swift
//  BreadWallet
//
//  Created by Henry on 10/27/15.
//  Copyright (c) 2015 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import WatchKit

class BRAWBalanceInterfaceController: WKInterfaceController {
    @IBOutlet var table: WKInterfaceTable!
    var transactionList = [BRAppleWatchTransactionData]()

    @IBOutlet var balanceTextContainer: WKInterfaceGroup!
    @IBOutlet var balanceLoadingIndicator: WKInterfaceGroup!
    @IBOutlet var balanceLabel: WKInterfaceLabel!
    @IBOutlet var balanceInLocalCurrencyLabel: WKInterfaceLabel!
    @IBOutlet var transactionHeaderContainer: WKInterfaceGroup! {
        didSet {
            transactionHeaderContainer.setHidden(true) // hide header as default
        }
    }
    
    var showBalanceLoadingIndicator = false {
        didSet{
            self.balanceTextContainer.setHidden(showBalanceLoadingIndicator)
            self.balanceLoadingIndicator.setHidden(!showBalanceLoadingIndicator)
        }
    }
    
    // MARK: View life cycle
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        updateBalance()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        updateBalance()
        updateTransactionList()
        NotificationCenter.default.addObserver(
            self, selector: #selector(BRAWBalanceInterfaceController.updateUI), name: NSNotification.Name(rawValue: BRAWWatchDataManager.ApplicationDataDidUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(BRAWBalanceInterfaceController.txReceive(_:)), name: NSNotification.Name(rawValue: BRAWWatchDataManager.WalletTxReceiveNotification), object: nil)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func txReceive(_ notification: Notification?) {
        print("balance view controller received notification: \(notification)")
        if let userData = (notification as NSNotification?)?.userInfo,
            let noteString = userData[NSLocalizedDescriptionKey] as? String {
                self.presentAlert(
                    withTitle: noteString, message: nil, preferredStyle: .alert, actions: [
                        WKAlertAction(title: NSLocalizedString("OK", comment: ""),
                            style: .cancel, handler: { self.dismiss() })])
        }
    }
    
    // MARK: UI update
    func updateUI() {
        updateBalance()
        updateTransactionList()
    }
    
    func updateBalance() {
        if let balanceInLocalizationString = BRAWWatchDataManager.sharedInstance.balanceInLocalCurrency as String? {
            if (BRAWWatchDataManager.sharedInstance.balanceAttributedString() != nil){
                balanceLabel.setAttributedText(BRAWWatchDataManager.sharedInstance.balanceAttributedString())
            }
            balanceInLocalCurrencyLabel.setText(balanceInLocalizationString)
            showBalanceLoadingIndicator = false;
        } else {
            showBalanceLoadingIndicator = true;
        }
    }
    
    func updateTransactionList() {
        transactionList = BRAWWatchDataManager.sharedInstance.transactionHistory
        let currentTableRowCount = table.numberOfRows
        let newTransactionCount = transactionList.count
        let numberRowsToInsertOrDelete = newTransactionCount - currentTableRowCount
        self.transactionHeaderContainer.setHidden(newTransactionCount == 0)
        // insert or delete rows to match number of transactions
        if (numberRowsToInsertOrDelete > 0) {
            let ixs = IndexSet(integersIn: NSMakeRange(currentTableRowCount, numberRowsToInsertOrDelete).toRange() ?? 0..<0)
            table.insertRows(at: ixs, withRowType: "BRAWTransactionRowControl")
        } else {
            let ixs = IndexSet(integersIn: NSMakeRange(newTransactionCount, abs(numberRowsToInsertOrDelete)).toRange() ?? 0..<0)
            table.removeRows(at: ixs)
        }
        // update row content
        for index in 0 ..< newTransactionCount  {
            if let rowControl = table.rowController(at: index) as? BRAWTransactionRowControl {
                updateRow(rowControl, transaction: self.transactionList[index])
            }
        }
    }
    
    func updateRow(_ rowControl: BRAWTransactionRowControl, transaction: BRAppleWatchTransactionData) {
        let localCurrencyAmount
            = (transaction.amountTextInLocalCurrency.characters.count > 2) ? transaction.amountTextInLocalCurrency : " "
        rowControl.amountLabel.setText(transaction.amountText)
        rowControl.localCurrencyAmount.setText(localCurrencyAmount)
        rowControl.dateLabel.setText(transaction.dateText)
        rowControl.type = transaction.type
        rowControl.seperatorGroup.setHeight(0.5)
    }
}
