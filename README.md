# Deprecated

This repository is now depreceated. Please take a look at the latest repo for the LoafWallet-iOS Project @ https://github.com/litecoin-foundation/loafwallet-ios

LoafWallet
----------------------------------

[![download](/images/Download_on_the_App_Store_Badge_US-UK_135x40.png)](https://itunes.apple.com/us/app/loafwallet/id1119332592)

## Litecoin done right

The simplest and most secure Litecoin wallet on any platform

### The first standalone iOS Litecoin wallet:

Unlike other iOS bitcoin wallets, **LoafWallet** is a real standalone Litecoin client. There is no server to get hacked or go down, so you can always access your money. Using [SPV](https://en.bitcoin.it/wiki/Thin_Client_Security#Header-Only_Clients) mode, **LoafWallet** connects directly to the Litecoin network with the fast performance you need on a mobile device.

### The next step in wallet security:

**LoafWallet** is designed to protect you from malware, browser security holes, *even physical theft*. With AES hardware encryption, app sandboxing, keychain and code signatures, LoafWallet represents a significant security advance over web and desktop wallets, and other mobile platforms.

### Beautiful simplicity:

Simplicity is **LoafWallet**'s core design principle. A simple backup phrase is all you need to restore your wallet on another device if yours is ever lost or broken.  Because **LoafWallet** is [deterministic](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki), your balance and transaction history can be recovered from just your backup phrase.

### Features:

- ["Simplified payment verification"](https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki) for fast mobile performance
- No server to get hacked or go down
- Single backup phrase that works forever
- Private keys never leave your device
- Import [password protected](https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki) paper wallets
- ["Payment protocol"](https://github.com/bitcoin/bips/blob/master/bip-0070.mediawiki) payee identity certification

### URL scheme:

**LoafWallet** supports the [x-callback-url](http://x-callback-url.com) specification with the following URLs:

```
loaf://x-callback-url/address?x-success=myscheme://myaction
```

This will callback with the current wallet receive address: `myscheme://myaction?address=1XXXX`

The following will ask the user to authorize copying a list of their wallet addresses to the clipboard before calling back:

```
loaf://x-callback-url/addresslist?x-success=myscheme://myaction
```

### WARNING:

***Installation on jailbroken devices is strongly discouraged.***

Any jailbreak app can grant itself access to every other app's keychain data and rob you by self-signing as described [here](http://www.saurik.com/id/8) and including `<key>application-identifier</key><string>*</string>` in its .entitlements file.

---

**LoafWallet** is open source and available under the terms of the MIT license.

Source code is available at https://github.com/litecoin-foundation/LoafWallet/
