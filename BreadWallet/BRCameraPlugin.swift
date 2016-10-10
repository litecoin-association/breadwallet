//
//  BRCameraPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 10/9/16.
//  Copyright © 2016 Aaron Voisine. All rights reserved.
//

import Foundation

@available(iOS 8.0, *)
@objc public class BRCameraPlugin: NSObject, BRHTTPRouterPlugin, UIImagePickerControllerDelegate,
                                   UINavigationControllerDelegate, CameraOverlayDelegate {
    
    let controller: UIViewController
    var response: BRHTTPResponse?
    var picker: UIImagePickerController?
    
    init(fromViewController: UIViewController) {
        self.controller = fromViewController
        super.init()
    }
    
    public func hook(router: BRHTTPRouter) {
        // GET /_camera/take_picture
        //
        // Optionally pass ?overlay=<id> (see overlay ids below) to show an overlay
        // in picture taking mode
        //
        // Status codes:
        //   - 200: Successful image capture
        //   - 204: User canceled image picker
        //   - 404: Camera is not available on this device
        //   - 423: Multiple concurrent take_picture requests. Only one take_picture request may be in flight at once.
        //
        router.get("/_camera/take_picture") { (request, match) -> BRHTTPResponse in
            if self.response != nil {
                print("[BRCameraPlugin] already taking a picture")
                return BRHTTPResponse(request: request, code: 423)
            }
            if !UIImagePickerController.isSourceTypeAvailable(.Camera)
                || UIImagePickerController.availableCaptureModesForCameraDevice(.Rear) == nil {
                print("[BRCameraPlugin] no camera available")
                return BRHTTPResponse(request: request, code: 404)
            }
            let response = BRHTTPResponse(async: request)
            self.response = response
            
            dispatch_async(dispatch_get_main_queue()) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = .Camera
                picker.cameraCaptureMode = .Photo
                
                // set overlay
                if let overlay = request.query["overlay"] where overlay.count == 1 {
                    print(["BRCameraPlugin] overlay = \(overlay)"])
                    let screenBounds = UIScreen.mainScreen().bounds
                    if overlay[0] == "id" {
                        picker.showsCameraControls = false
                        picker.allowsEditing = false
                        picker.hidesBarsOnTap = true
                        picker.navigationBarHidden = true
                        
                        let overlay = IDCameraOverlay(frame: screenBounds)
                        overlay.delegate = self
                        overlay.backgroundColor = UIColor.clearColor()
                        picker.cameraOverlayView = overlay
                    }
                }
                self.picker = picker
                self.controller.presentViewController(picker, animated: true, completion: nil)
            }
            
            return response
        }
        
        // GET /_camera/picture/(id)
        //
        // Return a picture as taken by take_picture
        //
        // Status codes:
        //   - 200: Successfully returned iamge
        //   - 404: Couldn't find image with that ID
        //
        router.get("/_camera/picture/(id)") { (request, match) -> BRHTTPResponse in
            var id: String!
            if let ids = match["id"] where ids.count == 1 {
                id = ids[0]
            } else {
                return BRHTTPResponse(request: request, code: 500)
            }
            let resp = BRHTTPResponse(async: request)
            do {
                let imgDat = try self.readImage(id)
                resp.provide(200, data: imgDat, contentType: "image/jpeg")
            } catch let e {
                print("[BRCameraPlugin] error reading image: \(e)")
                resp.provide(500)
            }
            return resp
        }
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        guard let resp = self.response else {
            return
        }
        defer {
            self.response = nil
            dispatch_async(dispatch_get_main_queue()) {
                picker.dismissViewControllerAnimated(true, completion: nil)
            }
        }
        resp.provide(204, json: nil)
    }
    
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        defer {
            dispatch_async(dispatch_get_main_queue()) {
                picker.dismissViewControllerAnimated(true, completion: nil)
            }
        }
        guard let resp = self.response else {
            return
        }
        guard var img = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            print("[BRCameraPlugin] error picking image... original image doesnt exist. data: \(info)")
            resp.provide(500)
            response = nil
            return
        }
        dispatch_async(resp.request.queue) {
            defer {
                self.response = nil
            }
            do {
                if let overlay = self.picker?.cameraOverlayView as? CameraOverlay {
                    if let croppedImg = overlay.cropImage(img) {
                        img = croppedImg
                    }
                }
                let id = try self.writeImage(img)
                print(["[BRCameraPlugin] wrote image to \(id)"])
                resp.provide(200, json: ["id": id])
            } catch let e {
                print("[BRCameraPlugin] error writing image: \(e)")
                resp.provide(500)
            }
        }
    }
    
    func takePhoto() {
        self.picker?.takePicture()
    }
    
    func cancelPhoto() {
        if let picker = self.picker {
            self.imagePickerControllerDidCancel(picker)
        }
    }
    
    func readImage(name: String) throws -> [UInt8] {
        let fm = NSFileManager.defaultManager()
        let docsUrl = fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let picDirUrl = docsUrl.URLByAppendingPathComponent("pictures", isDirectory: true)!
        let picUrl = picDirUrl.URLByAppendingPathComponent("\(name).jpeg")!
        guard let dat = NSData(contentsOfURL: picUrl) else {
            throw ImageError.CouldntRead
        }
        return Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(dat.bytes), count: dat.length))
    }
    
    func writeImage(image: UIImage) throws -> String {
        guard let dat = UIImageJPEGRepresentation(image, 0.5) else {
            throw ImageError.ErrorConvertingImage
        }
        let name = NSData(UInt256: dat.SHA256()).base58String()
        
        let fm = NSFileManager.defaultManager()
        let docsUrl = fm.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let picDirUrl = docsUrl.URLByAppendingPathComponent("pictures", isDirectory: true)!
        let picDirPath = picDirUrl.path!
        var attrs = try? fm.attributesOfItemAtPath(picDirPath)
        if attrs == nil {
            try fm.createDirectoryAtPath(picDirPath, withIntermediateDirectories: true, attributes: nil)
            attrs = try fm.attributesOfItemAtPath(picDirPath)
        }
        let picUrl = picDirUrl.URLByAppendingPathComponent("\(name).jpeg")!
        try dat.writeToURL(picUrl, options: [])
        return name
    }
}

