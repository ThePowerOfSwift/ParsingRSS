//
//  ViewController.swift
//  ParsingRSS
//
//  Created by Stanley Chiang on 2/6/16.
//  Copyright © 2016 Stanley Chiang. All rights reserved.
//

import UIKit
import Kanna
import MWFeedParser
import Cartography

class ViewController: UIViewController, MWFeedParserDelegate, UITextViewDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.whiteColor()
        
        let htmlFile = NSBundle.mainBundle().pathForResource("compacthodinkeersstest", ofType: "html")
        let htmlString = try? String(contentsOfFile: htmlFile!, encoding: NSUTF8StringEncoding)
        
        var scrollView = UIScrollView()
        scrollView = UIScrollView(frame: self.view.frame)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(scrollView)
        
        let stackView = UIStackView(arrangedSubviews: restructureText(htmlString!) as! [UIView])
//        stackView.frame = CGRectMake(0, 0, self.view.frame.width, self.view.frame.height * 6)
        
        stackView.axis = UILayoutConstraintAxis.Vertical
        stackView.distribution = UIStackViewDistribution.Fill
        scrollView.addSubview(stackView)
        
        for view in stackView.arrangedSubviews {
            constrain(view) { view in
                view.leading == view.superview!.leading
                view.trailing == view.superview!.trailing
            }
        }
        
        self.view.setNeedsDisplay()
        self.view.setNeedsLayout()
        
        scrollView.contentSize = stackView.frame.size
        
        constrain(stackView) { stack in
            stack.edges == stack.superview!.edges
        }
//        request()
    }
    
    func addHyperLink(html:String, noTags:String) -> NSMutableAttributedString {
        let didEmbedHyperlinks:NSMutableAttributedString = NSMutableAttributedString(string: noTags)
        if let doc = Kanna.HTML(html: html, encoding: NSUTF8StringEncoding) {
            for link in doc.css("a") {
                let linkText = link.text!
                let linkURL = link["href"]!
                
                let rangeOfLinkText = noTags.rangeOfString(linkText)!
                
                let startIndexString = String(rangeOfLinkText.startIndex)
                let startIndexInt = Int(startIndexString)!
                didEmbedHyperlinks.addAttribute(NSLinkAttributeName, value: linkURL, range: NSMakeRange(startIndexInt, linkText.characters.count))
            }
        }
        return didEmbedHyperlinks
    }
    
    func extractImageLinksAndPositionsFrom(html:String, noTags:String) -> [(String, Range<String.Index>)] {
        var imagesLinkAndPosition = [(String, Range<String.Index>)]()
        if let doc = Kanna.HTML(html: html, encoding: NSUTF8StringEncoding) {
            for node in doc.css("div.embed-img"){
                if let imageId = node.css("p").innerHTML {
                    for link in node.css("img") {
                        if let url = link["src"], _ = link["src"]?.rangeOfString("hodinkee"){
                            if let range = noTags.rangeOfString(imageId) {
                                imagesLinkAndPosition.append((url, range))
                            }
                        }
                    }
                }
            }
        }
        return imagesLinkAndPosition
    }
    
    func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        UIApplication.sharedApplication().openURL(URL)
        return false
    }
    
    func textViewDidChange(textView: UITextView) {
        textView.sizeThatFits(self.view.bounds.size)
    }
    
    func feedParserDidStart(parser: MWFeedParser!) {
        print("started parsing")
    }
    
    func feedParserDidFinish(parser: MWFeedParser!) {
        print("finished parsing")
    }
    
    func request() {
        let URL = NSURL(string: "http://fulltextrssfeed.com/www.hodinkee.com/blog/atom.xml")
        let feedParser = MWFeedParser(feedURL: URL);
        feedParser.delegate = self
        feedParser.parse()
    }
    
    func stripTagsFrom(html: String) -> String? {
        let encodedString:String = html
        let encodedData:NSData = encodedString.dataUsingEncoding(NSUTF8StringEncoding)!
        let attributedOptions: [String: AnyObject] = [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding
        ]
        do {
            let tagsStripped = try NSMutableAttributedString(data: encodedData, options: attributedOptions, documentAttributes: nil)
            return tagsStripped.string
        } catch {
            print(error)
            return nil
        }
    }
    
    func restructureText(html: String) -> [AnyObject]{
        var stack = [AnyObject]()
        if let noTags:String = stripTagsFrom(html) {
            let didExtractImageLinksAndPositions:[(String, Range<String.Index>)] = extractImageLinksAndPositionsFrom(html, noTags: noTags)
            let didEmbedHyperlinks:NSMutableAttributedString = addHyperLink(html, noTags: noTags)
            
            /*
            we will consider the base case to be alternating between 1 textview and then 1 image view and assume that they alternate --done--
            edge case #1: starting with an image --done--
            edge case #2: ending on text <missing>
            */
            
            var prevLocation:Int = 0
            var length: Int!
            
            for (link, range) in didExtractImageLinksAndPositions {
                if let startOfImageLoc = convertIndexToInt(range.startIndex), let endOfImageLoc = convertIndexToInt(range.endIndex) {
                    
                    length = startOfImageLoc - prevLocation
                    
                    if startOfImageLoc != 0{
                        let label:UILabel = UILabel()
                        let substring = didEmbedHyperlinks.attributedSubstringFromRange(NSMakeRange(prevLocation, length))
                        label.numberOfLines = 0
                        label.attributedText = substring
                        stack.append(label)
                        prevLocation = endOfImageLoc
                    }
                    
                    let imageLink:UIImageView = UIImageView()
                    imageLink.contentMode = .ScaleAspectFit
                    let imgURL: NSURL = NSURL(string: link)!
                    
                    // Download an NSData representation of the image at the URL
                    let request: NSURLRequest = NSURLRequest(URL: imgURL)
                    NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue(), completionHandler: { (response, data, error) -> Void in
                        if error == nil {
                            imageLink.image = UIImage(data: data!)
                        }
                        else {
                            print("Error: \(error!.localizedDescription)")
                        }
                    })
                    stack.append(imageLink)
                }
            }
        }
        return stack
    }
    
    func convertIndexToInt(index:String.Index) -> Int? {
        let string = String(index)
        if let int = Int(string) {
            return int
        }else {
            return nil
        }
    }
    
    func feedParser(parser: MWFeedParser, didParseFeedItem item: MWFeedItem) {
        parser.stopParsing()
    }
}