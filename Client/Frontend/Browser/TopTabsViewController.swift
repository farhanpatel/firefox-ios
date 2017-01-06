/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import WebKit

struct TopTabsUX {
    static let TopTabsViewHeight: CGFloat = 40
    static let TopTabsBackgroundNormalColor = UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1)
    static let TopTabsBackgroundPrivateColor = UIColor(red: 90/255, green: 90/255, blue: 90/255, alpha: 1)
    static let TopTabsBackgroundNormalColorInactive = UIColor(red: 178/255, green: 178/255, blue: 178/255, alpha: 1)
    static let TopTabsBackgroundPrivateColorInactive = UIColor(red: 53/255, green: 53/255, blue: 53/255, alpha: 1)
    static let PrivateModeToolbarTintColor = UIColor(red: 124 / 255, green: 124 / 255, blue: 124 / 255, alpha: 1)
    static let TopTabsBackgroundPadding: CGFloat = 35
    static let TopTabsBackgroundShadowWidth: CGFloat = 35
    static let TabWidth: CGFloat = 180
    static let CollectionViewPadding: CGFloat = 15
    static let FaderPading: CGFloat = 5
    static let BackgroundSeparatorLinePadding: CGFloat = 5
    static let TabTitleWidth: CGFloat = 110
    static let TabTitlePadding: CGFloat = 10
}

protocol TopTabsDelegate: class {
    func topTabsDidPressTabs()
    func topTabsDidPressNewTab()
    func topTabsDidPressPrivateModeButton(cachedTab: Tab?)
    func topTabsDidChangeTab()
}

protocol TopTabCellDelegate: class {
    func tabCellDidClose(cell: TopTabCell)
}

