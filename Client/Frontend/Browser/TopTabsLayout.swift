/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class TopTabsLayoutDelegate: NSObject, UICollectionViewDelegateFlowLayout {
    weak var tabSelectionDelegate: TabSelectionDelegate?
    
    @objc func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    @objc func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(TopTabsUX.TabWidth, collectionView.frame.height - 2)
    }
    
    @objc func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(1, TopTabsUX.TopTabsBackgroundShadowWidth, 1, TopTabsUX.TopTabsBackgroundShadowWidth)
    }
    
    @objc func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    @objc func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        tabSelectionDelegate?.didSelectTabAtIndex(indexPath.row)
    }
}

class TopTabsViewLayout: UICollectionViewFlowLayout {
    var themeColor: UIColor = TopTabsUX.TopTabsBackgroundNormalColorInactive
    var decorationAttributeArr: [Int : UICollectionViewLayoutAttributes?] = [:]
    
    override func collectionViewContentSize() -> CGSize {
        return CGSize(width: CGFloat(collectionView!.numberOfItemsInSection(0)) * (TopTabsUX.TabWidth+1)+TopTabsUX.TopTabsBackgroundShadowWidth*2,
                      height: CGRectGetHeight(collectionView!.bounds))
    }
    
    override func prepareLayout() {
        super.prepareLayout()
        self.minimumLineSpacing = 2
        scrollDirection = UICollectionViewScrollDirection.Horizontal
        registerClass(TopTabsBackgroundDecorationView.self, forDecorationViewOfKind: TopTabsBackgroundDecorationView.Identifier)
        registerClass(Seperator.self, forDecorationViewOfKind: "Seperator")
    }
    
    override func shouldInvalidateLayoutForBoundsChange(newBounds: CGRect) -> Bool {
        return true
    }

    override func layoutAttributesForDecorationViewOfKind(elementKind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionViewLayoutAttributes? {
        let layout = super.layoutAttributesForDecorationViewOfKind(elementKind, atIndexPath: indexPath)
        print("row from layout is  \(layout?.indexPath.row) and we are at \(indexPath.row)")
        if let z = self.decorationAttributeArr[indexPath.row] {
            return z
        } else {
            print("not found")
            let sep = UICollectionViewLayoutAttributes(forDecorationViewOfKind: "Seperator", withIndexPath: indexPath)
            sep.frame = CGRect.zero
            sep.zIndex = -1

            return sep
        }
    }

    // MARK: layoutAttributesForElementsInRect
    override func layoutAttributesForElementsInRect(rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var attributes = super.layoutAttributesForElementsInRect(rect)!
        
        // Create decoration attributes
        let decorationAttributes = TopTabsViewLayoutAttributes(forDecorationViewOfKind: TopTabsBackgroundDecorationView.Identifier, withIndexPath: NSIndexPath(forRow: 0, inSection: 0))

        // Make the decoration view span the entire row
        let size = collectionViewContentSize()
        decorationAttributes.frame = CGRectMake(-(TopTabsUX.TopTabsBackgroundPadding-TopTabsUX.TopTabsBackgroundShadowWidth*2)/2, 0, size.width+(TopTabsUX.TopTabsBackgroundPadding-TopTabsUX.TopTabsBackgroundShadowWidth*2), size.height)
        
        // Set the zIndex to be behind the item
        decorationAttributes.zIndex = -1
        
        // Set the style (light or dark)
        decorationAttributes.themeColor = self.themeColor
        
        // Add the attribute to the list
      //  decorationAttributeArr.removeAll()
        var arr: [Int: UICollectionViewLayoutAttributes] = [:]
        for i in attributes {
            if i.indexPath.item > 0 {
                let sep = UICollectionViewLayoutAttributes(forDecorationViewOfKind: "Seperator", withIndexPath: i.indexPath)
                sep.frame = CGRect(x: i.frame.origin.x - 2, y: i.frame.origin.y, width: 2, height: i.frame.size.height)
                sep.zIndex = -1
                arr[i.indexPath.row] = sep
                attributes.append(sep)
            }
        }
        self.decorationAttributeArr = arr
        attributes.append(decorationAttributes)

        return attributes
    }
}
