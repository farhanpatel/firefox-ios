/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage
import WebImage
import Shared

public extension UIImageView {

    public func setIcon(_ icon: Favicon?, forURL url: URL?, completed completionBlock: ((UIColor, URL?) -> Void)? = nil ) {
        if let siteURL = url?.baseDomain, let defaultIcon = FaviconFetcher.defaultIcons[siteURL] {
            let filePath = Bundle.main.path(forResource: "TopSites/" + defaultIcon.url.replacingOccurrences(of: ".png", with: ""), ofType: "png")
            self.image = UIImage(contentsOfFile: filePath!)
            DispatchQueue.main.async {
                completionBlock?(defaultIcon.color, url)
            }
        } else {
            let imageURL = URL(string: icon?.url ?? "")
            let defaults = defaultFavicon(url)
            self.sd_setImage(with: imageURL, placeholderImage: defaults.image, options: []) {(img, err, _, _) in
                guard let image = img, let dUrl = url, err == nil else {
                    completionBlock?(defaults.color, url)
                    return
                }
                self.colorFor(image: image, andURL: dUrl, completed: completionBlock)
            }
        }

    }

    private func colorFor(image: UIImage, andURL url: URL, completed completionBlock: ((UIColor, URL?) -> Void)? = nil) {
        // The completion block usually contains UI related code. So make sure it happens on the main thread.
        if let color = FaviconFetcher.colors[url.absoluteString] {
            DispatchQueue.main.async {
                completionBlock?(color, url)
            }
        } else {
            image.getColors(scaleDownSize: CGSize(width: 25, height: 25)) {colors in
                DispatchQueue.main.async {
                    completionBlock?(colors.backgroundColor, url)
                }
                FaviconFetcher.colors[url.absoluteString] = colors.backgroundColor
            }
        }
    }

    public func setFavicon(_ site: Site, completed completionBlock: ((UIColor, URL?) -> Void)? = nil ) {
        if let defaultIcon = FaviconFetcher.defaultIcons[site.tileURL.absoluteString] {
            let url = defaultIcon.url.replacingOccurrences(of: ".png", with: "")
            let filePath = Bundle.main.path(forResource: "TopSites/" + url, ofType: "png")
            self.image = UIImage(contentsOfFile: filePath!)
            DispatchQueue.main.async {
                completionBlock?(defaultIcon.color, site.tileURL)
            }
        } else {
            self.setIcon(site.icon, forURL: site.tileURL, completed: completionBlock)
        }

    }

    fileprivate func defaultFavicon(_ url: URL?) -> (image: UIImage, color: UIColor) {
        if let url = url {
            return (FaviconFetcher.getDefaultFavicon(url), FaviconFetcher.getDefaultColor(url))
        } else {
            return (FaviconFetcher.defaultFavicon, .white)
        }
    }

    fileprivate func setDefaultIcon(_ url: URL?) {
        if let url = url {
            self.image = FaviconFetcher.getDefaultFavicon(url)
            self.backgroundColor = FaviconFetcher.getDefaultColor(url)
        } else {
            self.image = FaviconFetcher.defaultFavicon
            self.backgroundColor = UIColor.white
        }
    }
}

open class ImageOperation: NSObject, SDWebImageOperation {
    open var cacheOperation: Operation?

    var cancelled: Bool {
        if let cacheOperation = cacheOperation {
            return cacheOperation.isCancelled
        }
        return false
    }

    @objc open func cancel() {
        if let cacheOperation = cacheOperation {
            cacheOperation.cancel()
        }
    }
}

// This is an extension to SDWebImage's api to allow passing in a cache to be used for lookup.
public typealias CompletionBlock = (_ img: UIImage?, _ err: NSError, _ type: SDImageCacheType, _ key: String) -> Void
extension UIImageView {
    // This is a helper function for custom async loaders. It starts an operation that will check for the image in
    // a cache (either one passed in or the default if none is specified). If its found in the cache its returned,
    // otherwise, block is run and should return an image to show.
    fileprivate func runBlockIfNotInCache(_ key: String, cache: SDImageCache, completed: @escaping CompletionBlock, block: @escaping () -> UIImage?) {
        self.sd_cancelCurrentImageLoad()

        let operation = ImageOperation()

        operation.cacheOperation = cache.queryDiskCache(forKey: key, done: { (image, cacheType) -> Void in
            let err = NSError(domain: "UIImage+Extensions.runBlockIfNotInCache", code: 0, userInfo: nil)
            // If this was cancelled, don't bother notifying the caller
            if operation.cancelled {
                return
            }

            // If it was found in the cache, we can just use it
            if let image = image {
                self.image = image
                self.setNeedsLayout()
            } else {
                // Otherwise, the block has a chance to load it
                let image = block()
                if image != nil {
                    self.image = image
                    cache.store(image, forKey: key)
                }
            }

            completed(image, err, cacheType, key)
        })

        self.sd_setImageLoadOperation(operation, forKey: "UIImageViewImageLoad")
    }

    public func moz_getImageFromCache(_ key: String, cache: SDImageCache, completed: @escaping CompletionBlock) {
        // This cache is filled outside of here. If we don't find the key in it, nothing to do here.
        runBlockIfNotInCache(key, cache: cache, completed: completed) { _ in return nil}
    }
}