class TopTabsViewController: UIViewController {
    let tabManager: TabManager
    weak var delegate: TopTabsDelegate?
    var isPrivate = false
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: CGRectZero, collectionViewLayout: TopTabsViewLayout())
        collectionView.registerClass(TopTabCell.self, forCellWithReuseIdentifier: TopTabCell.Identifier)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.bounces = false
        collectionView.clipsToBounds = false
        collectionView.accessibilityIdentifier = "Top Tabs View"
        
        return collectionView
    }()
    
    private lazy var tabsButton: TabsButton = {
        let tabsButton = TabsButton.tabTrayButton()
        tabsButton.addTarget(self, action: #selector(TopTabsViewController.tabsTrayTapped), forControlEvents: UIControlEvents.TouchUpInside)
        tabsButton.accessibilityIdentifier = "TopTabsViewController.tabsButton"
        return tabsButton
    }()
    
    private lazy var newTab: UIButton = {
        let newTab = UIButton.newTabButton()
        newTab.addTarget(self, action: #selector(TopTabsViewController.newTabTapped), forControlEvents: UIControlEvents.TouchUpInside)
        return newTab
    }()
    
    lazy var privateModeButton: PrivateModeButton = {
        let privateModeButton = PrivateModeButton()
        privateModeButton.light = true
        privateModeButton.addTarget(self, action: #selector(TopTabsViewController.togglePrivateModeTapped), forControlEvents: UIControlEvents.TouchUpInside)
        return privateModeButton
    }()
    
    private lazy var tabLayoutDelegate: TopTabsLayoutDelegate = {
        let delegate = TopTabsLayoutDelegate()
        delegate.tabSelectionDelegate = self
        return delegate
    }()
    
    private weak var lastNormalTab: Tab?
    private weak var lastPrivateTab: Tab?
    
    private var tabsToDisplay: [Tab] {
        return self.isPrivate ? tabManager.privateTabs : tabManager.normalTabs
    }

    private var isUpdating = false
    private var _oldTabs: [Tab] = []
    private var inserts: [NSIndexPath] = []

    init(tabManager: TabManager) {
        self.tabManager = tabManager
        super.init(nibName: nil, bundle: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(TopTabsViewController.reloadFavicons(_:)), name: FaviconManager.FaviconDidLoad, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: FaviconManager.FaviconDidLoad, object: nil)
        self.tabManager.removeDelegate(self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.dataSource = self
        collectionView.delegate = tabLayoutDelegate
        collectionView.reloadData()
        dispatch_async(dispatch_get_main_queue()) {
           //  self.scrollToCurrentTab(false, centerCell: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabManager.addDelegate(self)
        
        let topTabFader = TopTabFader()
        
        view.addSubview(tabsButton)
        view.addSubview(newTab)
        view.addSubview(privateModeButton)
        view.addSubview(topTabFader)
        topTabFader.addSubview(collectionView)
        
        newTab.snp_makeConstraints { make in
            make.centerY.equalTo(view)
            make.trailing.equalTo(view)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }
        tabsButton.snp_makeConstraints { make in
            make.centerY.equalTo(view)
            make.trailing.equalTo(newTab.snp_leading)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }
        privateModeButton.snp_makeConstraints { make in
            make.centerY.equalTo(view)
            make.leading.equalTo(view)
            make.size.equalTo(UIConstants.ToolbarHeight)
        }
        topTabFader.snp_makeConstraints { make in
            make.top.bottom.equalTo(view)
            make.leading.equalTo(privateModeButton.snp_trailing).offset(-TopTabsUX.FaderPading)
            make.trailing.equalTo(tabsButton.snp_leading).offset(TopTabsUX.FaderPading)
        }
        collectionView.snp_makeConstraints { make in
            make.top.bottom.equalTo(view)
            make.leading.equalTo(privateModeButton.snp_trailing).offset(-TopTabsUX.CollectionViewPadding)
            make.trailing.equalTo(tabsButton.snp_leading).offset(TopTabsUX.CollectionViewPadding)
        }
        
        view.backgroundColor = UIColor.blackColor()
        tabsButton.applyTheme(Theme.NormalMode)
        if let currentTab = tabManager.selectedTab {
            applyTheme(currentTab.isPrivate ? Theme.PrivateMode : Theme.NormalMode)
        }
        updateTabCount(tabsToDisplay.count)
    }
    
    func switchForegroundStatus(isInForeground reveal: Bool) {
        // Called when the app leaves the foreground to make sure no information is inadvertently revealed
        if let cells = self.collectionView.visibleCells() as? [TopTabCell] {
            let alpha: CGFloat = reveal ? 1 : 0
            for cell in cells {
                cell.titleText.alpha = alpha
                cell.favicon.alpha = alpha
            }
        }
    }
    
    func updateTabCount(count: Int, animated: Bool = true) {
        self.tabsButton.updateTabCount(count, animated: animated)
    }
    
    func tabsTrayTapped() {
        delegate?.topTabsDidPressTabs()
    }
    
    func newTabTapped() {
        //Save the current state
        for var i = 0; i<100; i++ {
            dispatch_async(dispatch_get_main_queue()) {
                let currentTab = self.tabManager.selectedTab
                let oldTabs = self.tabsToDisplay

                //Let TabManager do its thing (pass the event up)
                self.delegate?.topTabsDidPressNewTab()

                //Use the new state of tabs to figure out what has changed.
                let newTabs = self.tabsToDisplay
                let newSelectedTab = self.tabManager.selectedTab
                self.updateTabsFrom(oldTabs, to: newTabs, reloadTabs: [])
            }
        }

    }

    func updateTabsFrom(oldTabs: [Tab], to newTabs: [Tab], reloadTabs: [Tab?]) {
        var deletes: [NSIndexPath] = []
        var inserts: [NSIndexPath] = []
        var updates: [NSIndexPath] = []

        updates = reloadTabs.flatMap { tab in
            guard let tab = tab where newTabs.indexOf(tab) != nil && oldTabs.indexOf(tab) != nil else {
                return nil
            }
            return NSIndexPath(forRow: newTabs.indexOf(tab)!, inSection: 0)
        }
        for (index, tab) in newTabs.enumerate() {
            if oldTabs.indexOf(tab) == nil {
                inserts.append(NSIndexPath(forRow: index, inSection: 0))
            }
        }

        for (index, tab) in oldTabs.enumerate() {
            if newTabs.indexOf(tab) == nil {
                deletes.append(NSIndexPath(forRow: index, inSection: 0))
            }
        }

        if self.isUpdating  {
            self.inserts = self.inserts + inserts
            return
        }
        self.isUpdating = true
        let oldInserts = self.inserts
        self.inserts = []
        oldInserts.forEach { print("old inserts \($0.row)") }
        inserts.forEach { print("current inserts \($0.row)") }
        print("number of items in datastore  BEFORE UPDATE \(self.tabsToDisplay.count)")
        collectionView.performBatchUpdates({
            let cInserts = oldInserts + inserts
            cInserts.forEach { print("animating \($0.row)") }
            self.collectionView.insertItemsAtIndexPaths(cInserts)
           // self.collectionView.deleteItemsAtIndexPaths(deletes)
          //  self.collectionView.reloadItemsAtIndexPaths(updates)
        //    self.inserts = []
            print("number of items in datastore \(self.tabsToDisplay.count)")
             self.isUpdating = false
            }) { _ in

                //self._oldTabs = []
                print("number of items in datastore AFTER UPDATE \(self.tabsToDisplay.count)")
        }
    }
    
    func togglePrivateModeTapped() {
        delegate?.topTabsDidPressPrivateModeButton(isPrivate ? lastNormalTab : lastPrivateTab)
        self.privateModeButton.setSelected(isPrivate, animated: true)
        self.collectionView.reloadData()
        self.scrollToCurrentTab(false, centerCell: true)
    }

    func reloadFavicons(notification: NSNotification) {
        if let tab = notification.object as? Tab {
        //    self.updateTabsFrom(tabsToDisplay, to: tabsToDisplay, reloadTabs: [tab])
        } else {
         //   self.collectionView.reloadData()
        }
    }
    
    func scrollToCurrentTab(animated: Bool = true, centerCell: Bool = false) {
        guard let currentTab = tabManager.selectedTab, let index = tabsToDisplay.indexOf(currentTab) where !collectionView.frame.isEmpty else {
            return
        }
        if let frame = collectionView.layoutAttributesForItemAtIndexPath(NSIndexPath(forRow: index, inSection: 0))?.frame {
            if centerCell {
                collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: index, inSection: 0), atScrollPosition: .CenteredHorizontally, animated: false)
            } else {
                // Padding is added to ensure the tab is completely visible (none of the tab is under the fader)
                let padFrame = frame.insetBy(dx: -(TopTabsUX.TopTabsBackgroundShadowWidth+TopTabsUX.FaderPading), dy: 0)
                collectionView.scrollRectToVisible(padFrame, animated: animated)
            }
        }
    }
}

extension TopTabsViewController: Themeable {
    func applyTheme(themeName: String) {
        tabsButton.applyTheme(themeName)
        isPrivate = (themeName == Theme.PrivateMode)
        privateModeButton.styleForMode(privateMode: isPrivate)
        newTab.tintColor = isPrivate ? UIConstants.PrivateModePurple : UIColor.whiteColor()
        if let layout = collectionView.collectionViewLayout as? TopTabsViewLayout {
            if isPrivate {
                layout.themeColor = TopTabsUX.TopTabsBackgroundPrivateColorInactive
            } else {
                layout.themeColor = TopTabsUX.TopTabsBackgroundNormalColorInactive
            }
        }
    }
}

extension TopTabsViewController: TopTabCellDelegate {
    func tabCellDidClose(cell: TopTabCell) {
        guard let index = collectionView.indexPathForCell(cell)?.item else {
            return
        }
        // Used by our Diff
        let oldTabs = tabsToDisplay
        var oldSelectedTab: Tab?
        var newSelectedTab: Tab?
        //10 index 5
        let tab = tabsToDisplay[index]
        tabManager.removeTab(tab)
        //index 5. Tabs 9
        if tab == oldSelectedTab {
            // If we just closed the active tab we'll need to switch tabs and animate that change.
            oldSelectedTab = tab
            if tabsToDisplay.count == 1 {
                newSelectedTab = tabsToDisplay.first
                //8 > 5
            } else if tabsToDisplay.count - 1 > index {
                newSelectedTab = tabsToDisplay[index]
            } else {
                newSelectedTab = tabsToDisplay[index - 1]
            }
            tabManager.selectTab(newSelectedTab)
        }


        let newTabs = tabsToDisplay
        //correctly calculate which tabs to reload here!
      //  self.updateTabsFrom(oldTabs, to: newTabs, reloadTabs: [oldSelectedTab, newSelectedTab])

//        var selectedTab = false
//        if tab == tabManager.selectedTab {
//            selectedTab = true
//            //we havent changed tabs yet. Why we doing this now
//            delegate?.topTabsDidChangeTab()
//        }
//
//        if tabsToDisplay.count == 1 {
//            tabManager.removeTab(tab)
//            tabManager.selectTab(tabsToDisplay.first)
//        } else {
//            var nextTab: Tab
//            let currentIndex = indexPath.item
//            // 10 6
//
//            tabManager.removeTab(tab)
//            if selectedTab {
//                tabManager.selectTab(nextTab)
//            }
//        }


    }
}

extension TopTabsViewController: UICollectionViewDataSource {
    @objc func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let index = indexPath.item
        let tabCell = collectionView.dequeueReusableCellWithReuseIdentifier(TopTabCell.Identifier, forIndexPath: indexPath) as! TopTabCell
        tabCell.delegate = self
        
        let tab = tabsToDisplay[index]
        tabCell.style = tab.isPrivate ? .Dark : .Light
        tabCell.titleText.text = tab.displayTitle
        
        if tab.displayTitle.isEmpty {
            if (tab.webView?.URL?.baseDomain?.contains("localhost") ?? true) {
                tabCell.titleText.text = AppMenuConfiguration.NewTabTitleString
            } else {
                tabCell.titleText.text = tab.webView?.URL?.absoluteDisplayString
            }
            tabCell.accessibilityLabel = tab.url?.aboutComponent ?? ""
            tabCell.closeButton.accessibilityLabel = String(format: Strings.TopSitesRemoveButtonAccessibilityLabel, tabCell.titleText.text ?? "")
        } else {
            tabCell.accessibilityLabel = tab.displayTitle
            tabCell.closeButton.accessibilityLabel = String(format: Strings.TopSitesRemoveButtonAccessibilityLabel, tab.displayTitle)
        }

        tabCell.selectedTab = (tab == tabManager.selectedTab)
        
        if index > 0 && index < tabsToDisplay.count && tabsToDisplay[index] != tabManager.selectedTab && tabsToDisplay[index-1] != tabManager.selectedTab {
            tabCell.seperatorLine = true
        } else {
            tabCell.seperatorLine = false
        }
        
        if let favIcon = tab.displayFavicon,
           let url = NSURL(string: favIcon.url) {
            tabCell.favicon.sd_setImageWithURL(url)
        } else {
            var defaultFavicon = UIImage(named: "defaultFavicon")
            if tab.isPrivate {
                defaultFavicon = defaultFavicon?.imageWithRenderingMode(.AlwaysTemplate)
                tabCell.favicon.image = defaultFavicon
                tabCell.favicon.tintColor = UIColor.whiteColor()
            } else {
                tabCell.favicon.image = defaultFavicon
            }
        }
        
        return tabCell
    }
    
    @objc func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabsToDisplay.count
    }
}