enum ImageError: ErrorType {
    case ErrorConvertingImage
    case CouldntRead
}

protocol CameraOverlayDelegate {
    func takePhoto()
    func cancelPhoto()
}

protocol CameraOverlay {
    func cropImage(image: UIImage) -> UIImage?
}

class IDCameraOverlay: UIView, CameraOverlay {
    var delegate: CameraOverlayDelegate?
    let takePhotoButton: UIButton
    let cancelButton: UIButton
    let overlayRect: CGRect
    
    override init(frame: CGRect) {
        overlayRect = CGRectMake(0, 0, frame.width, frame.width * CGFloat(4.0/3.0))
        takePhotoButton = UIButton(type: .Custom)
        takePhotoButton.setImage(UIImage(named: "camera-btn"), forState: .Normal)
        takePhotoButton.setImage(UIImage(named: "camera-btn-pressed"), forState: .Highlighted)
        takePhotoButton.frame = CGRectMake(0, 0, 79, 79)
        takePhotoButton.center = CGPointMake(
            CGRectGetMidX(overlayRect),
            CGRectGetMaxX(overlayRect) + (frame.height - CGRectGetMaxX(overlayRect)) * 0.75
        )
        cancelButton = UIButton(type: .Custom)
        cancelButton.setTitle(NSLocalizedString("Cancel", comment: ""), forState: .Normal)
        cancelButton.frame = CGRectMake(0, 0, 88, 44)
        cancelButton.center = CGPointMake(takePhotoButton.center.x * 0.3, takePhotoButton.center.y)
        cancelButton.setTitleColor(UIColor.whiteColor(), forState: .Normal)
        super.init(frame: frame)
        takePhotoButton.addTarget(self, action: #selector(IDCameraOverlay.doTakePhoto(_:)),
                                  forControlEvents: .TouchUpInside)
        cancelButton.addTarget(self, action: #selector(IDCameraOverlay.doCancelPhoto(_:)),
                               forControlEvents: .TouchUpInside)
        self.addSubview(cancelButton)
        self.addSubview(takePhotoButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not implemented")
    }
    
    func doTakePhoto(target: UIControl) {
        delegate?.takePhoto()
    }
    
    func doCancelPhoto(target: UIControl) {
        delegate?.cancelPhoto()
    }
    
     override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        
        UIColor.blackColor().colorWithAlphaComponent(0.92).setFill()
        UIRectFill(overlayRect)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            return
        }
        CGContextSetBlendMode(ctx, .DestinationOut)
        
        let width = rect.size.width * 0.9
        var cutout = CGRect(origin: overlayRect.origin,
                            size: CGSize(width: width, height: width * 0.65))
        cutout.origin.x = (overlayRect.size.width - cutout.size.width) * 0.5
        cutout.origin.y = (overlayRect.size.height - cutout.size.height) * 0.5
        let path = UIBezierPath(rect: CGRectIntegral(cutout))
        path.fill()
        
        CGContextSetBlendMode(ctx, .Normal)
        
        let str = NSLocalizedString("Center your ID in the box", comment: "") as NSString
        
        let style = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        style.alignment = .Center
        let attr = [
            NSParagraphStyleAttributeName: style,
            NSFontAttributeName: UIFont.boldSystemFontOfSize(17),
            NSForegroundColorAttributeName: UIColor.whiteColor()
        ]
        
        str.drawInRect(CGRectMake(0, CGRectGetMaxY(cutout) + 14.0, rect.width, 22), withAttributes: attr)
    }
    
    func cropImage(image: UIImage) -> UIImage? {
        guard let cgimg = image.CGImage else {
            return nil
        }
        let rect = CGRectMake(0, 0, image.size.width, image.size.height)
        let width = rect.size.width * 0.9
        var cutout = CGRect(origin: rect.origin,
                            size: CGSize(width: width, height: width * 0.65))
        cutout.origin.x = (rect.size.width - cutout.size.width) * 0.5
        cutout.origin.y = (rect.size.height - cutout.size.height) * 0.5
        cutout = CGRectIntegral(cutout)
        
        func rad(f: CGFloat) -> CGFloat {
            return f / 180.0 * CGFloat(M_PI)
        }
        
        var transform: CGAffineTransform!
        switch image.imageOrientation {
        case .Left:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(90)), 0, -image.size.height)
        case .Right:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-90)), -image.size.width, 0)
        case .Down:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(rad(-180)),
                                                   -image.size.width, -image.size.height)
        default:
            transform = CGAffineTransformIdentity
        }
        transform = CGAffineTransformScale(transform, image.scale, image.scale)
        cutout = CGRectApplyAffineTransform(cutout, transform)
        
        guard let retRef = CGImageCreateWithImageInRect(cgimg, cutout) else {
            return nil
        }
        return UIImage(CGImage: retRef, scale: image.scale, orientation: image.imageOrientation)
    }
}