extension TopTabsViewController: TabSelectionDelegate {
    func didSelectTabAtIndex(index: Int) {
        let oldSelectedTab = tabManager.selectedTab
        let tab = tabsToDisplay[index]
        tabManager.selectTab(tab)
        let newSelectedTab = tabManager.selectedTab

      //  self.updateTabsFrom(tabsToDisplay, to: tabsToDisplay, reloadTabs: [oldSelectedTab, newSelectedTab])

        delegate?.topTabsDidChangeTab()
    }
}

extension TopTabsViewController : WKNavigationDelegate {
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
    //    collectionView.reloadData()
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
     collectionView.reloadData()
    }
}

extension TopTabsViewController: TabManagerDelegate {
    func tabManager(tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?) {
        if selected?.isPrivate ?? false {
            lastPrivateTab = selected
        } else {
            lastNormalTab = selected
        }
    }
    func tabManager(tabManager: TabManager, didCreateTab tab: Tab) {
      //   self._oldTabs = tabsToDisplay

    }
    func tabManager(tabManager: TabManager, didAddTab tab: Tab) {
//        if self.collectionView.numberOfItemsInSection(0) == 0 {
//            return
//        }
//        if self._oldTabs.isEmpty {
//            return
//        }
//        self.updateTabsFrom(self._oldTabs, to: self.tabsToDisplay, reloadTabs: [self.tabManager.selectedTab])
    }
    func tabManager(tabManager: TabManager, didRemoveTab tab: Tab) {}
    func tabManagerDidRestoreTabs(tabManager: TabManager) {}
    func tabManagerDidAddTabs(tabManager: TabManager) {}
    func tabManagerDidRemoveAllTabs(tabManager: TabManager, toast: ButtonToast?) {
        if let privateTab = lastPrivateTab where !tabManager.tabs.contains(privateTab) {
            lastPrivateTab = nil
        }
        if let normalTab = lastNormalTab where !tabManager.tabs.contains(normalTab) {
            lastNormalTab = nil
        }
    }
}
